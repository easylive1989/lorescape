# 旅程空狀態插圖與探索引導 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓沒有任何記錄的旅程頁不再是死巷——補上插圖、一句引導文案，以及一顆把使用者帶到探索頁的按鈕。

**Architecture:** 把 `trip_detail_screen.dart` 內 `_ItemsList` 的空狀態分支抽成獨立 widget `TripEmptyState`，放在既有的 `features/trip/presentation/widgets/`。按鈕用 `context.go('/?tab=explore')` 換掉整個導航堆疊。插圖以 `Image.asset` + `errorBuilder` 載入，缺圖時退回等高留白，因此程式碼不必等素材就緒。

**Tech Stack:** Flutter（fvm）、Riverpod、go_router、easy_localization、專案自有的 `AdaptiveButton`。

**Spec:** `docs/superpowers/specs/2026-07-27-trip-empty-state-design.md`

## Global Constraints

- 所有 flutter / dart 指令一律透過 `fvm` 執行，工作目錄為 `frontend/`。
- 程式碼註解與文件用繁體中文（技術名詞除外）。
- 每次改動後 `fvm flutter analyze --fatal-infos` 必須零問題才算完成。
- **不得修改 `frontend/pubspec.yaml`**——`assets/images/` 目錄已宣告在
  `flutter.assets` 下，新增檔案不需要再登記。
- i18n key 一律同時加到 `assets/translations/zh-TW.json` 與 `en.json`，
  兩邊 key 集合必須一致。
- 測試環境的 `AssetLoader` 回傳空翻譯（`test/helpers/pump_app.dart`），所以
  測試斷言比對的是**原始 i18n key 字串**，例如 `find.text('trip.no_items')`，
  不是中文譯文。
- 現有文案 key `trip.no_items`（「此旅程尚無任何記錄」）**沿用不改**。

## File Structure

| 檔案 | 動作 | 責任 |
|---|---|---|
| `frontend/lib/features/trip/presentation/widgets/trip_empty_state.dart` | 新增 | 空狀態的完整版面：插圖、標題、引導句、CTA 按鈕與其導航行為 |
| `frontend/lib/features/trip/presentation/screens/trip_detail_screen.dart` | 修改（`:506-519`） | `_ItemsList` 的 `items.isEmpty` 分支改為回傳 `const TripEmptyState()` |
| `frontend/assets/translations/zh-TW.json` | 修改 | 新增 `trip.empty_hint`、`trip.empty_cta` |
| `frontend/assets/translations/en.json` | 修改 | 同上 |
| `frontend/test/features/trip/presentation/screens/trip_detail_screen_test.dart` | 修改 | 更新既有空狀態斷言；新增 CTA 導航測試 |
| `frontend/assets/images/empty_trip.png` | 新增（Task 2） | 插圖素材本體 |

不另開 `trip_empty_state_test.dart`：`TripEmptyState` 沒有自己的狀態或
callback，導航行為只有透過 router 才驗得出來，螢幕層測試已完整覆蓋。

---

### Task 1: 空狀態元件與探索引導

**Files:**
- Create: `frontend/lib/features/trip/presentation/widgets/trip_empty_state.dart`
- Modify: `frontend/lib/features/trip/presentation/screens/trip_detail_screen.dart:506-519`
- Modify: `frontend/assets/translations/zh-TW.json`（`trip` 區塊）
- Modify: `frontend/assets/translations/en.json`（`trip` 區塊）
- Test: `frontend/test/features/trip/presentation/screens/trip_detail_screen_test.dart`

**Interfaces:**
- Consumes：`AdaptiveButton`（`lib/shared/widgets/adaptive/adaptive_widgets.dart`，
  建構子必填 `onPressed` 與 `child`，`style` 預設 `AdaptiveButtonStyle.filled`）；
  測試 helper `pumpRouterApp`（`test/helpers/pump_app.dart`）。
- Produces：`class TripEmptyState extends StatelessWidget`，建構子
  `const TripEmptyState({super.key})`，無其他參數。Task 2 依賴它引用的
  asset key 字串 `'assets/images/empty_trip.png'`。

- [ ] **Step 1: 加入兩把 i18n key**

在 `frontend/assets/translations/zh-TW.json` 的 `"trip"` 物件內，緊接在
`"no_items"` 那一行之後插入：

```json
    "empty_hint": "到探索頁找一個眼前的景點，聽它的故事，就會收進這本旅程",
    "empty_cta": "去探索景點",
```

在 `frontend/assets/translations/en.json` 的 `"trip"` 物件內，同樣緊接在
`"no_items"` 之後插入：

```json
    "empty_hint": "Find a place in front of you on Explore, listen to its story, and it lands in this journal",
    "empty_cta": "Explore places",
```

- [ ] **Step 2: 更新既有空狀態測試的斷言（先寫失敗的測試）**

在 `trip_detail_screen_test.dart` 的 import 區塊加入：

```dart
import 'package:context_app/features/trip/presentation/widgets/trip_empty_state.dart';
```

把檔案底部既有的 `_thenEmptyStateIsVisible()` helper 整個換掉：

```dart
void _thenEmptyStateIsVisible() {
  expect(find.byType(TripEmptyState), findsOneWidget);
  expect(find.text('trip.no_items'), findsOneWidget);
  expect(find.text('trip.empty_hint'), findsOneWidget);
  expect(find.text('trip.empty_cta'), findsOneWidget);
}
```

- [ ] **Step 3: 新增 CTA 導航測試**

在 `trip_detail_screen_test.dart` 的 `group('TripDetailScreen', ...)` 內，
接在既有那則 `then the empty state is rendered`（約 `:136-150`）之後加入：

```dart
    testWidgets(
      'given a trip with no entries, when the user taps the explore CTA, '
      'then the app leaves the trip and lands on the explore tab',
      (tester) async {
        final visitedLocations = <String>[];

        await _givenEmptyTripScreenWithRouter(
          tester,
          visitedLocations: visitedLocations,
        );

        await tester.tap(find.text('trip.empty_cta'));
        await tester.pumpAndSettle();

        // 用 go 而非 push：空旅程不該留在返回堆疊裡。
        expect(visitedLocations, contains('/?tab=explore'));
      },
    );
```

在檔案底部、緊接 `_givenTripDetailScreenWithRouter` 之後加入這個 helper：

```dart
/// 直接開在一本沒有任何記錄的旅程上，並記下每次落在首頁的完整 URI。
Future<void> _givenEmptyTripScreenWithRouter(
  WidgetTester tester, {
  required List<String> visitedLocations,
}) async {
  await pumpRouterApp(
    tester,
    initialLocation: '/trip/empty',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) {
          visitedLocations.add(state.uri.toString());
          return const Scaffold(key: ValueKey('home-screen'));
        },
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (_, _) => const TripDetailScreen(tripId: 'empty'),
      ),
    ],
    overrides: [
      tripRepositoryProvider.overrideWithValue(InMemoryTripRepository()),
      journeyRepositoryProvider.overrideWithValue(InMemoryJourneyRepository()),
    ],
  );
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}
```

- [ ] **Step 4: 跑測試確認失敗**

```bash
cd frontend && fvm flutter test test/features/trip/presentation/screens/trip_detail_screen_test.dart
```

Expected: 編譯失敗，`Error: Couldn't resolve the package 'context_app/features/trip/presentation/widgets/trip_empty_state.dart'`——元件還沒建立。

- [ ] **Step 5: 建立 `TripEmptyState` 元件**

新增 `frontend/lib/features/trip/presentation/widgets/trip_empty_state.dart`：

```dart
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 旅程（含「未分類」）沒有任何記錄時的空狀態。
///
/// 只有一行灰字的空狀態是條死巷——第一次進來的使用者看不出記錄是從哪裡長出
/// 來的。這裡補上插圖與一顆把人帶回探索頁的按鈕。
class TripEmptyState extends StatelessWidget {
  const TripEmptyState({super.key});

  /// 插圖尚未進版控時 `Image.asset` 會丟例外，由 `errorBuilder` 退回等高留白，
  /// 程式碼因此不必等素材就緒。詳見設計文件的「缺圖時的行為」。
  static const String _illustration = 'assets/images/empty_trip.png';
  static const double _illustrationSize = 200;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Center 讓內容在空間充裕時置中，SingleChildScrollView 則保證小螢幕
    // 不會 overflow。
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 純裝飾，語意交給下方的標題與按鈕承擔。
            ExcludeSemantics(
              child: Image.asset(
                _illustration,
                width: _illustrationSize,
                height: _illustrationSize,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const SizedBox(height: _illustrationSize),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'trip.no_items'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'trip.empty_hint'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            AdaptiveButton(
              // go 而非 push：使用者按下引導後不該還能退回這本空旅程。
              onPressed: () => context.go('/?tab=explore'),
              child: Text('trip.empty_cta'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: 把 `_ItemsList` 接上新元件**

在 `trip_detail_screen.dart` 的 import 區塊加入：

```dart
import 'package:context_app/features/trip/presentation/widgets/trip_empty_state.dart';
```

把 `_ItemsList.build` 內 `:506-519` 的整段：

```dart
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'trip.no_items'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
```

換成：

```dart
        if (items.isEmpty) return const TripEmptyState();
```

- [ ] **Step 7: 跑測試確認通過**

```bash
cd frontend && fvm flutter test test/features/trip/presentation/screens/trip_detail_screen_test.dart
```

Expected: 全部 PASS，包含新增的 CTA 導航那則。

- [ ] **Step 8: 跑完整測試與 analyze**

```bash
cd frontend && fvm flutter test && fvm flutter analyze --fatal-infos
```

Expected: 測試全綠；analyze 輸出 `No issues found!`。

- [ ] **Step 9: Commit**

```bash
git add frontend/lib/features/trip/presentation/widgets/trip_empty_state.dart \
        frontend/lib/features/trip/presentation/screens/trip_detail_screen.dart \
        frontend/assets/translations/zh-TW.json \
        frontend/assets/translations/en.json \
        frontend/test/features/trip/presentation/screens/trip_detail_screen_test.dart
git commit -m "feat(trip): 旅程空狀態補上插圖與前往探索頁的引導"
```

---

### Task 2: 插圖素材落地

**Files:**
- Create: `frontend/assets/images/empty_trip.png`

**Interfaces:**
- Consumes：Task 1 的 `TripEmptyState._illustration`，其值為
  `'assets/images/empty_trip.png'`；檔名與路徑必須逐字相符。
- Produces：無程式介面。素材就位後 `errorBuilder` 的留白會自動被真圖取代，
  **不需要修改任何程式碼**。

- [ ] **Step 1: 生成插圖**

在 Antigravity 用以下提示詞生成，取 1024×1024、**透明背景** PNG：

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

- [ ] **Step 2: 存到指定路徑**

存成 `empty_trip.png`，放進 `frontend/assets/images/`（與
`location_gate.png`、`splash_mark.png` 同一層，不開子資料夾）。

- [ ] **Step 3: 確認透明度與檔案大小**

```bash
file frontend/assets/images/empty_trip.png
du -h frontend/assets/images/empty_trip.png
```

Expected: `file` 輸出含 `RGBA`；若是 `RGB` 代表輸出成不透明白底，在淺色卡片
上會出現一塊白方框，需回 Step 1 重生或用影像工具去背。
大小應 ≤ 300 KB；超過先跑一次 `pngquant --quality=65-85 --ext .png --force
frontend/assets/images/empty_trip.png` 再量一次。

- [ ] **Step 4: 實機確認**

```bash
cd frontend && fvm flutter run
```

新增 asset 需**熱重啟**（在 `flutter run` 的 console 按 `R`，hot reload 的
`r` 不夠）。進到任一本沒有記錄的旅程，確認插圖顯示、沒有白方框、與文案和
按鈕的間距看起來平衡。

- [ ] **Step 5: 跑測試與 analyze**

```bash
cd frontend && fvm flutter test && fvm flutter analyze --fatal-infos
```

Expected: 與 Task 1 結束時相同，全綠。素材就位不會改變任何斷言——測試不依賴
圖片存在。

- [ ] **Step 6: Commit**

```bash
git add frontend/assets/images/empty_trip.png
git commit -m "assets(trip): 加入旅程空狀態插圖"
```
