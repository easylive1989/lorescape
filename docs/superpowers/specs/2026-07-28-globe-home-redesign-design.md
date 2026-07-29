# Lorescape v3：地球儀首頁與導覽重組

日期：2026-07-28
設計來源：Claude Design 專案 `dcdb2009-b819-4361-8be6-eeb8ba93005b`，
檔案 `Lorescape Redesign v3.html`（`app3/` 目錄：`screens_home.jsx`、
`screens_map.jsx`、`globe.jsx`、`data3.jsx`、`ls3.css`、`app.jsx`）。

## 背景

現在的 App 用四個 bottom nav 分頁：故事、探索、歷程、設定。v3 設計把首頁換成
一顆手繪風地球儀，地球儀釘著每日故事的地點，底部是橫向故事卡片列，bottom nav
整個拿掉，歷程與設定改由首頁右上角兩顆 icon 進入。

先前幾輪改版已經把設計系統落地了：`LorescapeTokens` 對應 `ls2.css` 的色票、圓角
與陰影；`Masthead`、`CategoryTag`、`GlyphThumb`、`TripBookshelf`、`NotebookPager`
都已存在；`ExploreScreen` 已是設計稿詳細地圖模式的樣子（搜尋、篩選、重新整理、
底部地點卡列、書籤 FAB）。所以本次的實質工作是**地球儀首頁與導覽重組**，地圖端
只需接上入口與參數。

還沒對齊設計稿的四張畫面（每日故事詳情、旅程詳情、訂閱頁、舊的旅程列表頁）不在
本 spec 範圍，另開一份。

## 目標

1. 打開 App 中間就是地球儀，預設釘住並轉到最新一篇每日故事的地點。
2. 底部是每日故事橫向卡片列，點卡片進入故事詳情。
3. 拿掉 bottom navigator，歷程書架與設定改由首頁右上角 icon 進入。
4. 使用者可以用自己的位置定位周圍景點，此時從地球儀 zoom in 到詳細地圖模式。
5. 上方搜尋 bar，搜尋也會進到詳細地圖模式。
6. 有按鈕在地球儀模式與詳細地圖模式之間切換。

## 架構與路由

`MainScreen`（`lib/app/shell/main_screen.dart`）刪除，改成扁平路由：

| 路由 | 畫面 | 進入方式 |
|---|---|---|
| `/` | `GlobeHomeScreen`（新） | App 啟動、onboarding 完成 |
| `/map` | `ExploreScreen`（沿用） | 首頁定位鈕、搜尋建議 |
| `/journey` | `JourneyScreen`（沿用） | 首頁右上書本 icon |
| `/settings` | `SettingsScreen`（沿用） | 首頁右上齒輪 icon |

一併移除：

- `StoryListScreen`（`features/daily_story/presentation/screens/story_list_screen.dart`）
  ——底部 rail 取代它的功能。
- `bottom_nav.*` 與 `story.list_*` 的 i18n key（zh-TW 與 en 兩份）。
- `RouterConfig` 中 `/` 的 `?tab=` 參數處理與 `ValueKey('main-screen-...')` hack。

`trip_empty_state.dart` 目前 `context.go('/?tab=explore')`，改成 `context.go('/map')`。
`/trips`（`TripListScreen`）目前沒有任何畫面 push，本次不動，留給殘局 spec 處理。

新 feature 目錄 `lib/features/home/`，內部依 domain / presentation 分層。它跨引
`features/daily_story/providers.dart` 與 `features/explore/providers.dart`，符合
`frontend/test/architecture/dependency_rules_test.dart` 的守門規則（feature 之間
只能引 domain 與 providers.dart）。路由掛載由 `app/config/router_config.dart` 這個
composition root 負責。

## 資料層：每日故事座標

地球儀釘點需要每日故事的經緯度，目前資料庫沒有這個欄位。
`daily_story_places` 只有 `name` / `wikipedia_title_en` / `country` /
`wikidata_id`，`daily_stories` 也沒有座標。

**Migration**：`supabase/migrations/` 新增一支，對 `daily_story_places` 加
`latitude double precision` 與 `longitude double precision`（皆 nullable），並比照
`20260527000000_grant_daily_story_places_card_select.sql` 的作法，把這兩欄的 select
權限 grant 給 `anon` 與 `authenticated`。

**Backfill**：`scripts/` 下新增一支 uv 腳本，讀出所有 `wikidata_id` 非 null 且座標為
null 的列，查 Wikidata 的 P625（coordinate location）寫回 `latitude` / `longitude`。
查不到座標、或 `wikidata_id` 為 null 的列，腳本印出清單供人工補。

**Publisher**：`publisher/` 產線新增景點列時一併解析並寫入座標。既有景點由 backfill
一次補齊。

**App**：

- `DailyStory`（`features/daily_story/domain/models/daily_story.dart`）新增
  `double? latitude` 與 `double? longitude`，兩者皆 nullable。
- `SupabaseDailyStoryRepository` 的 `_select` 常數把 join 從
  `daily_story_places!left(card_location_en, card_city_ch, card_city_en, wikidata_id)`
  擴充為再加上 `latitude, longitude`，`_fromRow` 一併映射。
- 座標為 null 的故事仍出現在底部 rail，只是不釘在地球儀上；rail 捲到這種卡片時
  地球儀維持原本的旋轉角度不動。

## 地球儀元件

放在 `lib/features/home/`：

### `domain/globe/orthographic_projection.dart`

純 Dart，不依賴 Flutter widget，可直接單元測試：

- `Offset? project(LatLng)`：正射投影到畫布座標，背面回傳 null。
- `bool isVisible(LatLng)`：以目前旋轉角判斷是否落在可見半球。
- `List<List<Offset>> clipRing(List<LatLng> ring)`：把一條多邊形環裁切到可見半球。
  跨地平線的環要插入大圓交點，並沿著地平線圓弧接合，否則陸地會出現破洞或跨過球
  心的錯誤三角形。

**這是全案最大的技術風險**，用 TDD 驅動：先寫涵蓋「完全可見」「完全不可見」「單次
跨越地平線」「多次跨越地平線」「包住極點」的測試案例，再寫實作。

### `domain/globe/world_outline.dart`

載入並解析打包在 `frontend/assets/geo/` 的 Natural Earth 110m 陸地輪廓
（GeoJSON，約 200KB）。啟動時以 `compute()` 在背景 isolate 解析一次後快取，避免
阻塞第一幀。

### `presentation/widgets/globe_view.dart`

`CustomPaint` 由下而上畫：

1. 球體底：`#FCF8ED`。
2. 經緯網格（10 度）：`rgba(111,124,86,.17)`，線寬 0.7。
3. 陸地：填 `#CBD8A9`，描邊 `rgba(101,116,74,.42)`，線寬 0.7。
4. 打光：左上偏移的徑向漸層，中心白 50% → 邊緣暖褐 22%；外圈描邊
   `rgba(120,106,70,.3)`。
5. 故事小點：**地球儀只釘最近 7 篇**有座標的每日故事，落在可見半球的畫半徑 4.5 的
   `#5F7148` 圓、2px `#FCF8ED` 描邊，旁邊帶地名標籤（`Noto Sans TC` 600 11px，
   `#6E6350`）；標籤落在球體右側時改成靠右對齊。第 8 篇之後的故事不釘小點——rail
   捲到那些卡片時，只有下面那顆選中 pin 與 chip 會出現。

選中的地點不畫在 canvas 上，改用 Flutter widget 疊層：clay 色水滴 pin ＋ 紙卡
chip（`paper-raised` 底、`line` 邊框、pill 圓角、`e2` 陰影、serif 地名），位置由
`project()` 算出後以 `Positioned` 擺放，離開可見半球時淡出。

### 互動

- 拖曳旋轉：水平無限、垂直夾在 ±78 度，係數 0.32。
- rail 捲動切換選中故事時，950ms `easeOutCubic` 飛到該座標（目標緯度往上偏 8 度，
  讓 pin 落在球體偏上處）。
- 不支援縮放，不做閒置自轉。

## 首頁組成

`presentation/screens/globe_home_screen.dart`，`Stack` 由下而上：

1. 地球儀，置中，上下留白讓出頂部列與底部 rail。
2. 頂部：eyebrow「每日故事 · Daily Lore」＋ serif 字標 `Lorescape`；右側兩顆
   `paper-raised` 圓形 icon 按鈕——書本 → `/journey`，齒輪 → `/settings`。
3. 搜尋 bar：`paper-raised` 底、`e2` 陰影。輸入後 300ms debounce，呼叫既有的
   `WikipediaPlacesService.searchByText`（`generator=search`，回傳含座標的條目），
   取前 5 筆顯示建議清單。點建議 → `/map?q=<地名>`。
4. 右側單一 clay 色「定位」按鈕 → `/map`（無參數）。設計稿的第二顆「地圖」按鈕
   拿掉：它在設計稿裡是 fit 全部假資料景點，真實 App 沒有全球景點資料庫，留著會
   是一顆與定位重複的按鈕。
5. 底部 rail：`latestDailyStoryProvider` ＋ `dailyStoryHistoryProvider` 合併成最多
   30 篇，橫向 snap 卡片。上方一行 label「每日故事 · Anno MMXXVI」。
   - 第一張標 clay 色**「最新」**徽章。伺服器的每日故事 cron 目前關閉、改為手動
     發布，最新一篇未必是今天，所以不標「今日」。
   - 點非選中卡 → 捲到該卡並轉動地球儀；點選中卡 → push `DailyStoryDetailScreen`。
   - 下方分頁圓點指示目前位置。

載入中：先畫地球儀（維持預設旋轉），故事點與 rail 在資料到達後淡入。
無故事時：rail 換成一行提示文字，地球儀照常顯示。

## 詳細地圖模式

`ExploreScreen` 的改動只有兩處：

1. 接受一個可選的初始查詢字串。有值時掛載後執行既有的
   `placesControllerProvider.search(query)`，沒值時維持現有的附近景點行為。
2. 頂部按鈕列左側加一顆地球儀 icon 按鈕，`pop()` 回首頁。

定位權限缺失時的行為不變，沿用現有的 `_LocationGateCard`：點定位一律先進地圖，
在地圖上引導開啟權限。景點資料存在全域 Riverpod provider，回到首頁再進地圖不會
重新拉取。

## 轉場

`/map` 使用 go_router 的 `CustomTransitionPage`，640ms：

- 首頁（被覆蓋的一頁）讀 `secondaryAnimation`：地球儀 `scale 1 → 4.8` 並淡出，
  曲線 `Cubic(.55, 0, .85, .36)`；頂部列淡出；底部 rail 下滑並淡出。
- 地圖（新頁）讀 `animation`：淡入。

回程同一組動畫反播。

## 歷程與設定

兩張畫面本體不動，各自在左上角加一顆浮動返回鈕（`paper-raised` 底、`line` 邊框、
`e2` 陰影），並把 `Masthead` 左內距讓開，避免壓到返回鈕。

## 測試

Unit：

- `OrthographicProjection` 的投影、反投影、可見性、裁切（含跨地平線與包極點案例）。
- `WorldOutline` 解析。
- `DailyStory` 座標欄位的映射。

Widget（依 `flutter-widget-tests` skill 的規範）：

- rail 依 provider 資料渲染、第一張帶「最新」徽章、點卡片導向故事詳情。
- 搜尋輸入 debounce 後顯示建議、點建議導向 `/map?q=`。
- 定位鈕導向 `/map`。
- 右上兩顆 icon 分別導向 `/journey` 與 `/settings`。
- 歷程與設定的返回鈕會 pop。
- 座標為 null 的故事不影響 rail 渲染。

移除既有的 `MainScreen` 與 `StoryListScreen` 相關測試。地球儀不做 golden test
（canvas 內容在不同平台不穩定），改由投影單元測試覆蓋正確性。

`fvm flutter analyze --fatal-infos` 必須全綠。

## i18n

新增 `home.*` 系列 key（eyebrow、搜尋 placeholder、定位、最新徽章、rail label、
無故事提示、歷程與設定的無障礙標籤），zh-TW 與 en 兩份都要。移除 `bottom_nav.*`
與 `story.list_*`。

## Analytics

新路由沿用 `routeObserversProvider` 自動送出的 GA4 `screen_view`，`GoRoute` 都要
給 `name`。本次不新增自訂事件。

## 不做

- 地球儀縮放手勢、閒置自轉。
- 「搜尋這片區域」。
- 訂閱入口調整——維持從設定頁進入、額度用盡時觸發 paywall。
- 每日故事詳情、旅程詳情、訂閱頁、舊旅程列表這四張畫面的視覺對齊，另開 spec。
