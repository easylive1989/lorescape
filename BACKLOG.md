# Lorescape Backlog

專案層級放 features 與 tasks。feature 若服務某個公司 epic，於標題標 `(epic: EN)`；純專案層工作可不標。
feature 編號 `F1`、`F2`…；task 編號 `T1`、`T2`… nested 在所屬 feature 底下。
epic 承接自原公司層 backlog；目前只有 E1（見下方「Epic」）。

**完成時一律標日期 `（YYYY-MM-DD）`**：feature 寫在狀態行
（`- 狀態: 已完成（2026-07-21）`），task 寫在該行句尾
（`- [x] T1: …（2026-07-21）`）。日期＝實際完成日，不是寫進 backlog 的日子；
程式類以 commit 日為準。「完成」與「上生產」不同時，兩個都標
（例：`已完成（程式，2026-07-20）；上架生效 2026-07-24`）。
2026-07-27 之前的條目有一批沒標，能從 git 查到的已回填，查不到的維持空白。

## Epic E1: 補齊漏斗上層流量
- 狀態: 進行中
- 目標: 讓落地頁流量從 ~1/天 提升到穩定兩位數/天，並累積到能判斷 PMF 的最小用戶量
- 政策（原 2026-07-07 公司決策）: 現階段主線＝補流量，暫緩「新功能／升級型」產品投入；不受暫緩限制的例外＝bug 修復與維運、直接服務漏斗的產品改動、留存/完成率埋點與量測
- 展開: 下方標 `(epic: E1)` 的 features
- [ ] 2026-08-04 回顧：檢視補流量主線是否推動流量/下載/留存指標，再決定是否解除暫緩、回補產品側投入（原公司決策設定的檢核點）

## ⚠️ 待部署（程式已在 repo，尚未上生產；更新於 2026-07-27）

> **2026-07-27 更新：下方整段已過期，iOS 與 Android 都已於 07-24 前後
> 上生產**（使用者 07-27 確認 iOS 與 Android 上架時間相近）。
> Android 有明確時戳：Play 正式版 `49162866 (20260724.0021)`，
> 2026-07-24 21:26 上架、165 個國家/地區。
> 對照 commit 時間，該 build 含 07-24 21:26 之前的所有 App 改動：
> **F10 `Info.plist` 相簿權限鍵（07-20）、F13 T1a/T1b 埋點修復（07-21）、
> F18 T7·T8 ＋ 移除 `NSLocationAlwaysAndWhenInUse…`（PR #95，07-23 23:13）、
> F17 T8（PR #96，07-24 08:10）、F23 定位引導卡（07-23）**。
> 佐證：`narration.csv` 於 07-26 首次收到 `narration_*` 事件（started 2 /
> completed 1），與上架時間一致。
> 下一批待送審的是 07-24 21:26 之後的改動（含 07-24 深夜的 theme token
> 收斂、arch 守門測試等），以及使用者 07-27 起正在修的問題。

以下改動已 commit + push 到 master，但**尚未部署到生產**，使用者尚看不到：

- [x] **落地頁**（`landing/`）：已部署到 `lorescape.app`（2026-07-09，Deploy Landing workflow 從 master HEAD 重建，正式站驗證通過）。含 F2/F6 T5 定價 section（廣告 7 天試用）與 F9 景點著陸頁
- [x] **Backend**（`backend/`）：已部署到 VPS（2026-07-09，Deploy Backend workflow `git reset --hard origin/master` + `docker compose up -d --build`）。含 F1 T1 的 Reel caption CTA 文案（已改為固定常數、不吃 CTA_TEXT env）＋ F8 發布 bot
- [x] **Publisher**（`publisher/`）：F11 T2 的 reel video_url fallback 於 2026-07-13 完成，2026-07-20 使用者手動觸發 Deploy Publisher workflow 上 VPS 生效
- [x] **App**（`frontend/`）：新版本已上架商店並顯示「7 天免費試用」字樣（2026-07-20 使用者確認），F6 T4 生效
- [ ] **Backend**（`backend/`）：F31 T1 付費牆移除（2026-08-05），需手動觸發 Deploy Backend workflow 才生效
- [ ] **落地頁**（`landing/`）：F31 T3 移除定價區塊（2026-08-05），需 Deploy Landing workflow 才生效
- [ ] **App**（`frontend/`，下一輪）：待下次 build 送審才生效的累積改動——
  - F10 的 `Info.plist` 相簿權限鍵（2026-07-20 完成）
  - F13 T1a narration 埋點修復（2026-07-21）：**在此之前上架的所有版本，
    narration 事件都收不到**，所以 GA4 要等新版本有安裝量後才會開始有資料
  - F13 T1b `FirebaseAnalyticsObserver`（2026-07-21）：同上，`screen_view`
    在新版本上架前仍會是 `(not set)`
  - F18 T7 書架多層堆疊 ＋ T8 書脊鬼影字修復（2026-07-24，PR #95）。
    ⚠️ 鬼影字修法**尚未實機驗證**（本地重現不出來，見 F18 T8）
  - F17 T8 地圖出處改頂部 ⓘ 按鈕（2026-07-24，PR #96）
  - 移除用不到的 iOS `NSLocationAlwaysAndWhenInUseUsageDescription`
    （2026-07-24，PR #95）——App 只用前景定位，Always key 從未被用到
  - F31 T2：移除升級 banner、paywall 導向與 /subscription 路由（2026-08-05）
- 已是生產狀態、不需部署：App Store / Google Play 的試用設定、RevenueCat offering

## F1: IG 導流 CTA (epic: E1)
- 狀態: 已完成（2026-07-08）
- 來源: marketing/audits/cro-2026-07-06.md（P0）
- [x] T1: Reel caption 預設 CTA 改為導向個人檔案連結/App（config.py `_DEFAULT_CTA_TEXT`）（2026-07-08）
- [x] T2: IG bio 導引文案與連結（既有 bio 已含「🎧 免費下載 ↓」＋ lorescape.app 落地頁連結，2026-07-08 查證，維持現狀不新增直連商店按鈕以保留落地頁歸因）

## F2: 落地頁與商店定價/試用透明度 (epic: E1)
- 狀態: 已完成（2026-07-08；T2 商店端設定日期不詳）
- 來源: cro-2026-07-06.md（P1，Offer 層目前最弱）
- [x] T1: 落地頁新增方案與試用區塊（Free/週/月/年，2026-07-08，見 landing Pricing 元件，與 F6 T5 同一提交）
- [x] T2: 免費試用已導入（見 F6：月/年 7 天試用已在兩商店啟用），定價區塊明列試用（完成日不詳，商店端設定無 commit 可查）

## F3: 落地頁「以 Wikipedia 為據」信任區塊 (epic: E1)
- 狀態: 已完成（2026-07-08）
- 來源: cro-2026-07-06.md（P1，異議處理 + proof）
- [x] T1: 新增「AI 說的，是真的嗎？」異議處理區塊，附 Wikipedia 出處 proof（2026-07-08，landing Trust 元件，置於 JourneyJournal 後、Pricing 前；本機視覺驗證通過）
- 註：原 T2（商店描述改 Wikipedia 為據開場）經使用者決定不做，已移除。

## F5: 留存/完成率量測 (epic: E1)
- 狀態: 已完成（2026-07-08，含 live GA4 驗證）
- 來源: E1 政策（埋點不受暫緩）；marketing/audits/cro-2026-07-06.md（narration 完成率為 missing_data）
- 註: narration 四種事件（started/progress/completed/abandoned，含 completion_rate）已埋，見 docs/adr/0003；缺的是彙整視圖與留存量測
- live 驗證（2026-07-08，`lorescape-metrics --only narration,retention`）：retention 寫入 13 rows 真實 cohort 資料；narration 查詢正確、事件名（narration_started/completed/abandoned）與 App logEvent 相符，目前 0 rows（pre-traffic，尚無播放事件，有流量後自動填）。兩來源已在 metrics Sheet。
- [x] T1: 從既有 Firebase narration 事件彙整「聆聽完成率」視圖（scripts/metrics/narration.py，GA4 completed/started；單元測試通過 + live 驗證）（2026-07-08）
- [x] T2: 次日/7日留存量測（scripts/metrics/retention.py，GA4 cohort D1/D7，回溯 14 天重算；單元測試通過 + live 驗證 13 rows）（2026-07-08）

## F6: 7 天免費試用 (epic: E1)
- 狀態: 已完成（2026-07-08，全部子步驟完成）
- 來源: F2 延伸；使用者決定導入 7 天試用（CRO P1「若無 trial，導入免費試用」）
- 決定: 試用套用**月方案＋年方案**，週方案不加（7 天≈整個週期）；地區全部、eligibility 新訂閱者
- 依賴: T4/T5 依賴 T1–T3 完成；商店設定（T1/T2）需使用者操作登入與同意協議，AI 不代做
- ⚠️ 落地頁（T5）在 T1–T2 真正設好前不得先廣告試用（避免誇大不實）
- [x] T1: App Store Connect — Premium Monthly / Yearly 各建 7 天免費試用介紹性優惠（2026-07-08 完成，首週免費、175 地區、新訂閱者、2026-07-08～2027-07-08、到期前需延長）
- [x] T2: Google Play — 月/年訂閱各建並啟用 7 天免費試用優惠（2026-07-08 完成，offer id free-trial-7d、獲取新客、從未訂閱任何項目、174 地區、狀態有效）
- [x] T3: 確認 RevenueCat offering 帶出 intro offer（2026-07-08 查證：offering「default」active，3 packages 正確對應月/年/週的 iOS 產品與 Android 基本方案；未綁特定 offer=標準做法，RevenueCat 執行期自動帶出符合資格的 free-trial-7d／iOS 介紹性優惠，RC 無需額外設定，新優惠可能需數分鐘同步）
- [x] T4: App paywall 顯示「7 天免費試用」（2026-07-08 完成，TDD；SubscriptionPlan 加 freeTrialDays、資料層讀 iOS introductoryPrice / Android freePhase、卡片顯示、free_trial_days 翻譯；subscription 30 tests + full suite pass）
- [x] T5: 落地頁定價區塊廣告 7 天試用（2026-07-08 完成，Pricing 元件，月/年標「7 天免費試用」、年標推薦；本機視覺驗證通過）

## F7: 免費方案文案/程式一致性查核

- 狀態: 已完成（2026-07-08）
- 來源: 落地頁定價修正時發現免費文案不一致
- 查核結論: 真實政策＝完整故事訂閱者專屬（後端 `narration/routes.py` 回 402 enforced）；免費可瀏覽故事角度＋每日精選故事，**無每日 on-demand 次數**。本地 `_dailyFreeLimit = 1` 只是顯示用計數器（非 enforcement），且免費用戶產生完整故事一律 402、`consumeUsage` 到不了，導致 settings 永遠顯示「剩餘 1 次」卻用不到。
- [x] T1/T2/T3: 移除 settings「每日使用」區塊；清掉沒在用的殘留翻譯（paywall_title/subtitle/remaining_usage、daily_usage/remaining_today）。App full suite 552 passed。（完成日不詳）
- 可選後續（未做）：本地 usage 計數器（`_dailyFreeLimit`/`consumeUsage`）移除顯示後成為內部殘留，若要一併移除需動 narration use case 與其測試，留待需要時再清。
- ⚠️ 此為 Flutter 改動，需隨「待部署 → App」一起重新 build 送審才會生效。
- 2026-07-20：App 新版本已上架（見「待部署」段），與 F6 T4 同一次 build，程式改動應已隨之生效——未逐項獨立驗證，若使用者發現 settings 仍殘留舊文案請回報。

## F8: 每日故事 IG 發布改用 Discord bot (epic: E1)

- 狀態: 已完成並上線（2026-07-09）
- 來源: 使用者要求「每日貼文一建立就發布、不需 server 排程」→ 收斂為常駐 Discord 互動 bot
- 設計/計畫: `docs/superpowers/specs/2026-07-09-discord-publish-bot-design.md`、`docs/superpowers/plans/2026-07-09-discord-publish-bot.md`
- 架構: 常駐 Discord Gateway bot（`lorescape_publisher.bot`，publisher 容器；上線當時模組路徑為 `lorescape_backend.social.publisher_bot`，2026-07-11 隨 `docs/adr/0004-split-social-publisher-from-backend.md` 拆到頂層 `publisher/`）取代 `publisher_daemon` 的 21:00/21:10/23:10 固定 cron。本地 send 腳本只上傳素材 + 建 `pending` row；bot 每 ~60s 輪詢 `social_posts`、貼四鈕審核（✅核准／🕘排程 modal／🚀立即發布／❌拒絕），排程迴圈在「到點且已核准」時發 IG。carousel + reel 皆接管；`DAILY_STORY_PUBLISH_ENABLED=0` 只暫停排程迴圈。
- [x] T1: bot 實作（subagent-driven 12 tasks，backend 415 + scripts 107 tests 全綠；雙發防護：process lock + 重讀最新 row，republish 用 `force` 略過）（2026-07-09）
- [x] T2: 拆分部署 workflow（`deploy-backend.yml` 手動：migration → VPS compose → 健康檢查含 bot Gateway 連線；`deploy.yml`→`deploy-app.yml` 只上架 App、移除週五排程）（2026-07-09）
- [x] T3: 上線 + 實測（2026-07-09，Deploy Backend workflow 三 job 綠；service-role smoke test 確認 bot 45s 內貼審核訊息並回填 `discord_message_id`，事後清理無痕）
- 已知未做（可選後續）: 計畫 §4 的 `/republish` slash command 未實作——`interactions.republish()` 只是 Python 函式，back-fill 走既有（已於 2026-07-11 拆分時整支刪除的）`publisher.py`／`reel_publisher.py` CLI，目前後者位於 `publisher/src/lorescape_publisher/reel_publisher.py`；approve/reject/schedule 按鈕未先 `defer()`（3s ack，慢查詢理論上顯示 failed 但寫入仍成功）。

## F9: 景點 SEO 著陸頁 (epic: E1)

- 狀態: 進行中（首批已上線 2026-07-09）
- 來源: 2026-07-09 SEO 關鍵字研究——GSC 診斷官網近 90 天僅 9 曝光/0 點擊/2 頁索引，流量太低致查詢字詞被匿名化；改用 Google 自動完成挖出「[景點] 導覽app / 語音導覽」高意圖長尾金礦
- 設計: `landing/src/app/[locale]/place/[slug]` 靜態路由 + `landing/src/lib/places.ts` 資料層，複用每日故事頁版型與 metadata 模式。**新增景點只需在 `places.ts` 加一筆**（zh+en 維基為本故事 + keyword-rich metaTitle/description/keywords），sitemap 自動帶入、無需改程式
- [x] T1: 建 place 路由 + 首批 5 景點（羅浮宮 louvre、故宮 national-palace-museum、大英博物館 british-museum、聖家堂 sagrada-familia、中正紀念堂 chiang-kai-shek-memorial-hall）× zh/en = 10 頁；首頁 zh/en metadata 織入「語音導覽 app / audio tour guide app」等搜尋詞（commit c5358c51，push + Deploy Landing 部署完成，2026-07-09，正式站 10 頁皆 200、sitemap 6→16 URL）
- [x] T2: GSC 對 10 個新網址催索引（加速收錄）（完成日不詳，GSC 端操作無 commit 可查）
  - 2026-07-10 已催 9/10：5 個 zh 全部 + en louvre/national-palace-museum/british-museum/sagrada-familia；踩到 GSC 每日配額上限
  - 2026-07-11 查證：**10/10 景點頁全部「網頁已編入索引」**（含剩下未手動催的 en/chiang，Google 自然收錄）。部署後 1 天全數進索引，方向驗證通過；下一步等曝光/查詢資料，依 F9 T3 決定擴充
- [ ] T3: 1–4 週後回看 GSC 曝光/查詢，依有反應的景點決定下一批擴充；候選——叢集 B 國外（凡爾賽宮、羅馬競技場、梵谷博物館、米蘭大教堂、國王湖），叢集 C 台灣（九份、淡水紅毛城、台北 101、日月潭）
- 註: 擴充前先確認首批方向對了（有曝光/排名）再大量複製，避免版型或方向要調時改一堆頁

## F11: reel 發布 video_url fallback

- 狀態: 已完成（2026-07-13，待 Deploy Publisher 上 VPS 生效）
- 來源: 2026-07-12 晚 Meta rupload 端點故障——排程與手動發布連吃 7 次泛型
  `ProcessingFailedError`（400），連當天早上剛成功發過的同一檔案也被拒（媒體/
  帳號/配額全排除）；最後手動改建 `video_url` container（Meta 自己抓公開網址，
  不經 rupload）一次成功。細節見 memory `reel-meta-transcode-failure`。
- 目標: publisher 的 reel 發布在 rupload 回**泛型** ProcessingFailedError 時
  自動 fallback 到 video_url 路徑，不再需要人工深夜救火
- 設計注意:
  - 需要一個放得下 reel 的公開 HTTP 位置（當晚是暫調 `ig-cards` bucket 上限
    5MB→50MB 再改回；正式做法建議開專用 bucket 如 `reel-videos`、上限 100MB，
    發布成功後刪檔）
  - fallback 只對「泛型 ProcessingFailedError」觸發；明確的轉碼錯誤（"failed
    to transcode"）代表影片規格問題，fallback 也救不了，應照舊 fail
  - VPS 端 publisher 已有影片檔（`/opt/lorescape-media/daily_video/<date>/`）
    與 Supabase service key，上傳 bucket 無新依賴
- [x] T1: 開 `reel-videos` 專用公開 bucket（2026-07-13 已建：public、
  `video/mp4`、上限 50MB——100MB 超過專案全域上傳上限會 413；見
  `docs/init/2026-07-13-reel-videos-bucket-setup.md`），發布流程結束後刪除
  暫存影片
- [x] T2: rupload 泛型 400 → `ReelUploadGenericError` →
  `reel_publisher.publish_reel_with_fallback` 上傳 bucket → `video_url`（2026-07-13）
  container（`instagram.publish_reel_from_url`）→ 輪詢 → publish → 清理；
  分流只認 `debug_info.type=ProcessingFailedError` +
  `message=Request processing failed`（轉碼錯誤同 type 但 message 不同，
  照舊 fail）；測試涵蓋兩種錯誤 body 與 fallback 清理
- [x] T3: `publish_reel.py` 加 `--via-url` 旗標直走 video_url；預設路徑也
  自動 fallback（2026-07-13）
- ⚠️ T2 為 publisher 改動，需 Deploy Publisher workflow 部署後才在 VPS 生效
  （尚未部署）

## F12: reel-remotion story.json 改為 gitignored 工作檔

- 狀態: 已完成（2026-07-12）
- 來源: story.json 為每日 pipeline 重生的工作資料（正式紀錄在 Supabase 與
  marketing/outputs/），逐日 commit 無留史價值，但 tracked 導致 git status
  天天 dirty；也不能單純 gitignore——Remotion 專案要有檔案才能編譯/預覽
- 設計: 執行期檔名維持 `story.json`（所有 import/腳本/skill 文件不動）；
  gitignore `src/data/story.json`，另 track `story.sample.json` 樣本，
  `npm run dev`/`build` 前由 `scripts/ensure_story.mjs` 在缺檔時從樣本複製
  （pipeline 的 prepare_story.mjs 本來就會先寫入真檔，不受影響）
- [x] T1: story.sample.json + ensure_story.mjs + gitignore + package.json（2026-07-12）
  pre-hooks；CLAUDE.md 專案地圖同步一句

## F10: iOS 相簿儲存權限鍵補齊

- 狀態: 已完成（程式，2026-07-20）；待下次 App build 送審生效
- 來源: 2026-07-11 frontend 依賴規則還債 final review 發現；缺口自 2026-02-05（7ef8771b 移除 `NSPhotoLibraryAddUsageDescription`）即存在，非本次 camera 刪除造成
- 問題: daily story / journey 分享輸出 PNG（share_plus share sheet），使用者在 share sheet 點「儲存影像」時 app 缺 `NSPhotoLibraryAddUsageDescription`，iOS 會使該動作失敗（甚至 crash）
- [x] T1: `frontend/ios/Runner/Info.plist` 補回 `NSPhotoLibraryAddUsageDescription`（文案「將分享圖片儲存到相簿」，2026-07-20 完成）；隨下次 App build 送審才會在生產生效

## F13: App 留存診斷 (epic: E1)

- 狀態: 進行中（2026-07-27 週報：**留存仍是全案最嚴重的問題**，且流量端
  已不再是瓶頸——本週新 cohort 44 人是前週 3.7 倍，D1/D7 連兩週 0%；
  T2 未動，T1c 部分驗證）
- **2026-07-27 週報數據**（marketing/audits/weekly-2026-07-27.md）：
  本週 App 新 cohort **44**（前週 12，+267%）、Android 新用戶 33、
  iOS 活躍 +140%，但 **D1 / D7 留存連兩週 0%**——沒有任何一個新用戶隔天
  回來。上週判讀的「人進不來」已被推翻，破口在**首次使用之後**。
  這是目前 P0 中的 P0。
- 來源: marketing/audits/weekly-2026-07-13.md（P0）——本週 App 活躍腰斬
  （iOS+Android 22 vs 46）、新用戶 −56%、D1 留存幾乎全週 0%（僅 07-11
  cohort 20%）、D7 全 0%；流量端反而成長（IG 觸及 +75%、Landing 新用戶
  +40%），問題在留不住不在進不來
- [ ] T1: 跑 marketing-retention 分析流失點（GA4 cohort + narration 完成率
  交叉；narration.csv 目前 0 rows，pre-traffic，一併確認事件有無進來）
  - **2026-07-21 查證：事件沒有進來，「pre-traffic」假設否證。** GA4
    property 514854947 從 2026-05-01 至今出現過的事件只有 14 種
    （first_open / screen_view / session_start / user_engagement /
    app_update / app_remove / app_store_subscription_renew …），
    **`narration_*` 一筆都沒有**。同期 `first_open` 82 次、iOS 下載僅 6 次，
    差距 13 倍——多出來的是開發機／模擬器，也就是說開發期間必然播放過，
    事件卻仍然掛零 ⇒ 是埋點沒送達，不是沒人播。
  - 已排除：consent 預設為 ON（`ConsentState.defaultOn()`）；observer 於
    2026-05-20（6a3653c5）進 main，早於 6 月上線；`app.dart:48` 有
    `ref.watch(narrationAnalyticsObserverProvider)`；`playerControllerProvider`
    非 family，UI 與 observer 用的是同一個 provider；main.dart 已 eager
    override `sharedPreferencesProvider`。靜態檢查看不出斷點。
  - 附帶：`screen_view` 的 `unifiedScreenName` **全部是 `(not set)`**，
    畫面追蹤同樣沒設定，GA4 上無法看任何 App 內漏斗。
  - [x] T1a: 根因已定位並修復（2026-07-21，不需實機）：
    `consentRepositoryProvider` 以 `requireValue` 取 SharedPreferences，而
    `main.dart` 用 async closure override `sharedPreferencesProvider`，因此
    provider 首次被讀取時仍是 `AsyncLoading` → 丟 `StateError`。該 provider
    全 `lib/` 只有 `_consentEnabled()` 一處會讀（第一次播放才觸發），
    Riverpod 又快取 build 失敗並在後續讀取重拋 ⇒ 整個 container 生命週期內
    每個 narration 事件都失敗；emit 是 fire-and-forget 沒人 await，例外落進
    unhandled async gap，所以兩個月完全無聲。修在讀取端（先 await
    `sharedPreferencesProvider.future`）並加 `_fireAndLog`，另補走真實
    consent repository 的回歸測試——既有測試全都 fake 掉它，這正是測試全綠
    而線上全死的原因。
  - [x] T1b: 掛上 `FirebaseAnalyticsObserver`（新增 `routeObserversProvider`
    並接進 GoRouter observers），補回 GA4 畫面名稱（2026-07-21）
  - [ ] T1c: 下次 App 送審上架後，確認 GA4 開始出現 `narration_*` 與具名的
    `screen_view`（修復要隨版本才會在生產生效）
    - **2026-07-27 已驗證：`narration_*` 事件開始進來了。** 含修復的版本
      **iOS 與 Android 都在 07-24 前後上架**（Android 明確為 07-24 21:26），
      `data/metrics/narration.csv` 隨即於 **07-26 首次出現非空列**
      （started 2 / completed 1 / abandoned 1，完成率 0.5）；在此之前
      該檔自 06-27 起回溯 30 天全空。⇒ T1a 的修復在生產有效。
    - 尚未驗證，T1c 不結案：`screen_view` 是否已具名（GA4 上查
      `unifiedScreenName` 是否還是 `(not set)`）。
    - ⚠️ 目前 narration 只有 1 天、3 個事件，且無法區分是真實用戶
      或開發機（GA4 未濾 debug 流量，見 F26）。不要據此判讀完成率。
- [ ] T2: 檢查每日故事推播的實際送達與開啟情況（習慣養成迴路是否真的在
  運作）
  - **2026-07-27 升為本 feature 最優先**：D1 留存 0% 而新用戶暴增，
    習慣養成迴路是唯一能把人拉回來的機制。先確認推播有沒有真的送出、
    送達率、開啟率；再看首日 onboarding 卡在哪一步。
  - 執行方式：跑 marketing-retention（GA4 cohort × narration 完成率），
    narration.csv 現在有資料了，交叉分析已可進行。
- [ ] T3: 下週週報驗證 reel 片尾下載 CTA 成效（2026-07-13 上線
  `Cinematic.tsx` ending CTA，對「IG 觸及 1,923 → iOS 下載 1」的轉化缺口）
  - 2026-07-20 部分驗證：對「追蹤」有效（聖家堂 Reel 24h 帶進 +5 粉絲、
    profile_visits 1，本週唯一破 1 的 CTA 轉換）；對「下載」尚未見效
    （iOS 下載仍持平 2/週，觸及卻 +154%）。轉換斷層在 bio→商店這一段，
    見 F15

## F14: GA4 Android 追蹤斷線診斷 (epic: E1)

- 狀態: **重啟（2026-07-27）**——07-21 的結案結論（Android 零獲客）被本週
  數據推翻：GA4 自 **07-22 起 Android 恢復回報**，本週 Android 活躍 36、
  新用戶 33，其中 **07-26 單日 15 新用戶**。零獲客的判斷不再成立。
- **2026-07-27 時間線（用來判讀，但還不足以下結論）**：

  | 日期 | Android 活躍 / 新用戶 | 事件 |
  |---|---|---|
  | 07-11～07-21 | 0 / 0 | F14 據此於 07-21 結案「零獲客」 |
  | 07-22 | 2 / 2 | **早於新版上架**，只能是開發機或既有裝置 |
  | 07-23 | 6 / 5 | 同上 |
  | 07-24 | 7 / 7 | **21:26 Play 正式版上架（165 國）** |
  | 07-25 | 5 / 4 | |
  | 07-26 | **16 / 15** | 上架後第 2 天 |

  07-22～07-23 那 8 個活躍早於上架，不可能是新版帶來的；07-26 的 15 個
  新用戶則落在上架後，有可能是真實安裝。**兩種來源目前混在一起，
  無法分辨**（GA4 未濾 debug 流量，見 F26）。
- 分辨方式：`store_android.csv` 的 installs 匯出（Play 只在有量的月份產
  月報，目前該檔仍只有 06-27／07-14 兩列且 installs 全空）。若 8 月初
  Play 產出 2026-07 月報且有安裝數 ⇒ 確有真實獲客；若仍無月報 ⇒ GA4 那些
  新用戶多半是自家裝置，07-21 的零獲客結論依然成立。
  Play Console 該版本的「安裝數」欄目前顯示 0.00%（採用率），也偏向後者。
- 原結案理由（2026-07-21）保留於下，供對照：不是追蹤斷線，是 Android 通路
  零獲客（上線一個多月 0 安裝，使用者確認）
- 來源: marketing/audits/weekly-2026-07-20.md（P0）——`ga4.csv` 的
  `android_active_users`/`android_new_users` 自 2026-07-11 起連續 9 天全空，
  同期 Play 端無跡象顯示帳號停用，疑追蹤斷線而非真的零活躍
- **2026-07-21 查證：原假設（追蹤斷線）證據反向，Android 應是真的零安裝。**
  Play reports bucket 讀取正常（service account 權限 OK），但
  `com.paulchwu.instantexplore` 全 bucket 只有 **2026-03 一個月**的檔案，
  內容僅一列 `2026-03-29，Daily User Installs 1`（上架前內測）；
  **2026-04 之後零匯出，`stats/ratings/` 該 package 0 個物件**。Play 只在
  有量的月份產月報 ⇒ 沒有月報＝沒有安裝，而非匯出故障。Play 商店頁本身
  存活（HTTP 200）。`store_android.csv` 至今 0 列如實反映此事。
- 據此本 feature 的問題重新定義：不是「追蹤斷線」，是 **Android 通路沒有
  任何獲客**（上線一個多月 0 安裝）。
- [ ] T1: ~~檢查 App 端 Firebase Analytics 初始化與 GA4 Android 資料流設定~~
  → 改為：查 Play 商店頁能否被搜尋到（曝光/可見度）、上架狀態與國家/裝置
  相容性設定，確認是「沒人找得到」還是「找到了不下載」
- [ ] T2（2026-07-27 新增）: 確認 Play Console 報表 bucket 的 installs 匯出
  是否已開通並有 2026-07 月報。這是分辨上述兩種解釋的唯一證據；在此之前
  不要對 Android 通路下任何結論，也不要據此調整行銷投入。

## F15: IG → 下載轉換優化 (epic: E1)

- 狀態: 進行中（2026-07-21 量出斷層位置：落地頁不漏，損失在 reach→profile；
  T1 bio 文案已定稿待手動貼上，T2 片尾維持已驗證版本）
- 來源: marketing/audits/weekly-2026-07-20.md（P0）——本週 IG 觸及 +154%
  （1,923→4,879）、粉絲 +147%，但 profile_views 轉換率僅 0.6%（30/4,879，
  < 1% 月底檢核門檻）、iOS 下載持平在 2；問題在帳號定位/CTA 不在觸及量
- [x] T1: 改 IG bio 文案（現況「🎧 免費下載 ↓」+ 落地頁連結），加強價值主張
  句，非僅動詞指令（2026-07-21）
  - **2026-07-21 已套用上線**（瀏覽器手動操作；IG Graph API 無寫入端點），
    以 Graph API 讀回驗證 name / biography / website 皆為新值。
    名稱欄不在 IG 網頁版「編輯個人檔案」，實際位置是帳號管理中心 →
    個人檔案 → 姓名（注意：**14 天內只能變更兩次姓名**）。
  - 定稿內容：
    - 名稱欄：`Lorescape・AI 旅行說書人` → `Lorescape・景點故事語音導覽`
      （名稱欄是 IG 搜尋唯一吃關鍵字的欄位；「AI 旅行說書人」無人搜尋，
      「景點／故事／語音導覽」才是真實查詢詞）
    - 簡介：
      ```
      Google 只給你條目，我們給你故事。
      站在任何景點前，聽一段以 Wikipedia 為本的真實故事。
      🎧 App Store・Google Play ↓
      ```
      第一行改為對比句而非自我描述，直接命中 MARKETING.md 的 pain
      （「查 Google 只有條目式資訊」）；第二行保留 Wikipedia 建立信任。
  - **連結決策（2026-07-21）：`website` 維持 `lorescape.app`，不改直連
    App Store。** 曾評估砍掉「bio → 落地頁 → 商店」中間那一跳（Android
    至今 0 安裝、iOS 是唯一真實通路），但落地頁同時是 SEO 資產，決定保留。
    ⇒ bio→商店的漏損要改從**落地頁**下手（商店按鈕的位置與可見度），
    而非改 bio 連結。
- **2026-07-21 漏斗量測：斷層不在 bio→商店，在 reach→profile。** GA4 近 30 天
  `download_click` 共 **6 次**（hero 3 / footer 1 / navbar 1 / place 1），
  同期 iOS 下載 **6 次**——落地頁的商店按鈕點擊到實際安裝幾乎 1:1，沒有漏。
  落地頁 CTA 本身也已齊備：Hero（首屏）、Navbar、FinalCTA、Footer 都有
  `StoreButtons`，且 `storeUrlFor()` 已帶 App Store `ct` 與 Play install
  referrer 歸因參數。⇒ **不要再投資重做落地頁 CTA**。
  真正的損失全在上游：reach 2349 → profile_visits 16（0.7%）→ 落地頁
  每日僅 1–2 人。修 profile_visits 的槓桿是片尾 CTA 與 caption（見 T2），
  以及 bio 能不能讓人願意點連結（T1）。
  - 這修正了 F13 T3 於 07-20 的判讀（「轉換斷層在 bio→商店這一段」）。
  - 樣本極小（n=6），數字只能當方向不能當結論。
- [ ] T3: 2026-08-04 前後回看 bio 改版成效——比較 `data/metrics/ig.csv` 的
  `profile_views` 與 `ga4.csv` 的 `web_active_users`（bio 連結指向落地頁，
  這段就是 bio 的責任區）。**注意樣本量**：目前落地頁每天僅 1–2 人，
  至少累積兩週才有訊號，別在幾天內就下結論。基準＝07-21 之前 30 天。
  - 2026-07-27 中期讀數：本週 profile_views / reach = **1.0%**
    （26 / 2,612），前週 0.6%。方向對但仍在門檻邊緣，且同期落地頁
    web 新用戶反而降到 2（前週 8）——bio 改版目前看不出把人帶到落地頁。
    樣本仍極小，8/4 再判。
- [ ] T2: 統一 Reel 結尾 CTA 為固定模板——聖家堂 Reel（7/19）24h 帶進 +5
  粉絲、profile_visits 1，是本週唯一有效轉換的片尾，複製其結構到後續
  daily reel（見 F13 T3 註記）
  - 2026-07-21 一度把片尾改成「這裡的故事說完了／那你現在站的地方呢？」，
    但那等於換掉本週唯一有實證的版本，且與本 task 的方向相反，**已 revert**
    （e811abc4）。片尾維持 7/13 上線的版本。單獨保留的是字型 subset 缺字
    修復（b6e8598a），與文案無關。

## F19: publisher/.env 是佔位值（維運風險）

- 狀態: 待辦
- 來源: 2026-07-21 開工時發現——`publisher/.env` 內容是範本佔位值
  （`SUPABASE_URL=https://your-project.supabase.co`），真正的憑證只存在
  使用者的 shell 環境變數裡
- 風險: publisher 的程式與 skill 文件都假設「bare `load_dotenv()` 會撈到
  `publisher/.env`」。只要在沒有 export 環境變數的 shell 裡跑
  `cd publisher && uv run python ...`，就會連到不存在的專案；若哪天佔位值
  換成別的真實專案，更可能寫錯資料庫。dashboard 的 config 也會載入這份
  `.env`（`override=False`，目前靠環境變數先存在才沒出事）
- [ ] T1: 把真實憑證寫進 `publisher/.env`（該檔已 gitignore），或改為明確
  要求由環境變數提供並讓 `Config.from_env()` 在讀到佔位值時直接報錯，
  不要靜默連到錯的地方

## F20: Cloudflare www subdomain 轉址到主網域

- 狀態: 已完成（2026-07-22，瀏覽器操作 + curl 實測通過）
- 來源: 使用者要求（2026-07-22）——`www.lorescape.app` 目前未轉址到
  `lorescape.app`，需在 Cloudflare 設定 www → apex 轉址
- 範圍備註: 屬維運工作，不受 E1 暫緩政策限制；www 打不開也會漏接輸入
  `www.` 習慣的使用者與部分外部連結，間接影響漏斗
- 發現: 原本 `www` **根本沒有 DNS 紀錄**（`Could not resolve host`），不只是
  少一條轉址規則；apex 的 A 記錄是 DNS only（灰雲），而 Redirect Rule 只對
  走 proxy 的流量生效，故 www 必須設成 Proxied（橘雲）規則才吃得到
- [x] T1: 兩步完成（2026-07-22）——
  1. DNS 加 `www` CNAME → `lorescape.app`、**Proxied（橘雲）**
  2. Redirect Rule（用 Cloudflare 內建 `redirect-www-to-root` 範本）：
     `https://www.*` → `301` `wildcard_replace(http.request.full_uri,
     "https://www.*", "https://${1}")`，用 `full_uri` 故 path 與 query
     皆由 wildcard 帶過去（不需另勾 Preserve query string，避免 query 重複）
  - 實測（curl `--resolve` 繞過本機 DNS 負快取）：
    `https://www` → 301 → `https://lorescape.app/`（SSL 驗證 0、無警告）；
    `https://www/place/louvre?utm=test` → 301 保留 path+query；
    `http://www` → 兩跳（Always Use HTTPS → 轉址規則）最終落 `lorescape.app/zh` 200

## F21: Reel 略過率是觸及的主要驅動因子 (epic: E1)

- 狀態: 待辦
- 來源: 2026-07-23 開工，把當日三支 checkpoint 快照寫進
  `data/metrics/ig_reels_insights.csv` 後，對全表 33 列做同 checkpoint 比對
- **發現（n=11／checkpoint，三個 checkpoint 一致）：略過率與 views 穩定負相關。**

  | checkpoint | 相關係數 r | 低略過組中位 views | 高略過組中位 views | 倍率 |
  |---|---|---|---|---|
  | 24h | −0.76 | 727（略過 46.7–61.3%） | 212（略過 68.2–81.3%） | 3.4x |
  | 48h | −0.79 | 1,034（45.7–60.1%） | 224（67.5–82.5%） | 4.6x |
  | 7d | −0.64 | 960（38.5–52.5%） | 214（57.9–79.6%） | 4.5x |

  這把 `_reels-place-calendar.md` 於 07-21 用 n=2（布拉格 45.5%→2797、
  金字塔 70.1%→243）提出的「24h 略過率是唯一該盯的先行指標」從觀察
  升級為 n=11、跨三個 checkpoint 都成立的關係。
- **副發現：`avg_watch_time` 是誤導性指標，不要拿來優化。** 它與 views
  的 r 僅 **−0.18**（7d），而且方向是負的——表現最差的兩支平均觀看時間
  最長（撒哈拉 40 秒／略過 79.6%／119 views；佩特拉 26 秒／70.1%／
  250 views）。合理解釋是倖存者偏誤：看的人越少，留下來的越是本來就
  有興趣的，平均秒數反而被推高。
  - 這修正了 2026-07-23 當下對使用者的初步判讀（曾把「低略過 + 長平均
    觀看」並列為蘇州表現好的原因；實際上只有略過率有解釋力）。
- 意涵: 略過率是**前三秒 hook** 的直接產物，不是選點的產物。若此關係成立，
  選點 calendar 的配比調整對觸及的槓桿，遠小於 hook 怎麼寫。
- [ ] T1: 盤點 `ig_reels_insights.csv` 低略過組（<53%）與高略過組（>63%）的
  hook 句，找出可複製的結構差異，寫成 hook 模板進
  `lorescape-daily-reel` skill。
  - 初步觀察（**尚未驗證，不可當結論**）：低略過組多為「具體的人或家戶
    處境 + 明確衝突」（蘇州「一個被貶到底的官員」、白川鄉「一戶人家永遠
    蓋不起來」），高略過組多為抽象或地理性描述（「這座城市曾經富甲沙漠」）。
  - **注意**：句式不是變因。calendar 於 07-21 已證偽「疑問句 hook 拉觸及」，
    本表也一致——疑問句同時出現在低略過（馬丘比丘 38.5%、姬路城 52.5%）
    與高略過（石見銀山 63.7%）兩端。
- [ ] T2: 8/3 期末檢核的方法改用**略過率**當主要應變數，而非 reach/views。
  reach 受發布時間與觀測長度污染，略過率是同一支片內的比率、可直接互比。
  檢核「日韓 > 其他」假設時，先看各類型的略過率中位數是否有差，再看 reach。
- [ ] T3: 每天做 24h checkpoint 快照的優先級提高——它是唯一的先行指標，
  且漏抓不回補（見 lorescape-metrics skill）。目前 33 列已足以支撐上述分析，
  但 hook 模板要驗證需要更多樣本。
- 邊界: 這是相關性不是因果，且三個 checkpoint 的樣本高度重疊（同一批 Reel
  的不同觀測點），實質獨立樣本約 11 支。IG 演算法把略過率當排序訊號是合理
  推測，但無法從本資料證實。

## F25: 故事鉤子步驟埋點 (epic: E1)

- 狀態: 進行中（2026-07-26 埋點完成，待隨下次 App build 上生產驗證）
- 來源: 使用者詢問「呼叫後端產生三個故事 hook 會有 GA 紀錄嗎」（2026-07-26）
  查證後發現：**完全沒有**
- 範圍備註: E1 政策明列「留存/完成率埋點與量測」為暫緩例外
- 查證結論（2026-07-26）:
  - 後端零 GA：`grep -rni "analytics|ga4" backend/src/` 0 筆。GA4 純 client-side，
    `/narration/hooks` 只寫容器 log（`narration.hooks_cache.hit` 等）
  - App 原本只有四個自訂事件（narration_started / progress / completed /
    abandoned），全綁 `narrationId`、全由播放器 observer 發出 ⇒ 只有真的播了才有
  - hook 流程四個檔案（screen / controller / service / api_service）零埋點
  - 唯一痕跡是 `FirebaseAnalyticsObserver` 的自動 `screen_view`，而該畫面 route
    是 `path: '/config', name: 'config'`（go_router 17.2.3 `builder.dart:397` 用
    `state.name ?? state.path`）⇒ **GA4 上這個畫面叫 `config`**，看起來像設定頁，
    極易誤讀
  - ⇒ 漏斗在 `screen_view(config)` 到 `narration_started` 之間是斷的：
    「產生了角度但沒人想聽」答不出來
- [x] T1: 新增三個事件（2026-07-26）——`hooks_requested`（分母）、
  `hooks_returned`（帶 outcome success/empty/insufficient_source/error ＋
  hook_count）、`hook_selected`（帶 hook_index、hook_count、selected_default）。
  三者共同帶 `place_id` 與 `language`
  - **不做原本提的 `hooks_abandoned`**：放棄率＝有 `hooks_returned(success)`
    但無 `hook_selected`，在 GA4 端可直接推導；為它做 dispose-time 追蹤要在
    autoDispose family 上加「是否已選取」旗標，複雜度不值那點停留時間資訊
  - 事件階層改成家族制：`AnalyticsEvent`（eventId / occurredAt）→
    `NarrationAnalyticsEvent`（narrationId）／`StoryHookAnalyticsEvent`
    （placeId / language）。鉤子事件**不帶 narration_id**——那時 narration
    還不存在，硬塞會讓報表誤導
  - `firebaseParametersFor` 改由 `envelope()` + `payload()` 推導（原本逐型別
    列欄位的 switch 刪除），新事件不必再回頭改 data 層
- [x] T2: 抽出 `AnalyticsEmitter`（`analytics/domain/services/`）＋
  `analyticsEmitterProvider`，consent 檢查與 fire-and-forget 失敗記錄收在一處。（2026-07-26）
  observer 的四個發送點改走它，**F13 T1a 那段 `requireValue` 的坑只留一份實作**
  （原本若複製到新發送點，等於把兩個月無聲的 bug 再種一次）
  - provider 取不到底層服務時退化為 no-op：`FirebaseAnalytics.instance` 在
    Firebase 未 `initializeApp` 時會丟 `FirebaseException`，而發送點在畫面主
    流程上——實作過程確實踩到（11 個測試因此紅），不能讓埋點把功能帶掉
- [ ] T3: 下次 App 送審上架後，確認 GA4 出現 `hooks_requested` /
  `hooks_returned` / `hook_selected`，並用它們算出「產生角度 → 開始聆聽」的
  轉換率。與 F13 T1c 同一版驗證
- [ ] T4（可選）: 把 hook 畫面的 route `name` 從 `config` 改成語意化名稱
  （如 `select-story-hook`），否則 GA4 的 `screen_view` 永遠叫 `config`。
  ⚠️ 這是 `pushNamed('config')` 的呼叫點都要跟著改，且會讓歷史 screen_view
  資料斷點，改前先確認值得
- 驗證: `fvm flutter analyze --fatal-infos` 乾淨、`dart format` 對 lib 無變更、
  full suite 585 passed（新增 emitter 4 個、事件模型 4 個、hook 畫面行為 3 個）

## F16: 後端可觀測性（server 狀態檢測）

- 狀態: 待辦
- 來源: 使用者要求（2026-07-21）——增加 Lorescape 後端的可觀測性，可以檢測
  server 的 CPU、memory、disk、是不是活著等狀態
- 範圍備註: 屬維運工作，不受 E1 暫緩政策限制（政策明列「bug 修復與維運」為
  例外）
- [ ] T1: 規劃可觀測性方案（VPS 上 backend + publisher 容器的 liveness、
  CPU / memory / disk 監控；含通知管道與工具選型），再拆實作 tasks

## F17: 探索頁面重新設計

- 狀態: 已完成（2026-07-21）
- 來源: 使用者要求（2026-07-21）——重新設計 App 探索頁面，參考 Claude Design
- 設計稿: `docs/design/project/Lorescape Redesign v2.html` +
  `docs/design/project/app2/`（Claude Design 專案
  `dcdb2009-b819-4361-8be6-eeb8ba93005b`）。v1（`app/`）＝目前已實作的版本，
  v2（`app2/`）＝這次要做的新版；差異表見 `docs/design/README.md`
- 設計 token 已在 `frontend/lib/app/config/lorescape_tokens.dart`（v1 時落地），
  這次不動 token，只換探索頁的**結構**
- 方向決定（2026-07-21，使用者拍板）: **照設計做全螢幕地圖，導入 flutter_map**
- ⚠️ 風險: OSM 官方 tile server 的 usage policy 明文禁止 app 級別的重度取用，
  T1 必須先決定 tile 來源（自架 / MapTiler / Stadia 等），不能直接把
  設計稿的 `tile.openstreetmap.org` 帶進生產
- ⚠️ 這是 Flutter 改動，需隨下次 App build 送審才生效（與 F13 T1c 同一版）
- [x] T1a: 匯入 v2 handoff bundle 到 `docs/design/`（2026-07-21）
- [x] T1: 選定 tile provider 與授權/成本方案（2026-07-21，
  `docs/adr/0005-map-tile-provider.md`）——**OpenFreeMap 公共實例 + vector
  tiles**（`flutter_map` + `vector_map_tiles` 9.0.0-beta.9）。零成本、無用量
  上限、無 API key，且樣式可完全照 field journal 色票調（vector 的決定性
  優點）。Stadia / MapTiler 的免費方案都**禁止商業使用**，訂閱制 App 不可用。
  plan B ＝ Geoapify Free + raster + sepia 濾鏡
  - ⚠️ ADR 初稿選的是 Geoapify，理由「`vector_map_tiles` 只支援
    flutter_map 7.x」**經查證為錯**（beta 線已相依 `flutter_map ^8.1.1`），
    使用者質疑後修訂；修訂紀錄留在 ADR 文末
- [x] T2: 底圖 widget（2026-07-21）——`flutter_map ^8.1.1` +
  `vector_map_tiles 9.0.0-beta.9`（釘死確切版本）+ `latlong2`；
  `LorescapeMap`（`features/explore/presentation/widgets/lorescape_map.dart`）
  含 loading / error / data 三態與 attribution 角標，`mapStyleProvider`
  以 `StyleReader` 讀 OpenFreeMap positron 樣式並 `keepAlive` 快取。
  4 個 widget test、full suite 543 passed、analyze 乾淨
  - 注意：**不要把 tile URL 寫死**，OpenFreeMap 的 tile 路徑帶每週重建的
    日期段（`/planet/20260621_080001_pt/...`），必須由 style/TileJSON 在
    執行期解析
  - 使用者決定跳過效能 spike，也不保留 raster 退路（ADR 0005 已記）
  - **已在 iPhone 16 Pro simulator 目視驗證通過**（2026-07-21，marionette）：
    vector tile 正常渲染（海岸線、國界、多語地名）、平移流暢無空白 tile、
    attribution 角標可見。驗證方式是暫時把 ExploreScreen 換成地圖，**驗證後
    已完整還原**
  - ⚠️ 還沒接進 ExploreScreen（T5 才接）
- [x] T2b: 依 field journal 色票調整 style JSON（2026-07-21，模擬器目視驗證
  通過）。positron 原樣式是冷灰色系，與設計稿的暖紙感落差明顯，非改不可
  - `tool/build_map_style.py`：抓上游 positron、以「顏色→顏色」對應表遞迴
    重新上色（走整棵樹，才能改到 `["interpolate", ...]` 葉節點裡的顏色）、
    移除沒用到的 raster source，產出 `assets/map/lorescape_style.json`。
    上游若出現未對應的新顏色，腳本**直接失敗**而非默默留下冷灰色
  - `mapStyleProvider` 分工：**配色**用本地 asset，**tile 來源與 sprites**
    仍由上游 `StyleReader` 解析（含每週變動的 tile 路徑）；並把 providers
    過濾成本地樣式真的用到的 source，避免白白下載沒人顯示的 raster PNG
  - **踩到的坑（重要）**：`vector_map_tiles` 的磁碟快取 key 是
    `{z}_{x}_{y}_{source}.pbf`、**不含樣式身分**，TTL 預設 30 天。改了配色
    後畫面完全沒變，手動刪掉快取才生效——代表樣式改版對既有使用者最長
    30 天不會生效。解法：樣式 JSON 帶內容雜湊當版本號，
    `MapTileCacheService` 依版本切快取目錄並清掉舊版本，換樣式＝換目錄。
    已在乾淨建置下驗證新配色自動生效
- [x] T3: 地點 pin（2026-07-21）——`PlaceMapPin` 依設計稿以旋轉 -45° 的圓角
  方塊做水滴造型、紙色描邊與內點，依 `JournalCategory` 上色（設計稿只指定
  urban / heritage，其餘沿用 clay）；點 pin 進地點頁。地圖首次拿到地點座標時
  自動 `fitCamera`（maxZoom 6），只框一次不干擾後續操作
- [x] T4: 浮層 header（2026-07-21）——眼眉線「N 個地點 · Atlas」＋襯線大標
  ＋filter / refresh 圓鈕＋浮起式搜尋列，底下鋪紙色漸層
  - **踩到的 bug**：原本把整個浮層包進 `IgnorePointer` 讓漸層不擋觸控，再用
    巢狀 `IgnorePointer(ignoring: false)` 想收回來——**收不回來**，外層一旦
    排除整個子樹，搜尋/篩選/重新整理全部點不到。三個測試同時掛掉才抓到。
    正解是漸層獨立成一層 `Positioned.fill` + `IgnorePointer`
- [x] T5: 底部橫向卡片列（2026-07-21）——252px 卡片、縮圖／名稱／分類標籤／
  圓形前往鈕；點卡片本體 `flyTo` 該地點，點箭頭才進地點頁
  - **設計稿的缺口**：v2 的 map-card 沒有書籤，但探索頁卡片是**全 App 唯一
    能收藏地點的入口**（`togglePlace` 只有這一個呼叫點），照抄等於靜默刪功能。
    改把書籤壓在縮圖角落（含紙色底盤，否則深色照片上看不見）
- [x] T6: FAB 與 filter sheet 定位（2026-07-21）。設計稿的 `bottom:96` 會讓
  收藏 FAB **正好壓在卡片列上**（實機確認），改成貼著卡片列上緣浮放
- [x] T7: 邊界情境與測試（2026-07-21）——定位失敗 / 無地點 / 樣式載入失敗
  各有可見說明；`fvm flutter analyze --fatal-infos` 乾淨、full suite 545 passed
  - **修回一個 regression**：改版時卡片列的 error 分支回傳空白，把定位被拒的
    錯誤訊息吞掉了（整合測試抓到）。現在錯誤會以說明卡顯示在卡片列位置
  - 測試基礎建設：`test/helpers/fake_map_style.dart` 提供
    `fakeMapStyleOverrides()` 與 `settleMapTimers()`。**任何會渲染地圖的測試
    都要用**——不 override 樣式，`FlutterMap` 根本不會建出來；不跑完
    `vector_map_tiles` 排的 3 秒 timer，測試會以「Timer 尚未結束」失敗，
    而且訊息完全看不出跟地圖有關
- [x] T8: 地圖出處從右下角文字角標改為頂部 icon 列的 ⓘ 按鈕（2026-07-24,
  PR #96）。使用者要求把出處從地圖移進 icon 列。出處是 OpenFreeMap / OSM 的
  授權義務不得移除，但 OSM attribution guideline 允許小螢幕收進「明顯且直接
  可及」的入口——ⓘ 點擊彈出完整出處＋openstreetmap.org/copyright 連結。從
  `LorescapeMap` 移到探索頁浮層（`LorescapeMap` 目前僅此一處使用）。ADR 0005
  attribution 段同步更新

## F18: 歷程頁面重新設計

- 狀態: 已完成（2026-07-21）
- 來源: 使用者要求（2026-07-21）——重新設計 App 歷程頁面，參考 Claude Design
- 設計稿: 同 F17（`app2/screens_history.jsx`）
- 方向決定（2026-07-21，使用者拍板）: **照設計，歷程首頁只留旅程書架**，
  移除現有的「全部時間軸 ／ 依旅程」分段控制；時間軸內容改由點進某本
  旅程後的手記翻頁器閱讀。「未分類」（`tripId == null`）沿用既有概念，
  在書架上成為一本書
- ⚠️ 這是 Flutter 改動，需隨下次 App build 送審才生效（與 F13 T1c 同一版）
- [x] T1a: 匯入 v2 handoff bundle 到 `docs/design/`（2026-07-21）
- [x] T1: 手寫體 Long Cang（2026-07-21）——不需打包字型檔，專案已用
  `google_fonts`，`GoogleFonts.longCang()` 直接可用
- [x] T2: `JourneyScreen` 換成 Masthead ＋ 旅程書架（2026-07-21）。
  `TripBookshelf`：凹槽背板、四色書皮、高度 190/204/218 循環、木層板含前緣
  厚度；書名**逐字換行**而非 `RotatedBox`——CJK 的 `writing-mode:vertical-rl`
  是字元直立堆疊，用旋轉會讓中文躺著。未分類仍是一本書（沒有未歸類記錄時
  才隱藏，沿用舊 TripGrid 的判斷）。`Masthead` 抽到 `shared/widgets/journal/`
- [x] T3/T4: 手記翻頁器（2026-07-21，`shared/widgets/journal/notebook_pager.dart`）
  ——紙頁、拍立得（奇偶頁左右交替傾斜、角上膠帶）、Long Cang 手寫圖說、
  日期戳、頁碼、分享/刪除、頁點指示器
  - **偏離設計稿**：翻頁改用 `PageView`，沒有照抄手寫的拖曳邏輯（60px 門檻、
    0.32 阻尼）。自己排一列滿寬頁面會讓 `Row` 永遠 overflow，`ClipRect` 只
    遮得住畫面、遮不住框架斷言，測試直接掛。`PageView` 手感同類且附帶
    無障礙與捲動語意
  - 拍立得尺寸取「可用寬度」與「可用高度扣圖說」的較小者；原本用
    `AspectRatio` 會以寬度為準，頁面矮時爆版 639px
- [x] T5: `TripDetailScreen` 接上翻頁器（2026-07-21）。**多選模式仍走原本的
  列表**——翻頁器一次只看得到一張，沒辦法批次勾選/移動/匯出，硬套會把既有
  功能弄殘。多選、移動到其他旅程、PDF 匯出、刪除全部保留
  - 架構守門測試抓到我讓 trip feature 跨引 journey 的 presentation，
    已把 `NotebookPager` 移到 `shared/widgets/journal/`
- [x] T6: 殘留盤點（2026-07-21）——移除已無人使用的 `JourneyViewMode`、
  `journeyViewModeProvider`、`journeySearchQueryProvider`、
  `filteredJourneyItemsProvider` 與其測試檔，以及 5 個變成孤兒的 i18n key
  （`view_timeline` / `view_by_trip` / `search_hint` / `no_results` /
  `no_entries`）
  - ⚠️ **歷程頁的搜尋功能隨時間軸一起消失了**。這是 v2 設計的取捨，不是疏漏；
    若之後想找特定記錄，需要重新設計入口（例如書架上加搜尋，或旅程內搜尋）
- 驗證: `fvm flutter analyze --fatal-infos` 乾淨、full suite 535 passed

### F18 後續調整（2026-07-24）

- [x] T7: 書架改多層堆疊，取代橫向捲動（2026-07-24, PR #95）。使用者反映書多
  時要橫滑才看得到後面的書、發現成本高。改成一層放不下就往下長出新的一層
  書架（各自凹槽背板 ＋ 木層板），整頁本來就能上下捲。一層放幾本依可用寬度
  算（`LayoutBuilder`，390pt 下 4 本）；書高與配色沿用全域序號，換層時花色
  繼續變化。新增 `trip_bookshelf_test.dart`（多層換行 / 靠同一左邊界 / 無橫向
  Scrollable / caption）
- [x] T8: 修書脊上的鬼影字（2026-07-24, PR #95）。實機 iOS 上書名某一行會有
  一份「字影」被畫到框線左外側，偏移量剛好等於一個行高（15 × 1.15 = 17.25px）、
  往下 1px、色 `#66000000`——即 `TextStyle.shadow` 那層。T2 的「書名逐字換行」
  原本是把字用 `\n` 接成一個多行 paragraph；改成逐字各一個單行 `Text` 堆在
  `Column`（單行 paragraph 沒有跨行版面），書名外框再加 `ClipRect` 保險
  - ⚠️ **尚未實機驗證**：本地重現不出鬼影（測試走 Skia CPU raster、字型也非
    實機 Noto Sans TC）。改前改後渲染逐像素 diff 為 None，是純結構重構。若下次
    TestFlight 仍有鬼影，下一步＝拿掉 `_VerticalTitle` 的 `shadows`


## F23: 定位權限 pre-permission 說明卡

- 狀態: 待辦
- 來源: 使用者詢問「一打開 app 會要求權限嗎」引出（2026-07-24）
- 背景: 目前使用者第一次進「探索」分頁時，`PlacesController.build()` →
  `GeolocatorService.getCurrentLocation()` 會**直接彈系統權限框**，沒有前置
  說明。系統框只有一次機會（iOS 拒絕過 `requestPermission()` 不再彈；Android
  11+ 拒絕兩次同理），拒絕後只能靠 `_LocationGateCard` 引導去系統設定，回收
  率低。加一張自製說明卡在系統框之前，讓沒意願的人先被篩掉、不消耗那次機會
- 限制: geolocator 的 `LocationPermission` 沒有 `notDetermined`，Android 上
  「沒問過」與「拒絕過一次」都回 `denied`，無法區分——所以做法是「只要不是
  已授權也不是 deniedForever，就先顯示卡片，按鈕才觸發系統框」
- 註: 這張卡與現有的 `_LocationGateCard`（`explore_screen.dart`）是同一張卡的
  鏡像——那張是「被拒絕後」顯示，這張是「還沒問過時」顯示
- [ ] T1: 擴充 explore widget test，鎖住「進探索分頁不自動彈框」——用
  `FakeLocationService` 加計數器，斷言進入時 `requestPermission()` 次數為 0、
  卡片有出現；點按鈕後才變 1 且授權成功觸發 `refresh()`（先寫成紅燈，TDD）
- [ ] T2: 移除 `GeolocatorService` 的自動請求——`getCurrentLocation()` 遇
  `denied` 直接丟 `LocationError.permissionDenied`，不再自動 `requestPermission()`。
  對齊 `test/integration/permission_denial_flow_test.dart`
- [ ] T3: 改寫 `explore.map`／`location_gate` 的 `permission_denied` 文案為
  事前邀請語氣，補隱私保證句（只在使用 App 時取用、不背景追蹤）。zh-TW / en
- [ ] T4（選配）: 卡片加次要動作「先看看就好」，收起卡片、該 session 不再顯示
  （UI-only provider 存旗標）
- [ ] T5（選配）: 授權漏斗埋點——卡片曝光 / 按下允許 / 授權結果三事件接
  Firebase Analytics，之後才有數據判斷是否提升授權率
- [ ] T6: 實機手動驗收——iOS / Android 各跑全新安裝→卡片先出現→按鈕才彈系統
  框；iOS「允許一次」重開 App 行為；Android 拒絕兩次後卡片切「前往設定」

## F24: 行銷行事曆——以未來事件驅動內容提前準備 (epic: E1)

- 狀態: 待辦
- 來源: 使用者要求（2026-07-24）——建立一份行銷行事曆，透過未來事件反推
  「現在要提前準備什麼內容」，不再只被動跟每日產線走
- 範圍備註: 服務漏斗上層流量（讓內容搭上事件的搜尋與社群聲量高峰），屬
  E1 主線，不受暫緩政策限制
- 事件兩大類:
  1. **文化時刻**——大型賽事（超級盃、世界盃、奧運）、節慶（農曆年、中秋、
     聖誕、萬聖節…）、季節轉換（賞櫻、楓葉、暑假、連假出遊潮）
  2. **產業事件**——旅遊/科技大型會議與展會（ITB、TTE、台北旅展、WWDC、
     Google I/O）、旅遊業行事曆節奏（訂票高峰、旅遊淡旺季）、相關產品
     發布（Apple/Google 系統更新影響 ASO、競品動態）
- 與既有資產的分工: `marketing/content-calendar/` 目前只有 Reels 景點排程
  （lorescape-reels-planner，管「哪天發哪個景點」）；本行事曆管的是**事件
  →內容的提前量**（哪個事件要在幾週前開始準備什麼），兩者互補——事件行事曆
  決定主題檔期，Reels calendar 在檔期內落實選點
- 每個事件至少要回答: 事件與日期、對 Lorescape ICP（深度知性旅人）的切角、
  要準備的內容形式（Reel 選點檔期 / 景點 SEO 頁（F9）/ IG 貼文）、
  **lead time**（何時開始準備）、負責流程（哪個 skill / 例行）
- [ ] T1: 定義行事曆格式與存放位置——`marketing/content-calendar/` 內新增
  事件行事曆檔（markdown 表格即可，欄位：日期、事件、類型、ICP 切角、
  內容形式、lead time、狀態），並在 CLAUDE.md 的 content-calendar 說明
  同步一句
- [ ] T2: 盤點未來 6 個月（2026-08 ～ 2027-01）的事件並填入行事曆——
  文化時刻與產業事件各自列出，逐一過濾「與深度旅人/景點故事有無自然
  連結」，沒有切角的事件不硬蹭
- [ ] T3: 對留下的每個事件定義提前準備計畫——內容形式、lead time 與觸發日
  （例：楓葉季 Reels 檔期提前 3 週選點；旅展前 2 週備 SEO 頁）
- [ ] T4: 接進例行——SCHEDULE.md 加「每月 1 號檢視未來 60 天事件、啟動到期
  的準備項」，讓 lorescape-scheduler 開工時自動帶出；每月順手補上新滾入
  的第 6 個月事件
- [ ] T5（可選）: 首個檔期實跑驗證——挑最近一個事件（依 T2 結果）走完
  「提前準備→發布→回看成效」一輪，把經驗修回 T1 的格式與 T3 的 lead time

## F26: GA4 未濾除開發流量，App 端指標不可信 (epic: E1)

- 狀態: 待辦
- 來源: marketing/audits/weekly-2026-07-27.md 判讀過程——本週 App 數字
  無法分辨真實用戶與自家裝置，直接卡住 F13（留存）與 F14（Android 獲客）
  兩個 P0 的結論
- 問題：GA4 property 514854947 收得到開發機／模擬器流量，且沒有任何標記
  可以濾掉。已知落差——
  - F13 於 2026-07-21 查得：`first_open` 82 次 vs iOS 實際下載 6 次（13 倍）
  - 2026-07-27：GA4 Android 新用戶 33（07-26 單日 15）vs Play installs
    匯出 0；GA4 iOS 新用戶 4 vs App Store 下載 2
- 影響：cohort / 留存 / narration 完成率全部混入開發流量。模擬器每次重裝
  算一次新用戶且不會隔天回訪，**會把 D1 留存往 0% 壓**——目前無法判斷
  「D1 0%」有多少是真實現象、多少是測量假象。
- [ ] T1: 在開發裝置與模擬器上標記 internal traffic（Firebase DebugView /
  GA4 `traffic_type=internal`，或建 debug build 專用的 GA4 property），
  讓生產 property 只收真實用戶
- [ ] T2: 在 GA4 建「排除內部流量」的資料篩選器並確認生效
- [ ] T3: 生效後回頭重跑一次留存數字，重新判定 F13 的 D1/D7 是否真的是 0%

## F27: 結構化內容改用 JSON ＋ 程式驗證格式

- 狀態: 待辦
- 動機：`BACKLOG.md`、`ISSUES.md`、`marketing/content-calendar/_reels-place-calendar.md`
  這類「AI 產生、程式解析、人閱讀」三用的檔案目前是自由格式 markdown，
  沒有任何機制保證欄位齊全或形狀一致，實際已經出事——
  - 2026-07-27：dashboard 把 calendar 的「開場 hook 指定」表誤收為排程列
    （兩張表都是「日期＋三欄」，regex 無從區分），選點列表出現重複日期
    且欄位錯位。修法只能靠「段落標題必須是 `## Week N`」這種脆弱約定。
  - 同日：BACKLOG 51 個已完成 task 有 14 個沒有完成日期，且格式三種
    並存（括號內／敘述中／子項），只能人工回填。
  - `SCHEDULE.md` 已在檔頭寫「格式勿改：三個 `## ` 區段、各一張三欄表」——
    等於用註解代替驗證，仍然是壞了才知道。
- 目標：讓 AI 產生完之後**可以用程式驗證格式**，而不是等下游解析爆掉。
- [ ] T1: 盤點要納管的檔案與各自的欄位（BACKLOG / ISSUES / reels calendar
  / SCHEDULE），確認哪些欄位是必填、哪些有列舉值（如 feature 狀態、
  景點類型、checkpoint）
- [ ] T2: 為每個檔定 JSON Schema（draft 2020-12），列舉值直接寫進 enum，
  日期用 `format: date` 收斂成 `YYYY-MM-DD`
- [ ] T3: 把現有內容遷移為 JSON（一次性轉檔，人工核對）
- [ ] T4: 寫驗證腳本（`uv run python -m tools.validate_content` 之類），
  接進 pre-commit hook 與 CI，schema 不過就擋
- [ ] T5: markdown 改由 JSON 渲染產生（人閱讀用），或改為 dashboard 直接
  讀 JSON、不再維護 markdown 版
- **待決策**：BACKLOG / ISSUES 目前是人與 AI 都會直接手改的檔案，改成 JSON
  後手改體驗會變差（沒有 diff 可讀性、容易漏逗號）。可能的折衷是「JSON 為
  單一事實來源 + 自動產生 markdown 檢視」，但要先確認手改流程能接受。
  T1 之前先決定這件事，否則會做出沒人願意用的格式。

## F28: 產品數據累積改存 Google Sheet

- 狀態: 待辦
- 目標 Sheet：https://docs.google.com/spreadsheets/d/1h4Bd8RWoh_UL3EA048GWSimyPExBEcCA3gYftwGQ-Js/edit?gid=134534190
- 現況：lorescape-metrics 累積到 `data/metrics/*.csv`（一來源一檔，
  **gitignored**），dashboard 的產品數據分頁直接讀這些 CSV。
- **這是把 2026-07-11 的決定改回去**（`d42b921d`：累積目的地從 Google Sheet
  改為 repo 內 CSV，同時刪掉 `scripts/metrics/sheets.py`、移除 dashboard 的
  google 依賴）。當時搬離 Sheet 的理由是「數據含營收、repo 為 public 不進
  版控」——但那個理由用 Sheet 同樣成立（Sheet 本來就不在 repo 裡），
  而 CSV 換來的代價是：**只存在本機、沒有備份、換機器就沒了、無法多處
  存取或分享**。
- [ ] T1: 取回 `SheetStore`（`git show d42b921d^:scripts/metrics/sheets.py`），
  接回 `report.py` / `store.py` / `stores.py`；`METRICS_SHEET_ID` 指向上方 Sheet
- [ ] T2: 把現有 `data/metrics/*.csv` 的歷史一次性匯入該 Sheet（逐分頁對應
  一個來源，注意 `ig_posts` 的複合 key `media_id+obs_date`、
  `ig_reels_insights` 的 `media_id+checkpoint`，重跑要能覆蓋不重複）
- [ ] T3: dashboard 產品數據改讀 Sheet（`dashboard/collectors/metrics.py`，
  需重新加回 google 依賴）
- [ ] T4: 決定 CSV 的去留——完全移除，或保留為本機快取（離線可看、
  Sheet 掛掉時仍能跑週報）。兩者都可，但要明確，避免兩份資料各自漂移
- [ ] T5: 同步文件與 skills：`lorescape-metrics`、`marketing-weekly-audit`、
  `marketing-monthly-audit`、`docs/init/metrics-setup.md`、`CLAUDE.md`
  的「data/metrics」說法
- 注意：`ig_reels_insights` 是唯一由 Claude 直接讀寫的來源（讀 IG App 截圖
  後寫入），改到 Sheet 後這個寫入路徑也要一併改，別留一個還在寫 CSV。

## F29: 落地頁 sitemap 收錄每日故事頁 (epic: E1)

- 狀態: 待辦
- 來源: 使用者詢問「landing page 有把每天產生的文章放進 sitemap 嗎」
  （2026-07-27），查證結論＝**沒有**
- 現況（2026-07-27 查證）:
  - `/[locale]/story/[date]` 頁面在 build 時由 `getPublishedStorySlugs()`
    （`landing/src/lib/dailyStory.ts`）從 Supabase `daily_stories` 撈出
    所有已發布日期靜態產生，metadata 設 `robots: index, follow`——
    這些頁本來就是要給搜尋引擎索引的
  - 但 `landing/src/app/sitemap.ts` 是同步函式，只列首頁（zh/en）、
    5 個手寫 `/place/[slug]` 景點頁與 legal 頁，完全沒引用 dailyStory
  - ⇒ 每日文章只能靠內外部連結被 Google 發現，sitemap 沒有幫忙
- [ ] T1: `sitemap.ts` 改 async，呼叫既有 `getPublishedStorySlugs()` 把
  每篇故事 URL（`/{locale}/story/{date}`）加進 sitemap；build 時本來就會
  連 Supabase，無新依賴。lastModified 可用 publish_date
- [ ] T2: 部署後驗證正式站 `sitemap.xml` 含 story URL，並在 GSC 觀察
  story 頁的收錄狀況（目前 story 頁是否已被索引，順便一併查）
- 註: story 頁只在 build 時產生（`dynamicParams = false`），新文章要等下次
  Deploy Landing 才會出現——sitemap 收錄節奏與頁面產生節奏一致，但代表
  「每日文章要進索引」隱含「landing 需要每日或定期重建部署」，是否排進
  例行由 F30 的定位研究一併決定

## F30: 四種內容素材定位研究與內容生成 skill 調整 (epic: E1)

- 狀態: 待辦
- 來源: 使用者要求（2026-07-27）
- 背景: 目前每日內容產線同時產出四種素材，但四者的定位（各自服務漏斗
  哪一段、目標受眾、成功指標）從未明確定義，內容生成邏輯也各自演化：
  1. **IG Reels**——每日故事影片（lorescape-daily-reel），觸及/獲客
  2. **IG carousel**——wander 風格圖組（lorescape-wander-carousel）
  3. **官網文章**——`/story/[date]` 每日故事頁（SEO 資產，配合 F29 進
     sitemap）＋ `/place/[slug]` 景點 SEO 頁（F9）
  4. **App 內文章**——每日精選故事（免費用戶可讀，留存/習慣養成迴路，
     見 F13 T2）
- [ ] T1: 研究並定義四種素材的定位——各自在漏斗的位置（觸及/導流/轉換/
  留存）、目標受眾與情境、成功指標（對齊既有 metrics：略過率、
  profile_views、GSC 曝光、D1 留存…）、彼此的分工與重複。產出定位文件
  （建議放 MARKETING.md 或 marketing/ 下獨立檔）
- [ ] T2: 依定位盤點內容生成的落差——同一份 daily story 目前如何派生成
  四種素材、哪些素材該有不同的寫法/長度/hook 策略（例：Reels 重前三秒
  hook（F21）、官網文章重搜尋意圖與關鍵字、App 內文章重完讀與隔日回訪）
- [ ] T3: 依 T2 結論調整內容生成 skills（lorescape-manual-daily-story、
  lorescape-daily-reel、lorescape-wander-carousel、story_prompt 等），
  讓各素材的生成指引明確對齊自己的定位，而非共用同一套文案邏輯

## F31: 暫時移除付費牆（App 全面免費）

2026-08-05 決策：暫時全面免費，訂閱不再擋任何功能。詳見
`docs/adr/0006-temporarily-remove-paywall.md`——含刻意保留的死碼清單
（subscription / usage feature、RevenueCat 整合、Supabase 表、商店端商品），
**之後調整付費模式時要先讀該 ADR 盤點現狀**。

- [x] T1: backend 移除 /narration 402 訂閱檢查（2026-08-05）
- [x] T2: App 移除升級 banner、paywall 導向與 /subscription 路由（2026-08-05）
- [x] T3: 落地頁移除定價區塊（2026-08-05）
- [ ] T4: 部署後才對使用者生效——backend（Deploy Backend workflow）、落地頁
  （Deploy Landing workflow）、App 需出新版送審（見「待部署」段）
