# 旅程空狀態：插圖 ＋ 引導至探索頁

日期：2026-07-27

## 背景

點進某本旅程（`/trip/:id`）而裡面沒有任何記錄時，畫面上只有一行灰字
「此旅程尚無任何記錄」（`trip_detail_screen.dart:506-519`）。這個空狀態只有
敘述沒有出口——新使用者第一次進來，看到的是一頁死巷。

本設計為這個空狀態加上插圖、一句引導文案，以及一顆導向探索頁的按鈕。

## 範圍

- **做**：一般旅程詳情頁（`/trip/:id`）的空狀態。
- **連帶**：`_ItemsList` 同時服務「未分類」頁（`/trip/uncategorized`），
  因此同一個空狀態也會出現在那裡。文案共用一份、不分岔——「這本旅程」
  對未分類頁一樣讀得通。
- **不做**：歷程首頁書架的空狀態、CTA 點擊埋點。兩者可另開 task。

## 設計

### 1. 新元件

新增 `frontend/lib/features/trip/presentation/widgets/trip_empty_state.dart`，
匯出 `TripEmptyState`（無參數、`const` 可建構）。

版面由上到下置中：

```
   [插圖 max 200×200]
   此旅程尚無任何記錄              ← titleMedium, onSurface
   到探索頁找一個眼前的景點，
   聽它的故事，就會收進這本旅程     ← bodyMedium, onSurfaceVariant, 置中
   [ 去探索景點 ]                  ← AdaptiveButton (filled)
```

實作要點：

- 外層用 `SingleChildScrollView` 包住，小螢幕不 overflow。
- 插圖用 `ExcludeSemantics` 包起來（純裝飾），語意由按鈕承擔。
- 插圖 `Image.asset(..., fit: BoxFit.contain)`，寬高上限 200。

`_ItemsList` 的 `items.isEmpty` 分支改成只回傳 `const TripEmptyState()`。
`trip_detail_screen.dart` 目前 644 行，抽出元件可避免此檔繼續長胖，也讓空
狀態能被單獨做 widget test。

### 2. 導航

按鈕 `onPressed: () => context.go('/?tab=explore')`。

用 `go` 而非 `push`：把 `/trip/:id` 這層整個換掉，使用者按下引導後不會再用
返回鍵退回那本空旅程。router 已支援 `tab` query
（`router_config.dart:68-73`，`'explore' => 1`）。

### 3. 素材

- 路徑：`frontend/assets/images/empty_trip.png`
- **pubspec 不需修改**——已宣告整個 `assets/images/` 目錄。
- 透明背景 PNG，1024×1024 產出，由 Flutter 縮放。
- App 只有淺色「Field Journal」主題（`theme_config.dart:19`），單一版本即可。

生成提示詞（手繪旅行手帳風）：

```
A hand-drawn travel journal illustration: an open blank notebook lying flat,
its two pages empty and cream-colored, with a fountain pen resting in the
gutter and a folded paper map peeking out from under one corner. A few loose
sketch marks suggest a compass rose in the top corner of the page.

Style: loose ink line work with soft watercolor washes, warm and muted palette
— terracotta, ochre, sepia brown, faded olive, aged paper cream. Visible
pencil under-drawing and slightly uneven linework, like a page from a
traveler's sketchbook. Gentle, inviting, a little wistful — an empty page
waiting to be filled, not a sad or broken state.

Composition: single centered object, generous negative space around it,
no text, no letters, no words anywhere in the image. Fully transparent
background (PNG with alpha), no drop shadow, no frame, no border.
Square 1:1, 1024x1024, flat front-on view, no photorealism, no 3D render.
```

### 4. 文案

`assets/translations/zh-TW.json` 與 `en.json` 的 `trip` 區塊各新增兩把 key：

| key | zh-TW | en |
|---|---|---|
| `trip.no_items` | 此旅程尚無任何記錄（沿用，不動） | （不動） |
| `trip.empty_hint` | 到探索頁找一個眼前的景點，聽它的故事，就會收進這本旅程 | Find a place in front of you on Explore, listen to its story, and it lands in this journal |
| `trip.empty_cta` | 去探索景點 | Explore places |

### 5. 測試

`frontend/test/features/trip/presentation/screens/trip_detail_screen_test.dart`：

- 既有的 `then the empty state is rendered`（:138）改為斷言插圖、`trip.no_items`、
  `trip.empty_hint`、`trip.empty_cta` 皆在畫面上。既有 helper 在 :569，
  用的是原始 key 字串（測試環境未載入翻譯）。
- 新增一則：點下 CTA 後導航到 `/?tab=explore`。router 測法依
  flutter-widget-tests skill。

元件本身不另開測試檔：`TripEmptyState` 沒有自己的狀態或 callback，導航行為
只有透過 router 才驗得出來，上面那兩則螢幕層測試已完整覆蓋，再寫一份只會
重複斷言同樣的三個元素。

### 6. 驗收

- `fvm flutter analyze --fatal-infos` 無任何問題。
- `fvm flutter test` 全綠。

## 決策紀錄

- **抽成獨立 widget 而非 inline 改**：`trip_detail_screen.dart` 已 644 行；
  專案既有 `features/trip/presentation/widgets/` 慣例（trip_card、trip_grid、
  move_to_trip_sheet）。
- **`go` 而非 `push`**：空旅程不值得留在返回堆疊裡。
- **不做通用 `EmptyState` shared widget**：目前只有一處要用，YAGNI。
