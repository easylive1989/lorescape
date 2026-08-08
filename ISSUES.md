# Lorescape 事故紀錄（ISSUES）

事故的追蹤清單，只記錄**發生什麼、原因、當下怎麼處理**——不預先規劃修法。
目的是留下歷史；若某類事故未來出現頻繁，再決定要不要根治。
新事故往上加（最新在最前）。

---

## ISSUE-003 — Android deploy 因 runner 磁碟耗盡失敗（ENOSPC）

- **發生日**：2026-08-07
- **影響**：Deploy App workflow 的 Android job；iOS job（macOS runner）正常
  上架 TestFlight，Play internal 該次沒送出

### 現象

Run [31187139231](https://github.com/easylive1989/lorescape/actions/runs/31187139231)
的 `Build Android App Bundle` 跑了 9m52s 後，Gradle 三個 task 同時炸開：

```
Execution failed for task ':app:mergeReleaseNativeLibs'
   > No space left on device
Execution failed for task ':app:minifyReleaseWithR8'
   > Failed to create directory '/home/runner/.gradle/caches/8.12/transforms/...'
Could not add entry ':app:mergeReleaseNativeLibs' to cache executionHistory.bin
   > java.io.IOException: No space left on device
```

Dart / Kotlin 編譯與 asset tree-shaking 全部通過，失敗點在建置後段
（native libs merge + R8），也就是磁碟用量的高峰。

### 原因

runner 磁碟被塞滿，非程式碼問題。與 2026-08-05 成功的那次（`bafcf830`）
相比，兩個變數同時往壞的方向動：

1. **ubuntu runner image 換版**（主因）：`20260720.247.2` →
   `20260804.265.1`。兩次建置流程完全相同（都要現場裝 NDK 27 +
   SDK Platform 31 + CMake 3.22），工作量沒變、image 換新就爆了。
2. **checkout 變大**（次因）：`63860365`（沉浸式故事 demo 合併，
   deploy 前一小時）加了約 120MB 二進位檔（marketing 截圖、story 音檔），
   repo 工作目錄 120MB → 239MB。Android job 其實只用得到 `frontend/`（11MB）。

同期 `frontend/` 本身僅 16 檔案異動、淨 -461 行，佐證問題不在 App 端。
log 裡沒有 `df` 輸出，無法回推當時究竟剩多少空間，也無法量化兩個因素的
比重——這條 pipeline 應是長期貼著磁碟上限在跑，8/5 只是剛好還過得去。

### 當下處理

改 `deploy-app.yml`（三項）：

- build 前後加 `df -h /`，之後不管成功失敗都看得到真實餘裕
- build 前加 Free disk space 步驟，清掉 dotnet / ghc / ghcup / swift /
  powershell / CodeQL 與預載 docker image
- Android、iOS 兩個 job 的 checkout 改 `sparse-checkout: frontend`，
  少拉 228MB

---

## ISSUE-002 — Reel 自動發布間歇性 ProcessingFailedError（IG 端處理失敗）

- **發生日**：2026-08-02（前例：2026-07-27）
- **影響**：每日 reel 自動發布；carousel 不受影響

### 現象

2026-08-02（巨石陣）reel 自動發布失敗，`social_posts`（media_type=reel）
status=`failed`，error：

```
Reel upload failed with HTTP 400 for container 18550664059077089:
{"debug_info":{"retriable":false,"type":"ProcessingFailedError",
 "message":"Request processing failed"}}
```

2026-07-27 也發生過一次一模一樣的錯誤（container 18549141970077089）。
其餘日期（7/20–8/1）皆正常發布。

### 原因

IG 端 media container 處理失敗（`ProcessingFailedError`），非本地影片
規格問題——`final.mp4` 為 h264 1080×1920 30fps yuv420p、34.2s、
~2.9 Mbps，與正常發布日相同 pipeline 產出。判定為 Meta 端間歇性處理
故障，與 ISSUE-001 同屬 Meta 側不穩定，但發生在 container 處理階段而
非素材抓取階段。

### 當下處理

用 publish-reel skill 本機補發同一支 `final.mp4`，一次成功
（ig_post_id 18098005030992498）。`social_posts` 該列維持 `failed`
（本機補發不回寫），無重複發布風險。

---

## ISSUE-001 — Wander 圖組發布間歇性 400（Meta 抓 Supabase 圖失敗）

- **發生日**：2026-07-24
- **影響**：每日 wander carousel 發布；reel / 單圖不受影響

### 現象

按 Discord 🚀 立即發布 wander 圖組後，bot 回「發佈失敗，見 log carousel
2026-07-24」。`social_posts`（media_type=carousel）status=`failed`，error：

```
400 Client Error: Bad Request for url:
https://graph.facebook.com/v21.0/<IG_USER>/media?image_url=<supabase>/slide_04.jpg&is_carousel_item=true&...
```

連續重試三次都失敗，但**每次卡住的 slide 不固定**（slide_04、slide_04、slide_06）。

### 原因

不是圖片內容、長寬比（8 張皆 1080×1350＝4:5）、可存取性（Supabase public
URL 皆 HTTP 200），也不是節流。真正的 Graph API 錯誤內文是：

```json
{"error":{"message":"Only photo or video can be accepted as media type.",
 "code":9004,"error_subcode":2207052,"is_transient":false,
 "error_user_title":"影音素材下載失敗"}}
```

**subcode 2207052 = Meta 伺服器去抓取 `image_url` 時下載失敗。** 建立
carousel item 時，是 Meta 主動 fetch 我方的 Supabase 圖片；這個 fetch
間歇性失敗，約每 8 張隨機掛 1 張（單獨打同一張都回 200）。carousel 需
抓 8 次，中鏢機率高；reel 只上傳單一 video_url，故不受影響。
`is_transient:false` 是 Meta 誤標——實際上重試就會過。

（`instagram.py` 只 raise HTTP 狀態、不印 Graph JSON 內文，所以 log 一開始
看不到 subcode，診斷時另外重打一次 Graph API 才拿到。）

### 當下處置

在 VPS `lorescape-publisher` container 內手動跑穩健發布：每個 carousel
item 失敗就重試（最多 8 次、間隔 3s），全部建好後組 CAROUSEL parent
container → `media_publish` → `post_log.record_post(status="published")`。
slide_06 重試一次即過，發布成功（IG post `17882378103612894`）。

> 註：`bot_flows.interactions.republish(...)` 會重置 row 並 `force=True`
> 重發，但仍走同一條無重試的 loop，單純 republish 常又掛在隨機某張，
> 所以是逐張手動重試才發成功。

### 相關

- 記憶：`carousel-meta-image-fetch-2207052`
- 主題相近：`reel-meta-transcode-failure`（reel 端 Meta rupload 故障改用
  video_url container 繞道，commit `04203de8` F11）
- 檔案：`publisher/src/lorescape_publisher/instagram.py`、`executor.py`
