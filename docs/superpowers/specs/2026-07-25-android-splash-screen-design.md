# Android 品牌化 Splash 畫面 — 設計 spec

> 日期：2026-07-25　範圍：Frontend（Flutter）啟動 splash（Play Console 「T4」）

## 目標

把 Android 啟動時那個「白底藍 App icon」的系統 splash，升級成一段
**品牌化的兩段式 splash**：深墨底上的山形 mark 描線動畫。iOS 一併沿用同樣的
原生 splash 設定（免得只有單平台品牌化）。

## 非目標（明確排除）

- **T1 edge-to-edge**（Android 15 無邊框 opt-in）、**T2 R8/shrink**、**T3 點陣圖降取樣**
  ——各自獨立 task，不在本 spec。
- 不改任何既有畫面的 UI、不動 onboarding 流程本身。
- 不做「等 App 初始化完成才收場」的動態時機（見下方取捨，已定為固定時長）。

## 關鍵前提（啟動流程實況）

`lib/main.dart` 的 `init()` 在 `runApp` **之前**就 `await` 完成所有重初始化
（Firebase / App Check / Supabase / 匿名登入 / RevenueCat / SharedPreferences）。
因此：

- 目前使用者看到的系統 icon splash，是**蓋在 `init()` 這段網路請求上**
  （冷啟動可能 1–3 秒）。
- Flutter 畫第一幀時，初始化早已完成。
- 故 Flutter 全螢幕 splash（固定 ~1.8s）**是加在系統 splash 之後**，
  總冷啟動 ≈ 原生初始化時間 + 1.8s。這是「品牌感 vs 進內容速度」的取捨，
  已與需求方確認**接受 +1.8s**。

## 架構：兩段式 splash

### Stage 1 — 系統 SplashScreen（涵蓋 `init()` 期間）

- 背景色 `#1B1611`（深墨，token `inkBg`）。
- 置中圖案：**米白山形 mark**（`#F7F1E6`，token `paper`）。
- 目的：跟 Stage 2 同底色、同 mark，讓系統 splash → Flutter splash **無縫交棒**
  （使用者不會看到底色或 logo 跳動）。
- Android 12+ 的系統 SplashScreen 只能「置中 icon + 純色底」，這正好夠用；
  不追求系統層全螢幕圖（做不到）。

### Stage 2 — Flutter 全螢幕 splash（固定 ~1.8s）

同深墨底 `#1B1611` 全螢幕。動畫時間軸（總長約 1.8s）：

| 時間 | 動作 |
|---|---|
| 0.0–1.0s | 山形**輪廓描線**畫出（stroke 進度 0→1），米白線條 |
| 0.9–1.4s | 足跡 6 段**逐段淡入**（stagger） |
| 1.2–1.7s | 「Lorescape」serif 字標於 mark 下方淡入 |
| 1.7–1.8s | 整體淡出 → `context.go('/')` |

播完（或 widget dispose 時）導向 `/`，交給既有 redirect gate 決定 onboarding/home。

## 元件與檔案

### 新增

- `lib/features/splash/presentation/splash_screen.dart`
  - `SplashScreen`：`StatefulWidget` + 單一 `AnimationController`（~1.8s）。
  - 深墨底 `Scaffold`／`ColoredBox`，中央擺 `CustomPaint`（山形）＋下方字標。
  - `initState` 起動畫；於 ~1.8s 後（`status == completed`）呼叫
    `context.go('/')`。用 `mounted` 防護。
- `lib/features/splash/presentation/mountain_painter.dart`
  - `MountainPainter extends CustomPainter`：
    - 以相對座標（`Size` 正規化）重建**雙峰山形輪廓** `Path`。
    - `PathMetric.extractPath(0, length * progress)` 畫描線 stroke。
    - 足跡 6 段各自的 `Path`／位置，依 `progress` 分段淡入（透明度）。
    - 線色 `#F7F1E6`，`strokeWidth`、`strokeCap.round`、`strokeJoin.round`。
  - `shouldRepaint` 依 `progress` 判斷。
- （素材）`assets/images/splash_mark.png`：**米白山形 mark**（僅系統 splash Stage 1 用；
  Flutter 端 Stage 2 用 `CustomPainter` 自繪，不吃這張）。由現有 mark 轉白／重繪，
  透明背景、正方形、留白邊界符合 Android 12 splash icon 安全區。

### 修改

- `pubspec.yaml`
  - `dev_dependencies` 加 `flutter_native_splash`（**build-time only**，不進 runtime）。
  - 加 `flutter_native_splash:` 設定區塊：`color: "#1B1611"`、
    `image: assets/images/splash_mark.png`、`android_12: { color, image }`、
    `color_dark` / `image_dark` 同值（深底本就適用暗色）。
  - `flutter.assets` 註冊 `assets/images/splash_mark.png`。
- `lib/app/config/router_config.dart`
  - `initialLocation` 改為 `/splash`。
  - 新增 `GoRoute(path: '/splash', name: 'splash', builder: … SplashScreen())`。
  - redirect gate 現況只在 `matchedLocation == '/'` 動作，`/splash` 天然放行；
    splash 期間 `refreshListenable` 會在背景 `ensureLoaded` onboarding，
    1.8s 後 `go('/')` 時狀態已就緒、**不會閃 onboarding**。無需改 redirect 條件。

### 產生（一次性指令，不進版控邏輯）

- `dart run flutter_native_splash:create`（在 `frontend/`，用 `fvm`）：
  依上述設定產生 `android/.../styles.xml`、`drawable*/`、iOS `LaunchScreen` 等原生資源。

## 錯誤處理與邊界

- **導向失敗防護**：動畫完成後 `if (!mounted) return;` 再 `context.go('/')`。
- **重進 splash**：`/splash` 只在 `initialLocation` 出現；deep link 直接進各自路由、
  不經 splash（deep link 場景不該被 1.8s 擋）。→ 確認 deep link（如 `/player`、
  `/:locale/story/:date`）仍以各自 path 為進入點，不受影響。
- **動畫效能**：`CustomPainter` 只重繪山形區域；`RepaintBoundary` 包住
  `CustomPaint` 避免全頁重繪。
- **無障礙**：splash 純視覺，加 `Semantics(label: 'Lorescape')` 於根節點。

## 測試

- **Widget test**（`test/features/splash/splash_screen_test.dart`，遵 flutter-widget-tests skill）：
  - 建立 `SplashScreen` 於測試用 router，`pump` 若干時間後
    **驗證有導向 `/`**（用假 router 觀察 location，interaction-over-static-render）。
  - 邊界：dispose 中途（未播完就離開）不應 `go`／不報 `setState after dispose`。
- **MountainPainter**：純函式性質，可用 golden 或對 `progress=0/0.5/1` 的
  `paint` 呼叫做輕量驗證（非必要，golden 視情況）。
- **手動驗證清單**：
  - Android 12+ 實機／模擬器冷啟動：系統 splash 深墨底 + 米白 mark → Flutter
    描線動畫 → 進主畫面，底色/mark **無跳動**。
  - Android 11 以下：flutter_native_splash 會用全螢幕圖路徑，確認底色一致。
  - 冷啟動總時長觀感可接受（原生 init + 1.8s）。
  - `fvm flutter analyze --fatal-infos` 全過。

## 取捨紀錄

- **固定 1.8s vs 等初始化**：選固定，簡單、可預期；代價是對 `init()` 較慢的裝置
  splash 為額外附加時間（不與 init 重疊，因 init 早於首幀完成）。
- **flutter_native_splash vs 手改 styles.xml**：選前者，跨 iOS/Android 與明暗色
  一致、少手工 XML 出錯；代價是多一個 build-time dev 依賴（可接受，不進 runtime）。
- **CustomPainter vs 動畫套件（rive/lottie）**：選前者，零 runtime 依賴、無向量原始檔
  也能自繪；代價是山形 `Path` 需手工重建座標（一次性）。
