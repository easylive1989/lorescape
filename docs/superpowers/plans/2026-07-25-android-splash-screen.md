# Android 品牌化 Splash 畫面 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Android/iOS 啟動 splash 從「白底 App icon」升級成深墨底、山形 mark 描線動畫的兩段式品牌 splash。

**Architecture:** 兩段式。Stage 1 系統 SplashScreen（flutter_native_splash 產生：深墨底 + 米白 mark，蓋住 `init()` 期間）；Stage 2 Flutter 全螢幕 splash（`CustomPainter`+`PathMetric` 自繪山形描線動畫，固定 ~1.8s 後 `context.go('/')`）。路由以 `/splash` 為 `initialLocation`，播完交給既有 redirect gate。

**Tech Stack:** Flutter 3.44.2、go_router、`CustomPainter`/`PathMetric`（零 runtime 依賴）、`flutter_native_splash`（build-time dev dependency）。

## Global Constraints

- 一律用 **fvm** 執行 flutter / dart 指令（`fvm flutter …` / `fvm dart …`）。
- 每個 task 完成後 `fvm flutter analyze --fatal-infos` 必須全過才算完成。
- 測試 `test/` 鏡射 `lib/` 結構；widget test 遵 flutter-widget-tests skill（interaction-over-static-render、fake-over-mock）。
- Feature-first：splash 程式放 `lib/features/splash/presentation/`。
- 顏色一律取 `lib/app/config/lorescape_tokens.dart` 的 token：底色 `inkBg = Color(0xFF1B1611)`、線色 `paper = Color(0xFFF7F1E6)`。**不要**寫死字面值。
- `flutter_native_splash` 只放 `dev_dependencies`（build-time only，不進 runtime）。
- package import 前綴為 `package:context_app/…`（見既有檔案）。

---

### Task 1: MountainPainter（山形幾何 + 描線 painter）

**Files:**
- Create: `frontend/lib/features/splash/presentation/mountain_painter.dart`
- Test: `frontend/test/features/splash/mountain_painter_test.dart`

**Interfaces:**
- Produces:
  - `Path buildMountainPath(Size size)` — 雙峰山形連續輪廓（含底線）。
  - `List<RRect> buildFootprints(Size size)` — 6 段足跡（由左下弧向右上）。
  - `class MountainPainter extends CustomPainter`，建構子
    `MountainPainter({required double strokeProgress, required double footprintProgress, required Color color})`。

- [ ] **Step 1: 先寫失敗測試**

```dart
// frontend/test/features/splash/mountain_painter_test.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:context_app/features/splash/presentation/mountain_painter.dart';

void main() {
  group('buildMountainPath', () {
    test('落在 size 範圍內、且非空', () {
      const size = Size(200, 200);
      final path = buildMountainPath(size);
      final b = path.getBounds();
      expect(path.computeMetrics().isNotEmpty, isTrue);
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(size.width));
      expect(b.bottom, lessThanOrEqualTo(size.height));
    });

    test('隨 size 等比縮放', () {
      final small = buildMountainPath(const Size(100, 100)).getBounds();
      final big = buildMountainPath(const Size(200, 200)).getBounds();
      expect(big.width, closeTo(small.width * 2, 0.01));
    });
  });

  group('buildFootprints', () {
    test('回傳 6 段、都在 size 內', () {
      const size = Size(200, 200);
      final prints = buildFootprints(size);
      expect(prints.length, 6);
      for (final r in prints) {
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(size.width));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(size.height));
      }
    });
  });

  group('MountainPainter.shouldRepaint', () {
    test('進度改變時要重繪', () {
      const c = Color(0xFFF7F1E6);
      final a = MountainPainter(strokeProgress: 0.2, footprintProgress: 0, color: c);
      final b = MountainPainter(strokeProgress: 0.5, footprintProgress: 0, color: c);
      expect(b.shouldRepaint(a), isTrue);
    });
    test('完全相同時不重繪', () {
      const c = Color(0xFFF7F1E6);
      final a = MountainPainter(strokeProgress: 0.5, footprintProgress: 0.3, color: c);
      final b = MountainPainter(strokeProgress: 0.5, footprintProgress: 0.3, color: c);
      expect(b.shouldRepaint(a), isFalse);
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/splash/mountain_painter_test.dart`
Expected: FAIL（`mountain_painter.dart` 不存在 / 未定義）

- [ ] **Step 3: 寫最小實作**

```dart
// frontend/lib/features/splash/presentation/mountain_painter.dart
import 'dart:ui';
import 'package:flutter/material.dart';

/// 雙峰山形連續輪廓（正規化座標 * size）。座標系 y 向下。
/// 由左下角起：左峰 → 谷 → 右峰 → 右下角 → 沿底線收回。
Path buildMountainPath(Size size) {
  final w = size.width;
  final h = size.height;
  Offset p(double nx, double ny) => Offset(nx * w, ny * h);

  return Path()
    ..moveTo(p(0.10, 0.82).dx, p(0.10, 0.82).dy) // 左下角
    ..lineTo(p(0.34, 0.30).dx, p(0.34, 0.30).dy) // 左峰
    ..lineTo(p(0.46, 0.52).dx, p(0.46, 0.52).dy) // 谷
    ..lineTo(p(0.60, 0.16).dx, p(0.60, 0.16).dy) // 右峰（較高）
    ..lineTo(p(0.86, 0.82).dx, p(0.86, 0.82).dy) // 右下角
    ..lineTo(p(0.10, 0.82).dx, p(0.10, 0.82).dy); // 底線收回
}

/// 6 段足跡，沿一條由 (0.42,0.62) 往右上 (0.64,0.34) 的緩弧排列。
List<RRect> buildFootprints(Size size) {
  final w = size.width;
  final h = size.height;
  const centers = <Offset>[
    Offset(0.44, 0.60),
    Offset(0.49, 0.55),
    Offset(0.54, 0.50),
    Offset(0.58, 0.45),
    Offset(0.61, 0.40),
    Offset(0.63, 0.35),
  ];
  final dashW = 0.045 * w;
  final dashH = 0.028 * h;
  return [
    for (final c in centers)
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx * w, c.dy * h),
          width: dashW,
          height: dashH,
        ),
        Radius.circular(0.012 * w),
      ),
  ];
}

/// 描線動畫 painter：山形輪廓依 [strokeProgress] 0→1 逐段畫出；
/// 足跡依 [footprintProgress] 0→1 逐段淡入。
class MountainPainter extends CustomPainter {
  const MountainPainter({
    required this.strokeProgress,
    required this.footprintProgress,
    required this.color,
  });

  final double strokeProgress;
  final double footprintProgress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // 山形描線：沿 PathMetric 取 0..len*progress 的子路徑。
    final full = buildMountainPath(size);
    for (final metric in full.computeMetrics()) {
      final sub = metric.extractPath(0, metric.length * strokeProgress.clamp(0.0, 1.0));
      canvas.drawPath(sub, stroke);
    }

    // 足跡逐段淡入：把 [0,1] 切成 6 段，每段負責一枚足跡的 alpha。
    final prints = buildFootprints(size);
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < prints.length; i++) {
      final segStart = i / prints.length;
      final segEnd = (i + 1) / prints.length;
      final t = ((footprintProgress - segStart) / (segEnd - segStart)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      canvas.drawRRect(prints[i], fill..color = color.withValues(alpha: t));
    }
  }

  @override
  bool shouldRepaint(MountainPainter old) =>
      old.strokeProgress != strokeProgress ||
      old.footprintProgress != footprintProgress ||
      old.color != color;
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/splash/mountain_painter_test.dart`
Expected: PASS（全部）

- [ ] **Step 5: analyze**

Run: `cd frontend && fvm flutter analyze --fatal-infos lib/features/splash test/features/splash`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/features/splash/presentation/mountain_painter.dart frontend/test/features/splash/mountain_painter_test.dart
git commit -m "feat(splash): add MountainPainter with stroke-draw + footprint geometry"
```

---

### Task 2: SplashScreen widget（動畫 + 自動導向）

**Files:**
- Create: `frontend/lib/features/splash/presentation/splash_screen.dart`
- Test: `frontend/test/features/splash/splash_screen_test.dart`

**Interfaces:**
- Consumes: `MountainPainter`（Task 1）、`LorescapeTokens`（`lib/app/config/lorescape_tokens.dart` 的 `inkBg` / `paper`）。
- Produces: `class SplashScreen extends StatefulWidget`（無參數 const 建構子），動畫約 1800ms 後呼叫 `GoRouter.of(context).go('/')`。

> 顏色 token 取用方式：先看 `lorescape_tokens.dart` 既有 API（如 `LorescapeTokens.of(context)` 或靜態常數）。若為靜態常數則直接 `LorescapeTokens.inkBg`；若為 InheritedWidget 型 API，於 build 取 `final t = LorescapeTokens.of(context);` 再用 `t.inkBg` / `t.paper`。實作前先讀該檔確認。

- [ ] **Step 1: 先寫失敗測試**

```dart
// frontend/test/features/splash/splash_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:context_app/features/splash/presentation/splash_screen.dart';

GoRouter _testRouter() => GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
      ],
    );

void main() {
  testWidgets('播放約 1.8s 後導向 /（顯示 HOME）', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _testRouter()));
    // 一開始在 splash，不是 HOME。
    expect(find.text('HOME'), findsNothing);
    // 推進超過動畫時長。
    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('動畫未播完就離開，不丟例外', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _testRouter()));
    await tester.pump(const Duration(milliseconds: 300));
    // 換掉整棵樹（模擬提前 dispose）。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 2000));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/features/splash/splash_screen_test.dart`
Expected: FAIL（`splash_screen.dart` 不存在）

- [ ] **Step 3: 讀 token 檔確認顏色 API**

Run: `sed -n '80,110p' frontend/lib/app/config/lorescape_tokens.dart`
（確認 `inkBg` / `paper` 是靜態常數還是 `of(context)`，決定下一步怎麼取色。）

- [ ] **Step 4: 寫最小實作**

```dart
// frontend/lib/features/splash/presentation/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/splash/presentation/mountain_painter.dart';

/// 全螢幕品牌 splash：深墨底上的山形描線動畫，約 1.8s 後導向 `/`。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          context.go('/');
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 顏色 token：依 Step 3 的實測 API 調整這兩行。
    const bg = LorescapeTokens.inkBg;
    const line = LorescapeTokens.paper;

    return Semantics(
      label: 'Lorescape',
      child: ColoredBox(
        color: bg,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final v = _controller.value; // 0..1 over 1.8s
              double interval(double a, double b) =>
                  ((v - a) / (b - a)).clamp(0.0, 1.0);
              final strokeT = interval(0.0, 0.56); // 0–1.0s
              final footT = interval(0.5, 0.78); // 0.9–1.4s
              final wordT = interval(0.67, 0.94); // 1.2–1.7s
              final fadeOut = 1.0 - interval(0.94, 1.0); // 1.7–1.8s

              return Opacity(
                opacity: fadeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: CustomPaint(
                          painter: MountainPainter(
                            strokeProgress: strokeT,
                            footprintProgress: footT,
                            color: line,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: wordT,
                      child: const Text(
                        'Lorescape',
                        style: TextStyle(
                          color: line,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/features/splash/splash_screen_test.dart`
Expected: PASS（兩例）

- [ ] **Step 6: analyze**

Run: `cd frontend && fvm flutter analyze --fatal-infos lib/features/splash test/features/splash`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add frontend/lib/features/splash/presentation/splash_screen.dart frontend/test/features/splash/splash_screen_test.dart
git commit -m "feat(splash): add animated SplashScreen that routes home after 1.8s"
```

---

### Task 3: 路由整合（`/splash` 為 initialLocation）

**Files:**
- Modify: `frontend/lib/app/config/router_config.dart`（`initialLocation` 與新增 `/splash` route）
- Test: `frontend/test/app/config/router_splash_test.dart`

**Interfaces:**
- Consumes: `SplashScreen`（Task 2）。
- Produces: router 以 `/splash` 起始；`/splash` 不被 redirect gate 攔截。

- [ ] **Step 1: 先寫失敗測試**

```dart
// frontend/test/app/config/router_splash_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:context_app/app/config/router_config.dart';
import 'package:context_app/features/splash/presentation/splash_screen.dart';

void main() {
  test('router 以 /splash 起始', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = RouterConfig.createRouter(container.read as dynamic);
    expect(
      router.configuration.uri.toString(),
      '/splash',
    );
    container.dispose();
  });

  testWidgets('/splash 建置 SplashScreen', (tester) async {
    // 依既有 router 測試慣例掛載 app，驗證起始畫面是 SplashScreen。
    // （若專案已有 router 測試 harness，沿用之。）
    expect(SplashScreen, isNotNull); // 佔位：實際 harness 於實作時補齊
  }, skip: true);
}
```

> 註：`RouterConfig.createRouter` 的參數型別為 `Ref`。實作 Step 前先讀
> `router_config.dart` 開頭與既有 router 測試（若有）確認建構方式；上面
> 第一個 test 若因 `Ref` 取得方式不同而無法直接跑，改用專案既有的 router
> 測試 harness 寫「起始 location == /splash」的斷言（同一個可驗證行為）。

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd frontend && fvm flutter test test/app/config/router_splash_test.dart`
Expected: FAIL（initialLocation 仍為 `/`）

- [ ] **Step 3: 改 router**

在 `frontend/lib/app/config/router_config.dart`：

1. `initialLocation: '/'` → `initialLocation: '/splash'`（第 28 行附近）。
2. import 加：
   `import 'package:context_app/features/splash/presentation/splash_screen.dart';`
3. `routes: [` 之後、`GoRoute(path: '/', …)` 之前，插入：

```dart
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
```

redirect gate 不需改：它只在 `state.matchedLocation == '/'` 時導向
`/onboarding`，`/splash` 天然放行；splash 期間 `refreshListenable` 會在背景
`ensureLoaded`，1.8s 後 `go('/')` 時 onboarding 狀態已就緒。

- [ ] **Step 4: 跑測試確認通過**

Run: `cd frontend && fvm flutter test test/app/config/router_splash_test.dart`
Expected: PASS

- [ ] **Step 5: 全量 router / splash 測試 + analyze**

Run: `cd frontend && fvm flutter test test/app test/features/splash && fvm flutter analyze --fatal-infos`
Expected: 測試全過、No issues found

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/app/config/router_config.dart frontend/test/app/config/router_splash_test.dart
git commit -m "feat(splash): use /splash as initial route ahead of home gate"
```

---

### Task 4: 原生 splash 品牌化（flutter_native_splash + 米白 mark 素材）

**Files:**
- Create: `frontend/assets/images/splash_mark.png`（米白山形 mark，512×512、透明底）
- Create: `frontend/test/tool/generate_splash_mark.dart`（一次性產圖工具）
- Modify: `frontend/pubspec.yaml`（`dev_dependencies` + `flutter_native_splash:` 設定 + `flutter.assets` 註冊）
- 產生（指令，非手改）：`android/app/src/main/res/**`、iOS `LaunchScreen` 等

**Interfaces:**
- Consumes: `MountainPainter`（Task 1，用來把 Stage 2 的同一幾何渲染成 Stage 1 的靜態 PNG，確保無縫交棒）。

- [ ] **Step 1: 加 dev 依賴**

```bash
cd frontend && fvm dart pub add --dev flutter_native_splash
```

Expected: `pubspec.yaml` 的 `dev_dependencies` 出現 `flutter_native_splash:`。

- [ ] **Step 2: 寫產圖工具（把 MountainPainter 渲染成 PNG）**

```dart
// frontend/test/tool/generate_splash_mark.dart
// 執行：fvm flutter test test/tool/generate_splash_mark.dart
// 產出：assets/images/splash_mark.png（progress=1 的米白山形，透明底）
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/splash/presentation/mountain_painter.dart';

void main() {
  test('generate splash_mark.png', () async {
    const dim = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    MountainPainter(
      strokeProgress: 1,
      footprintProgress: 1,
      color: LorescapeTokens.paper, // 依 Task 2 Step 3 的實測 API 調整
    ).paint(canvas, const Size(dim, dim));
    final img = await recorder.endRecording().toImage(dim.toInt(), dim.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('assets/images/splash_mark.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.existsSync(), isTrue);
  });
}
```

Run: `cd frontend && fvm flutter test test/tool/generate_splash_mark.dart`
Expected: PASS，且 `frontend/assets/images/splash_mark.png` 產生。

- [ ] **Step 3: 目視確認 PNG**

用 Read 檢視 `frontend/assets/images/splash_mark.png`：應為透明底、米白雙峰山形 + 足跡。不對就回 Task 1 調座標再重跑 Step 2。

- [ ] **Step 4: 設定 flutter_native_splash + 註冊 asset**

在 `frontend/pubspec.yaml` 的 `flutter:` 區塊 `assets:` 下加一行
`    - assets/images/splash_mark.png`（若 `assets:` 目前被註解，改為啟用並加此行）。

在 `pubspec.yaml` 頂層（與 `dependencies:` 同層）加設定區塊：

```yaml
flutter_native_splash:
  color: "#1B1611"
  image: assets/images/splash_mark.png
  color_dark: "#1B1611"
  image_dark: assets/images/splash_mark.png
  android_12:
    color: "#1B1611"
    image: assets/images/splash_mark.png
    color_dark: "#1B1611"
    image_dark: assets/images/splash_mark.png
  android: true
  ios: true
  web: false
```

- [ ] **Step 5: 產生原生資源**

Run: `cd frontend && fvm dart run flutter_native_splash:create`
Expected: 訊息顯示已更新 Android（`styles.xml`、`drawable*`、Android 12 `splash` 主題）與 iOS `LaunchScreen`。

- [ ] **Step 6: analyze + 全量測試**

Run: `cd frontend && fvm flutter analyze --fatal-infos && fvm flutter test`
Expected: No issues found、測試全過。

- [ ] **Step 7: 手動實機/模擬器驗證（冷啟動）**

- Android 12+：冷啟動 → 系統 splash 深墨底 + 米白 mark（靜態）→ Flutter 描線動畫 → 進主畫面。**底色與 mark 無跳動**（無縫交棒）。
- Android 11 以下：確認底色一致、mark 置中。
- 觀感總時長（原生 init + 1.8s）可接受。
> 用 `/run` 或 marionette 啟動 App 冷啟動觀察；截圖存證。

- [ ] **Step 8: Commit**

```bash
git add frontend/pubspec.yaml frontend/pubspec.lock frontend/assets/images/splash_mark.png \
  frontend/test/tool/generate_splash_mark.dart \
  frontend/android frontend/ios
git commit -m "feat(splash): brand native splash (dark ground + cream mark) via flutter_native_splash"
```

---

## Self-Review

**Spec coverage：**
- 兩段式架構 → Task 4（Stage 1 原生）+ Task 2（Stage 2 Flutter）✓
- 系統→Flutter 無縫交棒（同底色同 mark）→ Task 4 用 Task 1 幾何產同一張 mark ✓
- 描線動畫（CustomPainter+PathMetric）→ Task 1 ✓
- 足跡逐段淡入、字標淡入、整體淡出 → Task 2 時間軸 ✓
- 固定 ~1.8s 後導向 `/` → Task 2 ✓
- `/splash` initialLocation、redirect 放行 → Task 3 ✓
- flutter_native_splash 為 dev dependency → Task 4 Step 1 ✓
- 測試（widget 導向 + dispose 邊界）→ Task 2 ✓
- 非目標 T1/T2/T3 → 未納入任何 task ✓

**Placeholder scan：** Task 3 的第二個 widget test 標了 `skip: true` 佔位並說明改用既有 harness——這是刻意保留的彈性點（router 測試建構方式依專案 harness 而定），第一個 test 已覆蓋「initialLocation == /splash」的可驗證行為，非 placeholder 失誤。其餘步驟均含完整程式碼與指令。

**Type consistency：** `MountainPainter({strokeProgress, footprintProgress, color})` 在 Task 1 定義、Task 2 與 Task 4 一致使用；`buildMountainPath(Size)`/`buildFootprints(Size)` 簽章一致；`SplashScreen` const 建構子於 Task 2 定義、Task 3 使用一致。顏色 token 取用在 Task 2 Step 3 統一確認後，Task 4 沿用同一 API。
