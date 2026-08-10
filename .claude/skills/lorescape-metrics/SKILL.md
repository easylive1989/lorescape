---
name: lorescape-metrics
description: Use when the user wants to update Lorescape's accumulating daily metrics — Google Search Console search traffic, GA4 landing + app traffic, Instagram account reach/followers, per-post IG/Reels insights, Reels 24h/48h/7d insight snapshots from IG App screenshots, RevenueCat subscription/revenue snapshot, App Store / Play downloads & ratings, or App Store product page impressions/views. Triggers on 「產品數據報告」「這週/這月數據」「抓 GSC / 搜尋流量」「GA4 / landing / App 流量」「IG 數據 / 觸及」「每則貼文 / 貼文成效」「reel 洞察 / 截圖數據」「訂閱 / 營收 / MRR / RevenueCat」「App 下載 / 評分」「商店頁瀏覽 / 曝光 / product page views」. Sources via API (GSC / GA4 / IG / RevenueCat / App Store Connect / Play reports bucket)；Reels 快照另由使用者提供 IG App 洞察截圖. Accumulates into in-repo CSVs (data/metrics/*.csv, tracked in git since 2026-08-10), one file per source. Local, read-only, does not touch the server.
---

# Lorescape 數據抓取報告

把 Lorescape 各來源的產品數據**累積**到 repo 內的 **`data/metrics/*.csv`**
（2026-08-10 起納入版控——repo 為 private，原「含營收故不進版控」的
理由不成立），每來源一檔、逐日一列、
跨次累積。CSV 是唯一資料來源，補抓缺口時直接讀回 CSV 判斷。
（2026-07-11 前累積在 Google Sheet，歷史已匯出後停用。）
全部來源都走 API（GSC / GA4 / IG / IG 逐則貼文 / RevenueCat / App Store
Connect / Play 報表 bucket），不再用瀏覽器抓。

預設抓**昨天**；執行時自動偵測「最後紀錄日 → 昨天」的缺口並逐日補抓，
檔案首次（或空）時回溯 30 天建立基線。重跑同一天會覆蓋、不重複。

## 來源與檔案

| 來源 | 檔案 | key | 內容 |
| --- | --- | --- | --- |
| `gsc` | `gsc.csv` | date | 站台每日 clicks / impressions / ctr / position |
| `ga4` | `ga4.csv` | date | 每日 web / iOS / Android 各自的 active / new users（App = iOS + Android） |
| `ig` | `ig.csv` | date | 帳號每日 reach / profile_views（= 個人檔案/bio 瀏覽數）（+ 最新一天 followers/media 快照） |
| `ig_posts` | `ig_posts.csv` | (media_id, obs_date) | 每則貼文**逐日**追蹤：obs_date、posted_date、reach、likes、comments、saved、shares、total_interactions，Reels 另含 views、avg_watch_time |
| `ig_reels` | `ig_reels_insights.csv` | (media_id, checkpoint) | **Reels 洞察快照**（發布後 24h / 48h / 7d 三個 checkpoint）：略過率等六比率、瀏覽來源占比、觀眾輪廓（粉絲比／年齡／性別／國家）——API 拿不到，由使用者提供 IG App 截圖、Claude 讀圖寫入 |
| `revenuecat` | `revenuecat.csv` | date | 訂閱/營收每日快照：mrr、active_subscriptions、active_trials、active_users_28d、new_customers_28d、revenue_28d |
| `store_ios` | `store_ios.csv` | date | App Store 每日 downloads（ASC 銷售日報，可回補約一年）＋ 最新一天 avg_rating / ratings_count（iTunes lookup，TW storefront）與 reviews_count 快照 |
| `store_ios_pages` | `store_ios_pages.csv` | date | App Store 商品頁漏斗：每日 impressions（曝光）／product_page_views（商品頁瀏覽），來自 ASC Analytics「Discovery and Engagement」日報（非同步、落後 1–2 天；首跑只建報表請求） |
| `store_android` | `store_android.csv` | date | Play 每日 installs / active_devices ＋ avg_rating_daily / avg_rating_total ＋ 商店頁 store_listing_visitors / store_listing_acquisitions（Play Console 報表 bucket，可回補，但匯出約落後 2 天） |

`ig_posts` 是**每則貼文的逐日時間序列**：每次跑會為「發布在近 7 天內的每則
貼文」各記一列當天觀察（key = `media_id` + `obs_date`），所以每篇貼文最多
累積約 7 列後就離開追蹤窗、不再更新（追蹤天數 = `ig_posts.py` 的
`_TRACK_DAYS`）。`obs_date` 是觀察當天（= 昨天），`posted_date` 是發布日。
貼文 insights 只能讀「當下累計值」，跟 `revenuecat` 一樣**漏掉的天無法回補**
——要逐日連續就得**每天跑一次**。重跑同一天會覆蓋該貼文當天那列。檔案固定
依 **發布日 → 貼文 → 觀察日** 排序，所以同一則貼文的逐日列會相鄰、照時間排。

`ig_reels` 是**手動快照**來源：每支 Reel 在發布後 **24h、48h、7d** 各記一列
（key = `media_id` + `checkpoint`，值為 `24h`/`48h`/`7d`）。這些欄位（略過率
等六比率、瀏覽來源、觀眾輪廓）只存在 IG App 的洞察頁、Graph API 拿不到，
所以流程是：skill 算出今天到期的 reels → 使用者去 IG App 截圖、放進
**`data/metrics/_inbox/`** → Claude 從那裡讀圖寫入 CSV（見步驟 4）。
**這是唯一不由 `metrics.report` 管理的檔**，由 Claude 依
`references/reel-insights.md` 的欄位定義直接讀寫；漏抓的 checkpoint **不回補、
不留列**（快照過期即失真），重截同一 checkpoint 會覆蓋該列。檔案依
**posted_date → media_id → checkpoint（24h→48h→7d）** 排序。
image / carousel 貼文不做快照，維持 `ig_posts` 的 API 逐日追蹤即可。

想知道「昨天有多少人看過我的 IG bio」直接看 `ig.csv` 昨天那列的
`profile_views`（IG 的 profile/個人檔案瀏覽數，已每天記錄）。

`revenuecat` 是**快照**來源：RevenueCat 公開 API 只給「當下」的 overview
指標，沒有逐日歷史，所以每次只會記昨天一列（重跑同日覆蓋），**漏掉的天無法
回補**。要逐日連續就得每天跑一次。

`store_ios` 的 downloads 是逐日**首次下載數**（更新、重下載不算）。ASC 的
銷售日報約在**次日下午（台灣時間）**才產生，還沒好的日子會自動留待下次補；
評分（TW storefront）與評論數跟 `ig` 的 followers 一樣只在最新一天填快照。
`store_android` 兩個評分欄與 installs 都有逐日歷史、可回補；Play 匯出約落後
2 天，最近兩天會自然留缺待補（Play 官方沒有「總評分數」可撈，故無此欄）。
同檔的 `store_listing_visitors` / `store_listing_acquisitions` 來自
`stats/store_performance/`，是 Android 版的商店頁漏斗。**Play 對新 App 會
先匯出 store_performance、隔一陣子才開始匯出 installs / ratings**，所以初期
只有商店頁兩欄有值、其餘留空是正常的（2026-07-26 實測：installs/ratings 尚
未匯出任何檔）。store_performance 只有維度切分檔（country / traffic_source）、
沒有 `_overview`，程式讀 country 檔並把同一天各國加總。

`store_ios_pages` 用同一組 ASC 金鑰走 **Analytics Reports API**（非同步）：
首次執行只會建立 ONGOING 報表請求（記 0 列），Apple 約 1–2 天後才開始
產出每日報表；之後每次跑自動補到最新已產生的那天，還沒產生的日子留待
下次。ONGOING 只涵蓋建立請求之後的日子，更早的歷史**補不回來**。Android
的對應資料在 `store_android.csv` 的 store_listing_* 兩欄（見上）。細節與
403 排解見 `docs/init/metrics-setup.md` §E3。

2026-07-11 前用瀏覽器手抓的 `stores.csv` 保留當歷史檔，不再更新。

不要手動編輯 API 來源的 CSV（下次同步會整檔覆寫）；`ig_reels_insights.csv`
是唯一例外（Claude 依本 skill 讀寫）。分析請複製出去，或跑
`python3 dashboard/build_metric.py` 產生單檔 `dashboard/out/metric.html`。

## 前置條件

完整一次性設定（service account、IG token、API 啟用、踩雷排解）見
**`docs/init/metrics-setup.md`**。摘要：

- **Google（GSC + GA4）**：用 **service account**（非 ADC，ADC 會被 Google
  擋），`scripts/.env` 設 `GOOGLE_APPLICATION_CREDENTIALS` +
  `GA4_PROPERTY_ID_WEB` + `GSC_SITE_URL`。
- **IG（含逐則貼文）**：`scripts/.env` 的 `META_PAGE_ACCESS_TOKEN` 須帶
  `instagram_manage_insights` 權限（用 `scripts/meta_token_helper.py` 產），
  並設 `IG_USER_ID`。逐則貼文用同一組憑證。
- **資料目的地**：`data/metrics/*.csv`，自動建立、無需設定（詳見
  `docs/init/metrics-setup.md` §D）。
- **RevenueCat（訂閱/營收）**：`scripts/.env` 設 `REVENUECAT_V2_API_KEY`
  （RevenueCat → Project settings → API keys 建一把 **v2 secret key**，給
  metrics/overview 讀取權限；注意這跟 backend/.env 的 v1 `REVENUECAT_API_KEY`
  是不同的金鑰）與 `REVENUECAT_PROJECT_ID`（Project settings 的 Project ID）。
- **App Store（`store_ios` / `store_ios_pages`）**：`scripts/.env` 設
  `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_PATH`（App Store Connect API
  金鑰 .p8，權限「銷售與報告」）/ `ASC_VENDOR_NUMBER`（付款與財務報告頁
  的廠商編號；`store_ios_pages` 不需要）。`store_ios_pages` 若回 403，
  需把金鑰權限提高才能讀 Analytics 報表（見 metrics-setup §E3）。
- **Play（`store_android`）**：Play Console 已把上面那個 Google service
  account 加為使用者（權限「查看應用程式資訊並下載大量報表」），
  `scripts/.env` 設 `PLAY_REPORTS_BUCKET`（下載報表頁的 Cloud Storage URI
  中 `pubsite_prod_rev_…` 那段）。授權後最久要 24 小時才生效。

## 步驟

> 以下所有相對路徑（`scripts/`、`docs/`、`references/`）都是相對於**專案根目錄
> `instant_explore/`**，不是這個 skill 資料夾。metrics 程式在
> `instant_explore/scripts/metrics/`。指令請在專案根目錄下執行，例如
> `cd /Users/paulwu/Documents/PLRepo/instant_explore/scripts`。

1. 跟使用者確認要更新哪些來源（預設全部）。一般不必指定日期，工具會自動補到
   昨天；如要手動補特定區間用 `--start/--end`，調整首次回溯天數用 `--days N`
   （`ig_posts` 的追蹤窗固定 7 天、不受 `--days` 影響）。

2. **先 dry-run** 檢查設定與待補進度（讀 CSV 算缺口，不抓 API）：

       cd <instant_explore 專案根>/scripts && uv run python -m metrics.report --check

   每個來源會顯示 ready / 缺設定，以及「最後紀錄日、待補幾天 → 昨天」
   （`ig_posts` 顯示追蹤中的貼文發布區間 + 已存的觀察列數）。缺設定的先補。

3. 抓 API 來源並寫進 CSV：

       cd <instant_explore 專案根>/scripts && uv run python -m metrics.report

   只抓單一來源時用 `--only`，例如 `--only ig_posts` 或 `--only gsc,ga4`。
   完成後把 stdout 的每來源結果（`+N row(s) for <區間>` / `up to date` /
   `skipped`）念給使用者，必要時讀出對應 CSV 的近期幾列確認。

4. **Reels 洞察快照**（在 API 收集完、`ig_posts.csv` 已更新後做）：

   1. 從 `ig_posts.csv` 找出 `type=REELS` 且 `posted_date` 為
      **昨天（→24h）、前天（→48h）、7 天前（→7d）** 的貼文，並讀
      `ig_reels_insights.csv` 排除今天已記錄的 checkpoint。
   2. 沒有到期的就跳過本步。有的話，逐支列給使用者：
      checkpoint、景點名（取 caption 開頭）、permalink，請使用者到
      IG App 對每支開「洞察報告」截圖**三個 tab**：總覽（滑到「影響
      你瀏覽次數的因素」與「瀏覽/觀看次數主要來源」都入鏡）、
      互動次數、觀眾（「廣告受眾詳情」的年齡／國家地區／性別三個
      子頁籤各一張；IG 沒提供輪廓時一張即可）。
   3. **截圖收在 `data/metrics/_inbox/`**（固定路徑、不分日期）。使用者
      說「截圖放好了／放進 data 了」就直接去那裡撈，不用再問路徑；平放
      或分子資料夾都可以。每張截圖都帶著 reel 封面縮圖，據此對應到哪一
      支；checkpoint 一律由 `ig_posts.csv` 的 `posted_date` 推算，不靠檔
      名或資料夾名。
   4. 依 **`references/reel-insights.md`** 的欄位定義讀圖，寫入
      `data/metrics/ig_reels_insights.csv`（檔不存在先建 header；同 key
      覆蓋；依 posted_date → media_id → checkpoint 排序），最後把每支的
      關鍵數字（views / 略過率 / 按讚率 / 粉絲比）念給使用者核對。
   5. `_inbox` 的截圖是**一次性輸入**，寫進 CSV 後即無保留價值。核對完
      問使用者要不要清空——**不要自動刪**。
   6. 使用者當下沒空截圖就跳過，明確告知哪些 checkpoint 會因此留空
      （不回補）。

5. **選點規劃提示**：若本次更新了 `ig` / `ig_posts` 並向使用者做了
   IG 成效分析，結尾提示可接著用 **lorescape-reels-planner** 依最新
   數據規劃或檢核每日景點 Reel 的選點 calendar（下期排程、配比調整、
   期末檢核到期時尤其該提）。

## 注意

- 全程本機、唯讀，不寫 Supabase、不碰 server 排程；只寫 repo 內的
  `data/metrics/*.csv`（已納入版控，記得一併 commit）。
- 某來源缺憑證或失敗時，該來源標 `skipped: <原因>`，其他來源照常累積，
  不需整批重跑；之後補設定再跑會自動補上缺口。
- IG 帳號歷史 followers/media 無法回溯，只在最新一天填快照；逐日 reach /
  profile_views 用單日 `total_value` 查詢，數字對應該日曆日。
- `ig_posts` 逐日追蹤只能往前累積、漏掉的天無法回補，所以要**每天跑一次**
  才連續；每篇貼文追蹤約 7 天後自動離開。若曾用舊版（每則單列快照）的
  `ig_posts` 資料，改版第一次跑前需把該檔清成新 header（欄位結構不同）。
- `ig_reels` 快照同理**每天做一次**才不漏 checkpoint；漏了就留空、不回補
  （晚拍的截圖數字已不是該時點的狀態）。觀眾輪廓在互動帳號 <100 時 IG
  不提供，對應欄位留空即可，不算漏抓。
