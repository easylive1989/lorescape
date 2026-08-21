# Lorescape — Marketing Config

## Product
- **Name:** Lorescape
- **Type:** Mobile app (iOS + Android), freemium with subscription
- **One-liner:** AI 隨行的旅行說書人 — 走到任何景點，即時生成一段以史實為本的真實故事，再以語音娓娓道來。
- **URL:** https://lorescape.app
- **App Store:** https://apps.apple.com/tw/app/%E8%AE%80%E6%99%AF/id6751904060
- **Google Play:** https://play.google.com/store/apps/details?id=com.paulchwu.instantexplore

## Audience
- **ICP:** 25–45 歲的深度知性旅人。自由行為主，不滿足於走馬看花，渴望了解城市靈魂與景點背後的文化脈絡。以台灣用戶為核心，兼顧全球華語與英語旅人。
- **Pain:** 站在古蹟或景點前，查 Google 只有條目式資訊，找導覽團又受限於路線和時間，無法自由深入探索。
- **Alternative:** Google 搜索 + Wikipedia 自行查閱、傳統語音導覽（景點附設）、Rick Steves 或 Google Maps 語音導覽。

## Value Proposition
- **Primary:** 任何景點，一鍵生成有溫度的真實故事，並以純淨語音朗讀——讓你抬頭看世界，耳邊有故事。
- **Differentiators:**
  - 故事以 Wikipedia 為事實依據（grounding），不是 AI 杜撰
  - 提供 2–3 個故事角度讓用戶自選，而非單一制式內容
  - 語音逐句同步高亮，邊聽邊看
  - 聽完的故事自動成冊為旅程手記，依旅程歸檔、沿時間軸重溫
- **不再提的功能：** App 端的「每日故事」已於 2026-08-19 隨 v3 改版移除（ADR
  0010），對外文案不要再拿它當賣點；每日故事產線本身仍在跑，但只服務 IG 等社群
  通路。旅程手記的 PDF 匯出已於 2026-08-21 整包移除（`features/export/` 連同 pdf
  / printing 依賴一起刪），同樣不要再提。
  「文化足跡日誌／旅程手記」本身在 2026-08-11 到 08-19 之間曾以 `kBookshelfEnabled`
  隱藏，該旗標已移除、書架六條路由常駐註冊，功能現為正式可用，文案可以放心提。
- **Proof points:** 早期階段（App 2026-06 上線），暫不公開量化數字；行銷以上述質化差異化為主，待數據有意義後再補（下載量、故事生成次數、訂閱轉換率）
- **Source notes:** 所有功能描述來自 README.md 與 landing page copy（landing/src/i18n/）

## Revenue Model
- **Pricing:** Freemium + 訂閱制
- **Key plans:**
  - Free：基本探索功能
  - Premium Weekly：每週訂閱（`$rc_weekly`）— NT$33／週
  - Premium Monthly：每月訂閱（`$rc_monthly`）— NT$150／月（≈ USD 4.99）
  - Premium Yearly：每年訂閱（`$rc_annual`）— NT$660／年
- **Platform:** RevenueCat（統一管理 App Store + Google Play 訂閱）
- **Price source:** Google Play Console（台灣定價，2026-06-30 查）；iOS 平行定價，實際金額由各商店本地化決定

## Brand Voice
- **Tone:** 沉靜、知性、有溫度。像一位博學的旅伴在耳邊輕聲講故事，不像觀光手冊，也不像教科書。
- **Do:**
  1. 用第二人稱「你」直接對話，製造親近感
  2. 以情境開場（「當你站在宏偉的古蹟前…」），觸發情感共鳴
  3. 強調「史實為本」與「有來源」，建立信任感
- **Don't:**
  1. 不堆砌條目式資訊或功能清單
  2. 不用誇張行銷語氣（「最強！最好！革命性！」）
  3. 不過度使用 emoji，保持克制感（每篇最多 3 個）

## Current Channels
- **Active:**
  - 官網（lorescape.app）— Next.js 雙語（zh/en）落地頁，含 App Store / Google Play 按鈕
  - Instagram — 已發佈品牌啟動貼文，規劃每週一則景點故事系列
  - App Store（iOS）
  - Google Play（Android）
- **Planned:** YouTube Shorts、SEO 部落格（lorescape.app/blog）、TikTok 短影音、旅遊社群 KOL 合作

## Competitive Landscape
- **Direct competitors:**
  - Google Maps 語音導覽（功能整合在地圖 App，但故事深度不足）
  - Rick Steves Audio Tours（高品質但僅限特定歐洲城市，無 AI 即時生成）
  - 景點附設語音導覽（受限景點範圍，無自由探索）
- **Indirect competitors:**
  - Wikipedia / Google 搜尋（文字為主，無故事化敘事與語音）
  - Podcast 旅遊節目（非即時、非定位觸發）
- **Positioning:** Lorescape 是唯一能在「任何地點、任何時間」即時生成 Wikipedia 事實驗證故事並語音朗讀的 AI 旅行說書人，填補「深度知性旅人在現場的知識空白」。

## Brand Positioning（品牌定位框架）
撰寫定位 / 文案 / tagline 時的準則（原 marketing-brand skill 收攏於此；文案品質檢查走 `marketing-gate`）。

- **White space（可獨佔的定位）:** 任何地點 × 任何時間 × Wikipedia 事實驗證 × AI 故事 × 語音——競品各缺一塊：Google Maps 語音導覽故事淺、Rick Steves 靜態且限歐洲、景點附設導覽鎖定點、Wikipedia/搜尋無敘事無語音、旅遊 podcast 非即時非定位觸發。
- **定位陳述模板:** For〔深度知性旅人〕who〔站在景點前只查得到條目式資訊〕，Lorescape is the〔AI 旅行說書人〕that〔即時生成有溫度的史實故事並語音朗讀〕because〔以 Wikipedia 為事實依據、提供 2–3 個故事角度〕。
- **差異化維度（對比競品時用）:** 覆蓋範圍、AI 即時生成、Wikipedia 事實驗證、語音朗讀、多故事角度、定位觸發、訂閱訪問。
- **Tagline 限制:** 每則 < 8 字/words；zh-TW 與 English 並行；貼合「沉靜、知性、有溫度」語氣；禁誇張級（「最強」「最好」「革命性」）；主張須能由本檔或 codebase 佐證。
