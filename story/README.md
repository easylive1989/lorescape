# story — 景點包視覺小說

直式手機視覺小說引擎。目前有兩個景點包：

| 包 | 來源 | 狀態 |
|---|---|---|
| **龐貝 79** | `writer/創作/龐貝/` | 8 篇，完成 |
| **凡爾賽 1789** | `writer/創作/凡爾賽/` | **1/8 篇，製作中** |

App 首頁是書架（`/`），選包進 `/pack/:packId`，再選篇進 `/play/:storyId`。
目前跑 **Flutter Web** 做驗證，確認後整包搬進 `frontend/lib/features/visual_novel/`。

## 先決條件

素材與劇本來自 **`writer/`（Obsidian vault）**。美術定版原圖與 `story.json` 都在
版控裡；`.gitignore` 只擋 `美術測試/_processed/`（快取）與 `stories/*/assets/`
（匯入產生的 WebP），兩者都由匯入腳本重生。首次 clone 後必須先匯入**每一個包**：

```bash
python3 story/tool/import_pack.py                          # 龐貝
python3 story/tool/import_pack.py --pack versailles --partial   # 凡爾賽（未滿 8 篇）
```

沒跑這一步的話，`assets/content/*/assets/` 是空的，測試會失敗、畫面會全黑。

**`--partial` 是刻意要手動加的**：篇數未滿的包預設會被擋下並印出缺哪幾篇——
靜默放行等於讓做了一半的包看起來像做完的包。

`packs.json`（書架清單）由匯入腳本**掃描磁碟**產生，不是寫死的常數。
只匯入了龐貝的機器上，書架就只會有龐貝，不會列出一個載不進來的凡爾賽。

## 部署

兩個入口，**跑同一支閘門 `gate.sh`**：

```bash
./deploy.sh                 # 本機：閘門 → firebase deploy（用你的 firebase login）
./deploy.sh --skip-import   # 素材沒動時跳過匯入，省 2 分鐘
./gate.sh                   # 只跑閘門不部署（想確認會不會過就跑這個）
./gate.sh --ci              # CI 模式，本機也能跑來預演
```

CI：GitHub Actions 的 **Deploy Story**（`workflow_dispatch` 手動觸發），跑
`gate.sh --ci`，改用 service account 部署。CI 上沒有 fvm，SDK 由 flutter-action
依 `.fvmrc` 的版本裝好，所以 workflow 把 `FLUTTER` 環境變數換成 `flutter`。

→ https://story-lorescape.web.app

### 影像處理只在本機做

**匯入產生的 WebP 進版控**（18 MB／121 檔）。去背與轉檔要在 125 張圖上跑
Pillow＋numpy，CI 上又沒有 `_processed` 快取（那份 568 MB，不可能進版控），
所以分工是：

| | 本機 | CI |
|---|---|---|
| 素材去背／轉檔 | ✅ 有素材、有快取 | ❌ 完全不做 |
| 產物驗證 | 完整匯入即等於驗證 | `--verify-only` |
| 測試／build／部署 | ✅ | ✅ |

工作流程：**改了美術或劇本 → 本機重跑匯入 → 把 WebP 與 story.json 一起
commit → CI 部署。** 只改劇本文字時匯入很快（快取全中）。

忘記重跑匯入不會靜默出貨：`--verify-only` 拿 writer 來源與版控裡的產物**逐字
比對**，不同就擋；再檢查劇本引用的每張圖都在，缺件也擋。

`test_import_pack.py` 會實際跑一次匯入（去背容差、對齊分數、WebP 品質都是量
真實輸出），所以它跟影像處理綁在一起，`--ci` 不跑它。

**任何一關沒過就不會部署。** 閘門依序是：素材匯入 → 內容 lint（凡爾賽）→
劇本結構與矛盾檢查（全部包，見 [[劇本矛盾檢查規範]]）→ `analyze --fatal-infos`
→ `flutter test` → 匯入腳本測試 → `build web`。

**閘門只有一份的理由**：本機與 CI 各寫一份，遲早分岔，然後「CI 綠燈」變成
「CI 沒跑到的那幾步剛好是壞的」。改檢查請改 `gate.sh`，兩個入口自動同步。

**缺包是硬錯誤，不是跳過**：`packs.json` 掃磁碟產生，部署又會覆蓋線上版本，
所以少匯入一包等於把少一個景點的書架推上線。`gate.sh` 開頭會檢查每個包的
來源在不在，缺了就停。

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
