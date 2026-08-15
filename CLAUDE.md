# Lorescape 專案地圖

Lorescape 是 AI 景點故事導覽 App：為使用者眼前的景點生成以 Wikipedia 等
可信來源為本的故事，並以語音朗讀。Freemium + 訂閱制（RevenueCat）。

## Repo 結構

| 路徑 | 內容 |
|---|---|
| `frontend/` | Flutter App（iOS + Android），產品本體 |
| `backend/` | Python FastAPI 服務（只服務 App）：narration API（含訂閱 402 驗證）、訂閱 webhook 與 reconcile。Docker 部署於 VPS |
| `publisher/` | Social publisher（Python）：daily story 產線、Discord 審核 bot、IG 發布。獨立 image 與 .env，Docker 部署於 VPS |
| `landing/` | Next.js 雙語官網 lorescape.app，含 `/place/[slug]` SEO 景點頁 |
| `story/` | 獨立 Flutter 專案：直式視覺小說引擎，播放 `writer/創作/龐貝/` 的龐貝景點包 8 篇。先跑 Flutter Web 驗證（部署於 story-lorescape.web.app），之後整包搬進 `frontend/lib/features/visual_novel/`。素材由 `tool/import_pack.py` 從 writer vault 匯入（產出的 WebP 不進版控，會重生）。出貨閘門 `gate.sh` 由本機 `deploy.sh` 與 GitHub Actions `deploy-story.yml`（手動觸發）共用，見 `story/README.md` |
| `writer/` | Obsidian vault（**進版控**：劇本、製作規範、出圖腳本與美術定版原圖；只有 `_processed/` 快取與匯入產生的 WebP 被 ignore）。`製作規範/story_tool.py` 驗 `story.json` 結構與兩個語意 lint，判準見 `製作規範/劇本矛盾檢查規範.md`；`創作/<景點>/` 放各景點包的內容與素材 |
| `supabase/` | Supabase schema 與 migrations |
| `marketing/` | 行銷產出與工具（子資料夾見下表） |
| `scripts/` | 每日故事 / reel / metrics 自動化腳本（Python，uv 管理）；metrics 全走 API（GSC / GA4 / IG / RevenueCat / App Store / Play） |
| `dashboard/` | 產品數據單頁（Python，純標準函式庫、無框架）：`python3 dashboard/build_metric.py` 把 `data/metrics/*.csv` 內嵌成單檔 `out/metric.html`（gitignored），雙擊離線開啟。要看最新數據就重跑一次；不部署 |
| `data/metrics/` | 累積的每日產品數據 CSV（一個來源一檔），由 lorescape-metrics skill 寫入 |
| `docs/` | 專案文件（子資料夾見下表） |
| `demo/` | Remotion 專案：30 秒 App 介紹影片（UI 皆為 code mockup） |
| `BACKLOG.md` | 專案工作項：features（F1…）與 tasks（T1…）；epic 見檔內「Epic」段 |
| `SCHEDULE.md` | 例行工作行程表（每日／每週一／每月 1 號）；開工用 `/lorescape-scheduler` 讀取執行，dashboard 亦解析顯示 |
| `MARKETING.md` | 行銷設定：ICP、value prop、定價、品牌語氣、競品、品牌定位框架 |
| `ISSUES.md` | 事故紀錄：只記「發生什麼、原因、當下怎麼處理」，不預先規劃修法；供日後判斷某類事故是否頻繁到該根治。新事故往上加 |

行銷與每日故事的操作流程走各個 lorescape-* 與 marketing-* skills，不在此贅述。

### docs/ 子資料夾

| 路徑 | 內容 |
|---|---|
| `adr/` | 技術決策紀錄（ADR，編號 0001…） |
| `design/` | Claude Design 匯出的 UI mockup handoff bundle（官網、design system） |
| `init/` | 各服務的一次性建置指南（Firebase、訂閱、IG 發布、ig-cards bucket、metrics…） |
| `superpowers/` | 開發用 specs 與 implementation plans（依日期命名） |

### marketing/ 子資料夾

| 路徑 | 內容 |
|---|---|
| `audits/` | 行銷稽核報告（CRO、SEO…） |
| `brand/` | 品牌素材：logo、App icon、IG lockup（每日影片浮水印用） |
| `screenshots/` | 商店行銷截圖產出與編輯器（app-store-screenshots skill） |
| `content-calendar/` | Reels 景點排程 calendar |
| `outputs/` | 每日產出，依日期分資料夾：`daily_image/`（照片池）、`daily_carousel/`（IG 圖組）、`daily_video/`（reel 成品） |
| `sound/` | Reel 用 BGM 音檔 |
| `tools/reel-remotion/` | Remotion 影片專案（每日 reel 產製；photos/fonts/story.json 為 pipeline 重生的工作素材，不進版控——story.json 缺檔時由 `npm run ensure-story` 從 tracked 的 story.sample.json 複製） |

## Frontend（Flutter）

- 一律用 `fvm` 執行 flutter / dart 指令。
- `lib/` 分四層：`app/`（config、router、theme、shell）、`core/`（基礎設施）、
  `shared/`（共用 widgets）、`features/`（功能模組，內部依
  data / domain / presentation 分層）。
- 依賴規則：feature 之間只能跨引他 feature 的 domain 與 `providers.dart`
  （視為該 feature 的公開介面）；data / presentation 不得跨 feature 引用。
  被跨 feature 重用的元件由該 feature 的 providers.dart 明文 re-export；
  守門測試在 frontend/test/architecture/dependency_rules_test.dart。
  `app/` 僅得以 composition root 身分（router、shell）引用 features；
  `core/`、`shared/` 不依賴 `features/`。
- 技術選型：Riverpod（`Notifier` / `AsyncNotifier`）、go_router、
  supabase_flutter、purchases_flutter（RevenueCat）、Firebase Analytics / AI。
- 每次改動後執行 `fvm flutter analyze --fatal-infos`，所有問題修完才算完成。
- 測試：`fvm flutter test`；`test/` 鏡射 `lib/` 結構；widget test 規範見
  flutter-widget-tests skill。E2E 用 patrol（`patrol test`）。

## Backend（Python FastAPI）

- 程式在 `backend/src/lorescape_backend/`：narration、subscriptions、sources。
  daily story 產線與 IG 發布 bot 已拆到頂層 `publisher/`（`lorescape_publisher`
  套件），backend 不再依賴這兩塊。
- 依賴用 uv 管理；測試 `uv run pytest`。
- 部署：GitHub Actions `deploy-backend.yml`（手動觸發）→ VPS docker compose。
  其他 workflow：`ci.yml`、`deploy-app.yml`（App 上架）、`deploy-landing.yml`、
  `deploy-publisher.yml`（`publisher/` 獨立部署，見下）、`deploy-story.yml`（視覺小說，手動觸發）。

## Publisher（Python，社群發布）

- 程式在 `publisher/src/lorescape_publisher/`：daily_story（產線 + Discord
  審核貼文）、bot / bot_flows（常駐 Discord Gateway bot，四鈕審核與排程發
  布）、card / wander（IG 圖卡 / wander carousel 渲染）、reel_publisher（IG
  Reels 發布）。與 backend 各自獨立 image、`.env`、`docker-compose.yml`。
- `story_prompt.py` / `genai.py` 與 backend 對應檔案是刻意保留的兩份複製（拆
  分時接受分岔，換完全解耦），改動需人工同步兩邊，細節見
  `docs/adr/0004-split-social-publisher-from-backend.md`。
- 依賴用 uv 管理；測試 `uv run pytest`。
- 部署：GitHub Actions `deploy-publisher.yml`（手動觸發）→ VPS docker
  compose。VPS 一次性遷移步驟見 ADR 0004。

## 外部服務

Supabase（auth / DB / storage）、Firebase（Analytics、AI / Gemini）、
Google Maps / Places、RevenueCat（訂閱）、Meta Graph API（IG 發布）。

## 慣例

- 機密只放 `.env` 與 `service-account.json`（均已 gitignore），不進版控、
  不寫死在程式碼。
- 技術決策記在 `docs/adr/`。
- 文件以繁體中文撰寫（技術名詞除外）。
