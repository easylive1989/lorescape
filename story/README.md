# vn — 龐貝景點包視覺小說

直式手機視覺小說引擎，播放 `writer/創作/龐貝/` 的 8 篇群像短篇。
目前跑 **Flutter Web** 做驗證，確認後整包搬進 `frontend/lib/features/visual_novel/`。

## 先決條件

素材與劇本來自 **`writer/`（Obsidian vault，不在版控裡）**。首次 clone 後必須先匯入：

```bash
python3 story/tool/import_pack.py
```

沒跑這一步的話，`assets/content/pompeii-79/assets/` 是空的，測試會失敗、畫面會全黑。

## 執行

```bash
cd vn
fvm flutter pub get
fvm flutter run -d chrome        # Web 驗證
fvm flutter test                 # 全部測試
fvm flutter analyze --fatal-infos
```

## 結構

`lib/src/visual_novel/` 是**可整包搬移**的模組：

- `domain/` — 零 Flutter 依賴的劇本模型與執行器
- `data/` — `story.json` parser、bundle repository、`SharedPreferences` 存檔
- `presentation/` — 直式版面（版面數值全在 `play/layout.dart`）
- `providers.dart` — **唯一**公開介面

## 規格來源

- 版面、`story.json` schema、必備功能：`writer/製作規範/Flutter製作規範.md`
- 設計決策：`docs/superpowers/specs/2026-08-13-pompeii-vn-flutter-design.md`
