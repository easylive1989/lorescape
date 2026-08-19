# ADR 0010：App 端移除每日故事與收藏景點

- 狀態：Accepted
- 日期：2026-08-19
- 影響範圍：frontend、Android `AndroidManifest.xml`、landing
  `apple-app-site-association`

## 背景

v3 設計稿把 App 的主結構收斂成「探索 → 故事 → 書架」三塊，每日故事（首頁
故事列、故事詳情頁、`/:locale/story/:date` deep link）與收藏景點都不在這個
結構裡。兩者過去都是獨立的 feature 模組，且都各自有一條會被清掉的下游接
線（deep link 攔截、分享入口），一次改版順便整包收掉，不留一半。

## 決策

### 每日故事

App 端整包移除：

- `frontend/lib/features/daily_story/` 整個模組與對應測試。
- 首頁故事列（`StoryRail`）與 `home/providers.dart` 的
  `homeStoriesProvider`——隨這次一併發生的首頁改版（見下）而移除，非本決策
  的直接目標，但同一批 commit 處理。
- `app/config/router_config.dart` 的 `/daily-story/detail` 與
  `/:locale/story/:date` 兩條 route。
- `NarrationEventSource.dailyStory`：這個 enum member 移除是死碼清理，不是
  分析事件變動——`lib/` 裡唯一建構 `NarrationEventSource` 的地方
  （`features/analytics/presentation/narration_analytics_observer.dart:121`）
  一直是寫死 `NarrationEventSource.explore`，`dailyStory` 這個成員從沒被
  用來建構過任何事件，GA4 本來就沒收過 `daily_story` 這個來源值，移除它
  對線上格式沒有任何影響。
- i18n 的 `daily_story.*` 相關 key（兩個語系檔）。

deep link 攔截一併撤掉：

- Android `AndroidManifest.xml`：原本有一個獨立的
  `<intent-filter android:autoVerify="true">`，只放 `/zh/story` 與
  `/en/story` 兩個 `pathPrefix`（沒有掛其他路徑），這次整個 filter 一起刪
  除，不是只拿掉兩個 `<data>` 節點。
- landing `public/.well-known/apple-app-site-association`：`details[0].paths`
  清空為 `[]`，保留 `appID` 條目，未來要再掛別的路徑時不必重建整個檔案。

清空後這兩個 URL 前綴不再被 App 攔截，改由瀏覽器開 lorescape.app 的故事
頁，IG 導流的著陸體驗不變、只是不再跳轉進 App。

**刻意保留**：backend 的每日故事 API、`publisher/` 的產線與 Discord／IG 發
布 bot、landing 的 `/[locale]/story/[date]` 頁、Supabase `daily_stories`
表。這些是獨立於 App 的 IG／SEO 行銷資產，v3 改版的範圍只在 App 端。

### 收藏景點（saved locations）

整條線清掉：

- `features/saved_locations/` 整包。
- `features/sync/data/` 底下的 Hive repository、Supabase remote data
  source、syncing repository 三個檔案，以及 `sync_coordinator.dart` 裡的收
  藏同步分支。
- `features/sync/providers.dart` 與 `lib/app.dart` 對應的 provider 接線、
  Hive box 開啟與註冊。
- 探索頁的 `SavedLocationsButton` 與景點卡上的收藏按鈕。
- 對應測試（包含 fakes）。
- `NarrationEventSource.savedLocations`：理由同 `dailyStory`——同一個死碼
  清理，唯一的建構點寫死 `explore`，這個成員從沒上過線，移除不影響 GA4
  收到的資料。

**刻意保留**：Supabase `saved_locations` 表與其 RLS policy——使用者既有資
料不刪，表的最終處置（保留供未來復用、或另案清空）留給以後決定，不在本次
範圍內。

### 連帶影響：`lib/app.dart` 的分享地點 listener

從 Google Maps 分享地點進 App，唯一的落地動作原本是存進收藏（`ref.listen`
監聽 `shareIntentControllerProvider` 的結果，成功時呼叫
`savedLocationsProvider.notifier.savePlace()`）。收藏整條線移除後這個動作
沒有目標可寫，因此這段 listener 一併刪除。

要注意的是這個平台入口本身早在 ADR 0001（2026-05-13）就已經停用——
`shareIntentInitProvider` 從那時起就是註解狀態，Android `SEND` intent
filter 與 iOS Share Extension 的啟用規則也都關著。所以這次刪除的是「假設
分享流程重新打開之後，結果要導向哪裡」的那段程式碼，不是重新關閉一個當下
還在運作的功能。

`app.dart` 裡 `pendingShare = ref.watch(shareIntentControllerProvider)` 與
對應的 `_ShareLoadingOverlay` 沒有一併刪除，因為它們只是顯示「正在解析分
享內容」的 loading 畫面，本身不依賴收藏；但由於驅動它的
`shareIntentInitProvider` 從未被 watch，這個 loading 畫面在目前程式碼路徑
下永遠不會顯示，等同無害的殘留。`features/share/` 整個模組（URL 解析、
`ShareIntentHandler` 等）維持 ADR 0001 訂下的保留策略不變。日後要重新開放
分享入口，除了 ADR 0001 列的三個平台入口，還需要先決定新的落地動作是什
麼——收藏已經不存在，不能直接照舊接回去。

### 導覽重構（附帶背景，非本 ADR 決策核心）

同一批改版把 `/` 從地球儀首頁換成探索地圖，地球儀搬進
`features/journey/`（書架頁釘旅程停點），`features/home/` 整包刪除，書架
的六條路由從 `kBookshelfEnabled` flag 後面轉為常駐註冊、該 flag 檔案一併
刪除。這部分是首頁與導覽層級的改版，不屬於「移除每日故事／收藏」的決策範
圍，這裡僅供交叉參照——相關細節見
`docs/superpowers/specs/2026-08-19-redesign-v3-design.md` 第三節。

## 影響與注意事項

- IG 貼文與 landing 頁裡指向 `lorescape.app/<locale>/story/<date>` 的連結
  不需要改；使用者點進去一律在瀏覽器開啟，不再有「跳進 App」與「留在瀏覽
  器」兩種路徑分岔，反而簡化了行為的一致性。
- `saved_locations` 與 `daily_stories` 兩張表雖然保留，但 App 端已經沒有任
  何程式碼讀寫前者；後者仍由 backend／publisher 正常寫入與讀取，不受影
  響。
- 相關 spec：`docs/superpowers/specs/2026-08-19-redesign-v3-design.md` 第
  一、二節。

### GA4 screen name 的語意變動（發版日記得標註）

這份 ADR 對分析事件的說法有兩處要對照著看：上面把
`NarrationEventSource.dailyStory` / `.savedLocations` 的移除說成會讓 GA4
「不再收到」這兩個來源值——查過 `lib/` 裡唯一建構 `NarrationEventSource`
的地方後已訂正：那兩個成員從沒被用來建構過任何事件，移除的是死碼，GA4
收到的資料本來就不受影響。真正會動到 GA4 資料、卻在原本兩份 ADR 都沒提
到的變化，是下面這個：`app/config/router_config.dart` 的 `/` route。

改版前，`/`（route name `home`）是地球儀首頁；探索地圖是獨立的 `/map`
（name `map`）。改版後 `/` 直接就是探索地圖，`home/` 整包移除，`/map`
這個路徑也不再存在——地球儀搬進 `features/journey/`（書架頁釘旅程停
點），不再是可獨立導航到的畫面。

`FirebaseAnalyticsObserver`（`routeObserversProvider`）用 route settings
的 `name` 餵 `screen_view`，所以：

- 發版日前後，GA4 上同一個 screen name `home` 代表兩個完全不同的畫面
  （地球儀 → 探索地圖）。任何讀這個漏斗或序列的分析（含
  `data/metrics` 累積的 CSV）跨過發版日會把兩者接在一起，等於憑空接
  上一段不連續的資料。
- `map` 這個 screen name 從發版日起不會再出現。不是流量掉到 0，是這個
  名字本身消失了；解讀時不能誤判為「探索地圖沒人用了」。

**這不是程式問題，純粹是數據解讀要注意**：拉跨越發版日的 `home` /
`map` screen_view 序列時，先確認發版日期、把發版前後當成兩段不同定義
的資料處理，必要時在 `data/metrics` 對應資料列旁加註記。不建議事後改
route name 去「修正」歷史語意——那只會讓已經產生的 GA4 事件更難對齊。
