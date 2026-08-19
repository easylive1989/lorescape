# Redesign v3：移除每日故事與收藏、地圖換首頁、書架與付費牆歸位

- 日期：2026-08-19
- 設計來源：Claude Design 專案 `Lorescape Redesign v3.html`
  （`app2/*` ＋ `app3/*`，project id `dcdb2009-b819-4361-8be6-eeb8ba93005b`）
- 影響範圍：frontend 全域導覽、backend narration route、Supabase migration、
  Android／iOS deep link 設定、landing 的 AASA

## 背景

v3 設計稿把 App 的主結構換掉了：探索地圖成為首頁，地球儀從首頁移進「書架」
頁改釘旅程停點，每日故事整組不再出現在 App 裡。同時要把兩個先前關掉的功能
接回來——書架（`kBookshelfEnabled = false`，2026-08-11）與付費牆（ADR 0006，
2026-08-05），付費規則改成「非訂閱者每天免費一篇導覽」。

現況盤點：

- `features/daily_story/` 完整存在，被首頁 `StoryRail`、`/daily-story/detail`
  與 `/:locale/story/:date` deep link 使用。
- 書架沒被刪，是被編譯期 flag 關掉；`features/journey/`、`features/trip/`
  的程式碼與測試都在，narration 播完仍照常寫入 journey。
- 付費牆 UI（`features/subscription/`）還在，但沒有路由、設定頁沒有入口、
  backend 不再回 402。Supabase `daily_usage` 表與 `get_daily_used_count` /
  `consume_free_usage` RPC 都還在（migration `20260601000001`）。
- backend 的 `lorescape_backend/usage/`（`policy.py` / `repository.py` /
  `dependencies.py`，含 `DAILY_FREE_LIMIT = 1`）被 commit `952923be` 刪除，
  可從 `952923be^` 取回。

## 決策摘要

| 項目 | 決定 |
|---|---|
| 每日故事 | App 端整包移除；backend API、`publisher/` 產線、landing 故事頁不動 |
| 每日故事 deep link | 移除 App 攔截，`/zh/story/*`、`/en/story/*` 退回瀏覽器開 landing |
| 收藏景點 | 整條線清掉（UI ＋ repository ＋ sync ＋ Hive box ＋ 測試） |
| 首頁 | `/` 改為探索地圖；地球儀首頁與 `/map` 移除 |
| 地球儀 | 搬進 `features/journey/`，釘選中旅程的停點 |
| 書架 | 移除 `kBookshelfEnabled`，六條路由常駐 |
| 探索頁右上 | 書架 ／ 設定 ／ 重新整理 三顆圓鈕 |
| 付費牆 | 擋點一併恢復，非訂閱者每日免費 1 篇，快取命中照擋照計 |
| 額度 UX | 不做前置擋、不顯示剩餘次數；送出後接 402 直接開 paywall |
| 訂閱方案 | 沿用現有 RevenueCat offering 與定價，只改視覺 |
| 樣式 | 只做 v3 的增量畫面，其餘維持 v2 現狀 |

## 一、移除每日故事（App 端）

### 刪除

- `frontend/lib/features/daily_story/` 整包（13 檔）與 `frontend/test/` 下的
  對應測試。
- `features/home/presentation/widgets/story_rail.dart`。
- `features/home/providers.dart` 的 `homeStoriesProvider`。

### 修改

- `app/config/router_config.dart`：移除 `/daily-story/detail` 與
  `/:locale/story/:date` 兩條 route 及其 import。
- `features/analytics/domain/models/narration_event_source.dart`：移除
  `dailyStory` 成員與 `wireName` 的 `'daily_story'` 分支。此 enum 以 `name`
  持久化到 GA4，移除等於停止產生該值；歷史事件不受影響。
- i18n：刪除 `daily_story.*` 相關 key（兩個語系檔都要）。

### deep link

- `frontend/android/app/src/main/AndroidManifest.xml`：移除
  `pathPrefix="/zh/story"`、`pathPrefix="/en/story"` 兩個 `<data>`。若該
  `<intent-filter>` 移除後不再有任何 path，整個 filter 一併刪。
- `landing/public/.well-known/apple-app-site-association`：`details[0].paths`
  清空為 `[]`（保留 `appID` 條目，未來要再掛別的路徑時不必重建檔案）。
- `landing/public/.well-known/assetlinks.json` 不動——它是網域與 App 簽章的
  綁定，跟哪些路徑要攔截無關。

移除後這些網址由瀏覽器開 lorescape.app 的故事頁，IG 導流不中斷。

### 不動

backend `daily_story` API、`publisher/` 的 daily story 產線與 Discord／IG 發布、
landing 的 `/[locale]/story/[date]` 頁、Supabase `daily_stories` 表。這些是
IG／SEO 行銷資產，與 App 無關。

## 二、移除收藏（整條線）

### 刪除

- `features/saved_locations/` 整包（5 檔）。
- `features/sync/data/` 的 `hive_saved_locations_repository.dart`、
  `supabase_saved_locations_remote_data_source.dart`、
  `syncing_saved_locations_repository.dart`。
- 測試：`test/features/saved_locations/`（3 檔）、
  `test/fakes/in_memory_saved_locations_repository.dart`、
  `test/features/sync/data/hive_saved_locations_repository_test.dart`。

### 修改

- `features/sync/domain/services/sync_coordinator.dart`：移除 saved locations
  的同步分支。
- `features/sync/providers.dart`、`lib/app.dart`：移除相關 provider 與接線，
  含 Hive box 的開啟／註冊。
- `features/explore/presentation/screens/explore_screen.dart`：移除
  `SavedLocationsButton` 與景點卡上的 `_BookmarkButton`。
- `test/features/explore/presentation/screens/explore_screen_test.dart`、
  `test/integration/permission_denial_flow_test.dart`：移除對收藏的斷言。
- `NarrationEventSource.savedLocations` 一併移除（同 `dailyStory` 的理由）。

### 不動

Supabase `saved_locations` 表與其 RLS policy 保留，使用者既有資料不刪；表的
處置另案決定。

## 三、導覽重構

### 路由

```
/splash      SplashScreen
/            ExploreScreen        ← 原本是 GlobeHomeScreen
/onboarding  OnboardingWelcomeScreen
/journey     JourneyScreen（書架：地球儀 ＋ 旅程書列）
/trips       TripListScreen          ┐
/trip/edit   TripEditScreen          │
/trip/edit/:id                       ├ 原本包在 kBookshelfEnabled 裡的
/trip/uncategorized                  │ 五條，改為常駐註冊
/trip/:id    TripDetailScreen        ┘
/settings    SettingsScreen
/config      SelectStoryHookScreen
/player      NarrationScreen
/subscription  SubscriptionScreen  ← 恢復
```

- `/` 用 `NoTransitionPage`；`/map` 整條移除。指向 `/map` 的呼叫只有兩處：
  `globe_home_screen.dart:63`（隨該檔一起刪除）與
  `features/trip/presentation/widgets/trip_empty_state.dart:66` 的
  `context.go('/map')` → 改成 `context.go('/')`。
- `kBookshelfEnabled` 是 `app/config/feature_flags.dart` 裡唯一的旗標，整檔
  刪除，所有 import 一併清掉。
- 更新兩處寫死關閉狀態的測試斷言：
  `test/app/config/router_config_test.dart`（`expect(kBookshelfEnabled, isFalse)`）
  與 `test/features/home/presentation/screens/globe_home_screen_test.dart`
  （後者隨畫面刪除而整檔移除）。

### 刪除地球儀首頁

- `features/home/presentation/screens/globe_home_screen.dart`
- `features/home/presentation/widgets/home_top_bar.dart`
- 首頁 → 地圖的 zoom-into-map 轉場（`secondaryAnimation` 驅動的地球儀放大淡
  出）連同 `/map` 的 `CustomTransitionPage` 一起移除。

### 地球儀搬進 journey

`features/home/` 整包刪除，內容搬到 `features/journey/`：

| 原位置 | 新位置 |
|---|---|
| `home/domain/globe/globe_rotation.dart` | `journey/domain/globe/globe_rotation.dart` |
| `home/domain/globe/orthographic_projection.dart` | `journey/domain/globe/orthographic_projection.dart` |
| `home/domain/globe/world_outline.dart` | `journey/domain/globe/world_outline.dart` |
| `home/domain/models/globe_pin.dart` | `journey/domain/models/globe_pin.dart` |
| `home/presentation/widgets/globe_view.dart` | `journey/presentation/widgets/globe_view.dart` |
| `home/presentation/widgets/globe_painter.dart` | `journey/presentation/widgets/globe_painter.dart` |
| `home/presentation/widgets/globe_palette.dart` | `journey/presentation/widgets/globe_palette.dart` |
| `home/providers.dart` 的 `worldOutlineProvider` | `journey/providers.dart` |

理由：依賴規則禁止 feature 之間跨引 presentation 層，書架是地球儀唯一的
使用者，放在 journey 內部才合規。`test/features/home/` 對應搬到
`test/features/journey/`。

### 探索頁頂列

`_MapTopOverlay` 的 `Masthead.actions` 改為三顆圓鈕：

1. **書架**（book 圖示）→ `context.push('/journey')`
2. **設定**（齒輪圖示）→ `context.push('/settings')`
3. **重新整理**（既有 `_RefreshButton`）

樣式見第六節。設定頁在改版前唯一的入口是 `HomeTopBar.onOpenSettings`，該頁
被刪除，所以這顆設定鈕是設定頁能否進得去的關鍵，不可省略。

## 四、journey_entries 補經緯度

書架頁的地球儀要釘旅程停點，但 `journey_entries` 與 `SavedPlace` 沒有存座標
——`SavedPlace.toPlace()` 目前把 `PlaceLocation` 補成 `(0, 0)`。

- 新 migration
  `supabase/migrations/20260819000000_add_place_coords_to_journey_entries.sql`：
  `journey_entries` 增加 `place_lat double precision` 與
  `place_lng double precision`，皆 nullable（舊資料沒有座標可補）。
- `features/journey/domain/models/saved_place.dart`：新增 nullable
  `latitude` / `longitude`；`toPlace()` 在兩者皆非 null 時用真座標，否則
  維持現有的 `(0, 0)` fallback。
- `JourneyEntry.create` 從傳入的 `Place.location` 帶入座標。
- `features/sync/data/hive_journey_repository.dart` 與
  `supabase_journey_remote_data_source.dart`：讀寫新欄位；讀舊資料時缺欄位
  視為 null。
- 書架頁的地球儀只釘 `latitude`／`longitude` 皆非 null 的停點；一本旅程若
  沒有任何有座標的停點，地球儀不釘任何 pin（不顯示錯誤）。

## 五、恢復付費牆：每日免費一篇

### Backend

從 `952923be^` 取回 `backend/src/lorescape_backend/usage/`：

- `policy.py`：`DAILY_FREE_LIMIT = 1` 與 `has_free_quota(used_today)`。
- `repository.py`：`UsageRepository.used_today()` / `.consume()`，走
  service-role client 呼叫 `get_daily_used_count` / `consume_free_usage`。
- `dependencies.py`：`get_usage_repository`。
- 測試 `backend/tests/usage/test_policy.py`、`test_repository.py` 一併取回。

`narration/routes.py` 的 `post_narration` 改為：

1. `is_premium = subscriptions.is_subscribed(user.user_id)`
2. 非 premium 且 `not has_free_quota(usage.used_today(...))` → `402`，
   detail `"Daily free quota exhausted"`
3. 查快取；命中則回快取結果
4. 未命中則呼叫 `service.generate_narration`，成功後寫入快取
5. 非 premium 時 `usage.consume(user.user_id)`

**額度檢查在查快取之前**，且**快取命中同樣消耗額度**——規則保持「一天一篇
導覽」，不因為選到熱門景點就變成無限免費。生成失敗（拋例外）不消耗額度。

`POST /narration/hooks` 維持免費，不檢查也不消耗。

Supabase 的 `daily_usage` 表與兩支 RPC 已存在於 migration
`20260601000001_recreate_daily_usage.sql`；部署前需確認線上已套用（該檔全部
使用 `IF NOT EXISTS` / `CREATE OR REPLACE`，重跑安全）。

### Frontend

- `router_config.dart`：恢復 `/subscription` route → `SubscriptionScreen`。
- 設定頁最上方恢復 gem 升級卡片（樣式見第六節），點擊 push `/subscription`。
- 額度用完的流程：`narration_api_client.dart` 既有的
  `402 → NarrationError.freeQuotaExceeded` 映射、以及
  `narration_generation_controller.dart` 的
  `freeQuotaExceeded → NarrationGenerationErrorType.quotaExceeded` 都已存在
  且不需修改；只需在產生導覽的畫面收到 `quotaExceeded` 時
  `context.push('/subscription')`，不顯示錯誤訊息。
- `narration_state_error_type.dart`：`freeQuotaExceeded` 的訊息「今日免費次
  數已用完，觀看廣告即可繼續使用。」改為不再提廣告的文案；`requiresAdDialog`
  與 `requiresSpecialDialog` 兩個 getter 移除（廣告功能早已不存在，且新流程
  直接導向 paywall，不跳對話框）。

### 移除 frontend 的 usage feature

`features/usage/` 是一個沒有作用的本地計數器：`create_narration_use_case`
呼叫的 `consumeUsage()` 只寫 SharedPreferences、從不拋錯、擋不住任何東西，
而新流程不做前置擋、也不顯示剩餘次數。整包刪除：

- 刪 `features/usage/`（6 檔）與 `test/features/usage/`。
- `features/narration/domain/use_cases/create_narration_use_case.dart`：移除
  `UsageRepository` 建構參數與 `consumeUsage()` 呼叫，連同上方那段解釋
  vestigial counter 的註解。
- `features/narration/providers.dart`：移除對 usage providers 的引用。
- `narration_generation_controller.dart`：移除 `if (type is UsageError)` 分支
  （`UsageError` 隨 feature 一起消失；402 那條路徑不經過它）。
- 更新 ADR 0006 死碼清單中關於 `features/usage/` 的敘述——由新 ADR 承接。

額度的唯一真實來源是 backend。

## 六、v3 樣式（只做增量畫面）

其餘畫面（景點頁、故事頁、旅程詳情、手記、onboarding）維持 commit `3ce32a94`
之後的 v2 樣式，本次不動。

### 全站

v3 明確關掉標題上方的小字 eyebrow（`.masthead__eyebrow, .paywall__eyebrow,
.jp__eyebrow { display:none }`）。`shared/widgets/journal/masthead.dart` 的
`eyebrow` 停止顯示；影響探索、書架、設定三頁。對應的 i18n key（例如
`explore.atlas_eyebrow`、`journey.eyebrow`）一併清掉。

### 探索頁（新首頁）

- 右上三顆圓鈕：前兩顆 `paper-raised` 底色 ＋ `e1` 陰影，最右的重新整理鈕
  用 `clay` 實心底、白色圖示。
- 頂部漸層襯底、搜尋列、底部景點卡片列維持現況，v3 沒有改。
- 地圖底色不需改動：現在走 vector tile style（ADR 0005），已是米金色調，
  設計稿的 `sepia()` 濾鏡是給 raster OSM tile 用的。

### 書架頁（`/journey`）

上半地球儀、下半書架：

- 地球儀置中，上方留 128px、下方留 322px 的內距（`.shelfscr .hm-globe`）。
  釘的是目前選中那本旅程的停點。
- 標頭列：左「N 本旅程」，中間一條 1px 分隔線，右「＋ 新旅程」pill 按鈕。
  文字 10.5px、字重 700、字距 0.2em、大寫、clay 色。
- 書架本體：木板底（`#efe3ca → #e3d3b4` 漸層 ＋ 內陰影），下緣一條木條
  （`#b98d55 → #8f6a3d`，高 16px，帶投影與內高光）。
- 書背：寬 54px、高度依序錯落（148 ＋ (index % 3) × 10）、書名直排 16px
  字距 2px、底部小字顯示篇數、可橫向捲動。
- 選中的書：`translateY(-14px) rotate(-1.4deg)` ＋ 投影，動畫曲線
  `cubic-bezier(.2,.9,.3,1.25)`、0.3s。
- 底部提示：置中 11px 灰字「〈旅程名〉— 再點一下打開手記」。
- 互動：點未選中的書 → 選中它（地球儀換釘該旅程的停點）；點已選中的書 →
  進旅程詳情。
- 左上角浮動返回鈕（`paper-raised` 底 ＋ `e2` 陰影 ＋ 1px 邊框），回探索頁；
  Masthead 左內距讓出 48px 給它。

既有的 `TripBookshelf` 改造成上述樣式，`_CurrentTripBanner` 與 v2 的
Masthead 版面依 v3 調整。

### 付費牆（`/subscription`）

- 深色底（`is-dark`），右上關閉鈕。
- 上方 gem hero：92px 線稿寶石圖示、標題「解鎖無盡旅程」、副標
  「每個轉角，都有一位 AI 旅伴」。
- 方案卡：未選中只顯示名稱、badge 與價格；選中才展開 feature list（每條前
  面一個 sparkle 圖示）與細則，並在名稱左側顯示打勾圓點。
- 底部：主要 CTA（鎖頭圖示 ＋「訂閱〈方案名〉」）、「恢復購買」、
  「服務條款 · 隱私權政策」。
- 方案內容、定價、7 天免費試用全部沿用現有 RevenueCat offering，只換視覺。

### 設定頁

最上方恢復 gem 升級卡片：深色底、左側 30px 寶石圖示、主文「解鎖無盡旅程」、
副文「升級高級會員 · 無限導覽與路線規劃」、右側 chevron。點擊 push
`/subscription`。

## 七、文件與驗證

### ADR

- **ADR 0009：恢復付費牆，改為每日免費一篇**。取代 ADR 0006 的決策，說明
  擋點位置（`POST /narration`）、免費額度來源（`DAILY_FREE_LIMIT = 1`）、
  快取命中照擋照計的理由，並更新 0006 死碼清單中已消化的項目
  （`features/usage/` 已刪除、`/subscription` 路由已恢復、402 契約已重新
  啟用）。ADR 0006 標記為 Superseded by 0009。
- **ADR 0010：App 移除每日故事與收藏功能**。記錄 App 端整包移除的範圍、
  刻意保留的部分（backend API、publisher 產線、landing 故事頁、Supabase
  `daily_stories` 與 `saved_locations` 表）、以及 deep link 改由瀏覽器接手
  的決定。

### 其他文件

- `CLAUDE.md` 若有敘述受影響的結構，一併更新。
- `MARKETING.md` 與商店描述涉及訂閱制的文案：本次不處理，另案。

### 驗證

- `cd frontend && fvm flutter analyze --fatal-infos` 零問題。
- `cd frontend && fvm flutter test` 全綠，含
  `test/architecture/dependency_rules_test.dart` 守門測試（地球儀搬家後
  journey 不得再引用 home）。
- `cd backend && uv run pytest` 全綠。
- 手動驗證清單：
  1. 冷啟動 → 探索地圖首頁，右上三顆鈕都能點。
  2. 書架鈕 → 書架頁，地球儀有釘點（需先有帶座標的新記錄）、切換書會換釘點、
     再點一下進旅程詳情、返回鈕回探索。
  3. 設定鈕 → 設定頁，最上方升級卡 → 付費牆，關閉可返回。
  4. 非訂閱帳號當日第一篇導覽正常生成；第二篇送出後直接開付費牆。
  5. 訂閱帳號連續生成多篇不被擋。
  6. 瀏覽器開 `lorescape.app/zh/story/<date>` 不再被 App 攔截。

## 執行方式

改動面大，開 feature branch（git worktree）進行，不直接動 master。實作順序
於 implementation plan 中拆成獨立小 task。
