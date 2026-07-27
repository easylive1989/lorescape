# Lorescape 數據抓取（lorescape-metrics）設定指南

`lorescape-metrics` skill 在本機手動抓取產品數據，**累積**到 repo 內的
`data/metrics/*.csv`（每來源一檔、逐日一列、跨次累積；**gitignored**——數據
含營收而 repo 是 public）。CSV 即唯一資料來源（見 §D）。
2026-07-11 前累積在 Google Sheet，已一次性匯出到 CSV 後停用。

- 程式位置：`scripts/metrics/`
- 執行：`cd scripts && uv run python -m metrics.report`（預設抓昨天，
  自動補「最後紀錄日 → 昨天」的缺口；分頁空時回溯 30 天建立基線）
- 驗證設定 / 看待補進度（讀試算表算缺口，不抓 API）：`... report --check`
- 手動補特定區間：`... report --start 2026-06-01 --end 2026-06-20`
- 調整首次回溯天數 / 貼文刷新視窗：`... report --days 30`
- 子集：`... report --only gsc,ga4,ig,ig_posts`

API 來源四個，分別寫進同名分頁：

| 來源 | 分頁 | key | 內容 |
| --- | --- | --- | --- |
| `gsc` | `gsc` | date | 站台每日 clicks / impressions / ctr / position |
| `ga4` | `ga4` | date | 每日 web / iOS / Android active / new users（App = iOS + Android） |
| `ig` | `ig` | date | 帳號每日 reach / profile_views（+ 最新日 followers/media 快照） |
| `ig_posts` | `ig_posts` | media_id | 逐則貼文核心互動 + Reels 影片指標 |

App Store / Play 也走 API：`store_ios`（ASC 銷售日報 + iTunes lookup 評分
快照，見 §E）、`store_ios_pages`（ASC Analytics 報表的商品頁曝光/瀏覽，
共用同一組 ASC 金鑰，見 §E3）與 `store_android`（Play Console 報表
bucket，見 §F）。
（2026-07-11 前用瀏覽器手抓進 `stores.csv`，該檔保留當歷史檔。）

本專案實際使用的識別碼（方便對照）：

| 項目 | 值 |
| --- | --- |
| GA4 資源 ID（單一資源，含 web+iOS+Android） | `514854947` |
| GCP 專案編號（service account 所屬 / API 配額） | `946345911984`（Firebase 專案 `instant-explore-7b442`） |
| Search Console 資源 | `sc-domain:lorescape.app`（網域類型，Cloudflare DNS 驗證） |
| Facebook 粉專 ID | `1135790239616504` |
| IG Business Account ID（`IG_USER_ID`） | `17841402312650550` |
| App Store 數字 ID（`store_ios.py` 的 `APPLE_APP_ID`） | `6751904060` |
| ASC 廠商編號（`ASC_VENDOR_NUMBER`） | `93430162` |
| Android package（`store_android.py` 的 `ANDROID_PACKAGE`） | `com.paulchwu.instantexplore` |
| Play 報表 bucket（`PLAY_REPORTS_BUCKET`） | `pubsite_prod_rev_03880570992203689706` |

對應的 `scripts/.env`：

```
GA4_PROPERTY_ID_WEB=514854947
GA4_PROPERTY_ID_APP=                       # 留空，web/app 同一資源，填了會重複計算
GSC_SITE_URL=sc-domain:lorescape.app
GOOGLE_APPLICATION_CREDENTIALS=/Users/paulwu/.config/lorescape/metrics-sa.json
IG_USER_ID=17841402312650550
META_PAGE_ACCESS_TOKEN=<帶 instagram_manage_insights 的永久粉專 token>
ASC_KEY_ID=<ASC API 金鑰的 Key ID>
ASC_ISSUER_ID=<ASC API 金鑰頁的 Issuer ID>
ASC_KEY_PATH=/Users/paulwu/.config/lorescape/asc-api-key.p8
ASC_VENDOR_NUMBER=93430162
PLAY_REPORTS_BUCKET=pubsite_prod_rev_03880570992203689706
```

---

## A. Google（GSC + GA4）— 用 Service Account

> ⚠️ 不要用 `gcloud auth application-default login`。`analytics.readonly` /
> `webmasters.readonly` 是 Google 認定的「敏感 scope」，gcloud 的共用 OAuth
> client 沒過審，會被擋「系統已封鎖這個應用程式」。**一律用 service account。**
> 程式用 `google.auth.default()`，會自動讀 `GOOGLE_APPLICATION_CREDENTIALS`，
> 不需改任何程式碼。

### A1. 建 service account + 金鑰
1. GCP Console → IAM 與管理 → 服務帳戶 → 建立（如 `lorescape-metrics`），
   專案層級**不用**給任何角色。
2. 該服務帳戶 → 金鑰 → 新增金鑰 → JSON → 下載。
3. 存到 **repo 外**（如 `~/.config/lorescape/metrics-sa.json`），**勿** commit。
4. `scripts/.env` 加：`GOOGLE_APPLICATION_CREDENTIALS=<金鑰絕對路徑>`。

### A2. 啟用兩個 API（在 service account 所屬的 GCP 專案）
API 配額算在 service account 的專案（本專案是 `946345911984`），要先啟用：

```
gcloud services enable searchconsole.googleapis.com analyticsdata.googleapis.com --project=946345911984
```

（沒啟用會回 `accessNotConfigured` / `SERVICE_DISABLED` 403。）

### A3. 授權 service account 讀取
用金鑰裡的 `...iam.gserviceaccount.com` email：
- **GA4**：後台 → 管理 → 資源設定 → 資源 →「**資源存取權管理**」→ 新增 →
  貼 email → 角色「**檢視者**」→ 取消「通知新使用者」→ 新增。
- **GSC**：見 A5 驗證資源後，設定 ⚙ → 使用者和權限 → 新增使用者 → 貼 email →
  權限「完整」（或「受限」）。

### A4. GA4 property ID
- GA4 後台 → 管理 → 資源設定 → 資源 → 右上「資源 ID」（純數字，如 `514854947`）。
  注意：資料串流畫面上的大數字是**串流 ID**，不是資源 ID。
- 本專案 web + iOS + Android 三個串流**共用同一資源** → 只填
  `GA4_PROPERTY_ID_WEB`、`GA4_PROPERTY_ID_APP` 留空（填兩個會重複計算）。
- `ga4.py` 查詢帶 `platform` 維度，把這個單一資源**拆成 web / iOS / Android**
  三組欄位（App = iOS + Android），不再是三平台合計。`fetch_daily` 取
  `GA4_PROPERTY_ID_WEB or GA4_PROPERTY_ID_APP` 當作那個單一資源來查。

### A5. 建立 + 驗證 Search Console 資源
新帳號可能完全沒有資源（開到「歡迎使用」新增頁）。建議**網域類型**：
1. 歡迎頁「網域」框輸入 `lorescape.app` → 繼續。
2. DNS 在 Cloudflare → 對話框可選 **Cloudflare 自動驗證**：按「開始驗證」→
   授權 Google 存取你的 Cloudflare DNS → 它自動加 `google-site-verification`
   TXT 並完成驗證（不用手動編 DNS）。
3. 驗證成功 → `GSC_SITE_URL=sc-domain:lorescape.app`。
4. 回 A3 把 service account 加成使用者。

> 新資源驗證後，Search Console 要 **2~3 天**才開始累積搜尋數據，且不回溯
> 驗證前的資料。剛設好跑出 0 點擊 0 曝光是正常的。

---

## B. Instagram — 取得帶 insights 權限的永久粉專 token

發 Reels 的舊 token 只有發文權限，讀 insights 會回
`(#10) Application does not have permission`。要補
`instagram_manage_insights` 並重新產 token。

### B1. 在 App 開啟 insights 權限
Meta for Developers → 你的 App。先確認權限是否可用：
- 若用「使用案例」架構：使用案例 → 「管理 Instagram 的訊息和內容」→ 自訂 →
  在權限清單把 **`instagram_manage_insights`** 加入（狀態顯示「可供測試」即可，
  開發模式不用送 App Review）。

### B2. 在 Graph API Explorer 產短期 user token
工具 → Graph API 測試工具：
1. 選你的 App，**用戶權杖**。
2. 權限勾齊：`instagram_basic`、`instagram_content_publish`、`pages_show_list`、
   `pages_read_engagement`、`pages_manage_posts`、**`instagram_manage_insights`**。
3. Generate Access Token → 授權；過程中若要選粉專資產，**勾選 Lorescape 粉專**。
4. 可先驗證權限：查詢欄跑 `<IG_USER_ID>/insights?metric=reach&period=day`，
   有回傳 `data` 就代表 insights 權限通了。

### B3. 用 meta_token_helper.py 換永久粉專 token
```
cd scripts && uv run python meta_token_helper.py --platform instagram
```
依序輸入 App ID、App Secret（隱藏輸入）、B2 的短期 user token。

> ⚠️ **`/me/accounts` 會是空的**：Lorescape 是「新版粉專體驗 / 商業管理平台」
> 粉專，就算有 `pages_show_list` 也不會出現在 `/me/accounts`。helper 已改成
> 偵測到空清單時**改問你 Facebook Page ID**，輸入 `1135790239616504`，它就用
> 長期 user token 直接抓**永久**粉專 token（commit 8ec2df5）。

helper 最後印出：
```
IG_USER_ID=17841402312650550
META_PAGE_ACCESS_TOKEN=<永久粉專 token>
```
覆蓋 `scripts/.env` 同名兩行。IG token 同時也在 `publisher/.env`（伺服器發文用），
輪替時兩個檔案都要更新。

> 手動備援：在 Explorer 用 user token 跑
> `1135790239616504?fields=name,access_token,instagram_business_account`
> 也能直接拿到粉專 token（但短期 user token 衍生的會過期，正式用請走 helper）。

### B4. profile_views 的 API 變更
Graph API v21+ 的帳號 insights，`profile_views` 必須帶
`metric_type=total_value`，否則回 `(#100) ... should be specified with
parameter metric_type=total_value`。`ig.py` 已處理：逐日以
`metric_type=total_value`、`since=當天&until=隔天` 查單日總量（避開時間序列
`end_time` 的時區 off-by-one），並同時解析 `total_value` 與 `values[]` 兩種回傳。

### B5. 逐則貼文（`ig_posts`）
`ig_posts.py` 用同一組 token：先 `GET /<IG_USER_ID>/media`（newest-first，
翻頁到貼文早於區間就停）取近 30 天貼文，再逐則 `GET /<media-id>/insights`
抓 `reach,saved,shares,total_interactions`；likes/comments 直接取自 media
欄位（`like_count`/`comments_count`，較穩）；Reels/影片再加
`views,ig_reels_avg_watch_time`（v21 已無 `plays`，play 數改用 `views`）。
單則 insights 失敗時該列指標留空、不影響其他貼文。若某指標在你的 API 版本不
可用，調整 `ig_posts.py` 的 `_CORE_METRICS` / `_VIDEO_METRICS` 即可。

---

## C. 驗證

```
cd scripts
uv run python -m metrics.report --check   # 四來源 ready + 待補進度
uv run python -m metrics.report           # 抓昨天 + 自動補缺口
```
`--check` 會讀 CSV 算出每來源「最後紀錄日、待補幾天 → 昨天」（`ig_posts`
顯示要刷新的貼文區間）。實際抓取後，資料**直接寫進 `data/metrics/` 的同名
CSV**（`gsc.csv` / `ga4.csv` / `ig.csv` / `ig_posts.csv`…），stdout 列出每
來源 `+N row(s)` / `up to date` / `skipped`。

---

## D. 資料目的地：`data/metrics/*.csv`

數據累積在 repo 的 `data/metrics/`，每來源一個同名 CSV（不存在會自動建立），
CSV 即唯一資料來源——補抓缺口時直接讀回 CSV 判斷。**無需任何額外設定**。

- 該資料夾已 gitignore（數據含營收，repo 為 public），只存在本機；
  需要備份請自行處理（例如定期複製或私有備份）。
- 每次同步是「讀回 → 合併去重 → 整檔覆寫」，不要手動編輯這些 CSV，
  否則下次同步會被覆蓋。
- 2026-07-11 前的 Google Sheet 歷史已全數匯出到這些 CSV；Sheet 與
  `METRICS_SHEET_ID` 均已停用。

---

## E. App Store（`store_ios`）— App Store Connect API

### E1. 建 API 金鑰

1. App Store Connect →「用戶與存取」→「整合」→「App Store Connect API」→
   「團隊金鑰」（第一次要先按 Request Access 同意條款）。
2. ➕ 產生金鑰：名稱 `lorescape-metrics`，存取權限選**「管理員」（Admin）**。
   （同一把金鑰要同時服務 `store_ios` 的銷售報表與 `store_ios_pages` 的
   Analytics 報表，只有 Admin 兩者都能讀——「銷售與報告」讀不到 Analytics、
   「App 管理」兩者都讀不到，詳見 §E3。）
3. 下載 `.p8`（**只能下載一次**）放到
   `~/.config/lorescape/asc-api-key.p8`，記下 **Key ID** 與頁面上方的
   **Issuer ID**。
4. 「付款與財務報告」頁左上角的 8 碼**廠商編號**填 `ASC_VENDOR_NUMBER`。

### E2. 行為與限制

- 下載數來自銷售日報（DAILY/SALES/SUMMARY，gzip TSV），只計 Product Type
  `1*` 的首次下載；歷史可回補約一年。
- 某日報表約在**次日下午（台灣時間）**才產生：沒好時 API 回 404
  「report not available yet」，程式會停在該日、下次自動補；當日**零下載**
  也是 404 但訊息是「no sales」，會記 0。
- 評分/評論數沒有歷史：`avg_rating` / `ratings_count` 來自公開 iTunes
  lookup（**TW storefront**，與 ASC 全球數可能有出入）、`reviews_count`
  來自 ASC customerReviews 總數，都只在最新一天填快照。

### E3. 商品頁曝光/瀏覽（`store_ios_pages`）— Analytics Reports API

用同一組 ASC 金鑰（`ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_PATH`，
不需要廠商編號），從「App Store Discovery and Engagement」報表加總每日
**impressions（曝光）**與 **product_page_views（商品頁瀏覽）**，寫進
`store_ios_pages.csv`。

- Analytics 報表是**非同步**產生的：App 要先有一個 ONGOING 的
  analytics report request，**首次執行會自動建立**（該次記 0 列），
  Apple 約 1–2 天後才開始每天產出日報，之後每次跑會自動補到最新已
  產生的那天。
- ONGOING 只提供建立請求之後的資料，**更早的歷史補不回來**（想要一次
  性歷史得另外用 ONE_TIME_SNAPSHOT 手動撈，程式不做）。長期沒跑的話
  Apple 會停用 request（stoppedDueToInactivity），程式會自動刪掉重建，
  但停用期間的天數同樣補不回來——建議跟其他來源一樣每天跑。
- 報表按維度展開（裝置/來源/地區…），數字是全維度 Counts 加總；
  Unique Counts 只在單一維度列內去重、加總會灌水，所以**不收集**
  unique 數。
- 若此來源回 **403**：金鑰角色不夠。實測（2026-07-25）「銷售與報告」
  讀得到 salesReports 但讀不到 Analytics；改用「App 管理」則**兩者都 403**
  （連 `store_ios` 的 salesReports 也一起壞）。因為 `store_ios`
  （salesReports）與 `store_ios_pages`（analyticsReportRequests）共用同一把
  `ASC_KEY_ID`，只有 **管理員（Admin）** 角色能同時涵蓋兩者——建金鑰時
  務必選「管理員」，**不要**選「App 管理」。
- ASC 金鑰**建立後無法改角色**（金鑰頁明寫「無法透過修改金鑰存取更多
  服務」）。要換角色只能新建一把：下載新 `.p8` 覆蓋 `ASC_KEY_PATH`、把
  `ASC_KEY_ID` 換成新 Key ID，跑 `metrics.report --only
  store_ios,store_ios_pages` 確認不再 403 後，再回 ASC 撤銷舊金鑰
  （撤銷不可逆；別動 RevenueCat / CI-CD 等其他整合在用的金鑰）。

## F. Play（`store_android`）— Console 報表 bucket

### F1. 授權 + 找 bucket

1. Play Console →「使用者與權限」→ 邀請
   `lorescape-metrics@instant-explore-7b442.iam.gserviceaccount.com`，
   帳戶權限勾**「查看應用程式資訊並下載大量報表」**（service account
   不需接受邀請；**授權最久要 24 小時才同步到 GCS**）。
2. 「下載報表」→「統計資料」→ 複製 Cloud Storage URI，取
   `pubsite_prod_rev_…` 那段填 `PLAY_REPORTS_BUCKET`。

### F2. 行為與限制

- 讀 bucket 的 `stats/installs|ratings/…_overview.csv`（UTF-16）：
  `installs` = Daily User Installs、`active_devices` = Active Device
  Installs、每日/累計平均星等。歷史完整可回補。
- Play 匯出**約落後 2 天**，最近兩天自然留缺、之後補上；Play 沒有
  「總評分數」可撈（官方 API/報表都沒有），所以無此欄。

---

## 疑難排解對照

| 症狀 | 原因 | 解法 |
| --- | --- | --- |
| gcloud ADC「系統已封鎖這個應用程式」 | 敏感 scope，gcloud client 沒過審 | 改用 service account（§A） |
| 403 `accessNotConfigured` / `SERVICE_DISABLED` | GCP 專案沒啟用該 API | `gcloud services enable ...`（§A2） |
| GA4 403「default credentials not found」 | 沒設 `GOOGLE_APPLICATION_CREDENTIALS` 或金鑰無效 | 設 .env 指向 JSON 金鑰（§A1） |
| GA4 / GSC 回 403 權限不足 | service account 沒被加進該資源 | §A3 加 email |
| GSC 0 點擊 0 曝光 | 資源剛驗證 | 等 2~3 天累積，正常 |
| IG `(#10) does not have permission` | token 沒帶 `instagram_manage_insights` | §B 補權限重產 token |
| IG `(#100) profile_views ... metric_type=total_value` | API 改版 | 已於 `ig.py` 修正（§B4） |
| meta_token_helper `No Facebook Pages found` | 新版/商業粉專不出現在 /me/accounts | helper 已改問 Page ID（§B3） |
| ASC 401 `NOT_AUTHORIZED` | 金鑰/Issuer ID 錯或金鑰被撤銷 | 核對 §E1 三個值，必要時重建金鑰 |
| ASC 404 且訊息非 no sales | 該日報表還沒產生（次日下午才有） | 正常，下次跑會自動補 |
| Play bucket 403 | 授權還沒同步（最久 24h）或沒勾下載報表權限 | 等待或回 §F1 檢查權限 |

## 相關檔案
- `scripts/metrics/`（`report.py` 補抓引擎、`gsc.py`/`ga4.py`/`ig.py`/
  `ig_posts.py`/`store_ios.py`/`store_android.py` 來源；合併去重在
  `_common.py`；`store.py` 的 `FileStore` 讀寫 `data/metrics/*.csv`）
- `.claude/skills/lorescape-metrics/`（SKILL.md + references）
- `scripts/meta_token_helper.py`（換長期 Meta token）
- `docs/superpowers/specs|plans/2026-06-24-lorescape-metrics*`（設計與計畫）
