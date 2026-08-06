# 沉浸式歷史故事體驗 Demo（第一階段）設計

日期：2026-08-06
狀態：已與使用者逐段確認

## 背景與目標

App 走向調整：不再做 AI 景點導覽，轉向「深入的故事體驗」——以第二人稱讓使
用者帶入一個角色，搭配場景圖與可動人物，體驗一段真實歷史故事。

第一階段不動 App 本體，先做一個獨立網頁 demo 驗證方向：

1. 從過往每日故事（Supabase `daily_stories`）挑選台灣人熟悉度高的
   **國外景點**，找 5 個候選給使用者選定 1 個。
2. 為選定故事寫劇本（角色、場景、分支）。
3. 用 Gemini 生成場景圖與可動角色立繪。
4. 做成獨立小站上線。
5. 在 IG 邀請測試者遊玩。
6. 以內建問卷 + 行為事件收集 feedback，判斷方向是否值得投入。

之後預計**每週推出一個劇本**，因此引擎與產線必須模板化：上新劇本只需
「一份劇本資料 + 一包素材」，不改程式。

## 已確認的產品決策

| 決策點 | 結論 |
|---|---|
| 互動形式 | 有選擇的分支故事（interactive fiction） |
| 角色視角 | 虛構小人物（學徒、僕役、旅人…），穿梭於真實歷史事件，第二人稱「你」 |
| 主角現身 | 不現身——畫面只有 NPC 與場景，「你」的視角就是鏡頭 |
| 單劇本規模 | 輕量：5–10 分鐘、約 8–12 節點、2–3 個選擇點、2 種結局、5–8 張場景圖、1–3 個 NPC |
| 視覺風格 | 角色與場景皆為 cel-shaded 插畫風（使用者提供角色參考圖：正面全身、乾淨深色底） |
| 人物動態 | 骨架式概念、以「程式化紙娃娃」實作：部件拆分 + CSS 動畫 |
| 聲音 | BGM + 音效，無語音旁白 |
| 部署 | 獨立小站（與 landing 解耦），繁中 only |
| Feedback | 體驗後內建短問卷 + 匿名行為事件，存 Supabase |
| 地點挑選 | 台灣人熟悉度高的國外景點（京都、羅馬…），從過往 daily_stories 篩選 |

## 方案選擇

評估三案後採 **方案 A：自製輕量引擎**（React + JSON 劇本 + CSS 紙娃娃）。

- 捨 ink.js（方案 B）：2–3 個選擇點的分支規模用不到敘事 DSL，多一道
  劇本轉語法工序不利週更。
- 捨 PixiJS（方案 C）：視覺上限高但成本兩三倍；第一階段驗證的是「故事
  體驗方向」而非動畫技術。方向確立後可升級，劇本 JSON 格式可沿用。

## 架構

### 專案與部署

- 頂層新增 `story/`：Vite + React + TypeScript 靜態站，與 landing 完全
  解耦。
- 部署：Firebase Hosting 新增第二個 site，綁 `story.lorescape.app`；
  新增 GitHub Actions `deploy-story.yml`（手動觸發，比照
  `deploy-landing.yml`）。
- 路由：`/`（劇本選單）與 `/play/<slug>`（體驗本體）。免登入。

### 劇本內容結構

```
story/content/<slug>/
  script.json      # 劇本資料
  assets/
    scenes/        # 場景圖
    characters/    # 角色部件（去背 PNG）
    audio/         # BGM 與音效
```

### script.json 核心概念

- `characters`：NPC 定義（id、名字、部件圖清單、預設站位）。
- `nodes`：場景節點流程圖。每節點含：背景圖、出場角色與動作指令
  （進場／退場／說話／情緒）、第二人稱敘事文字（多段）、BGM／音效指令，
  結尾為 `next`（線性推進）或 `choices`（2–3 選項各指向不同節點）。
- `endings`：結局節點（帶 ending id，供事件記錄玩家走到哪個結局）。

引擎載入時做 JSON schema 驗證，產線出錯早發現。

## 每週素材產線

工具放 `scripts/`（沿用現有 uv Python 專案）新增 story 素材指令：

1. **選點**：從 `daily_stories` 撈候選（熟悉度、故事長度、戲劇性），
   人工挑定。
2. **劇本**：與 Claude 協作產出 `script.json` 初稿 → 人工審稿。
3. **生圖**（腳本讀 script.json 素材清單，呼叫 Gemini image model，
   `GEMINI_API_KEY` 已在 `.env` 備妥）：
   - 角色：生成全身立繪（鎖定參考圖風格）→ 以其為 reference 生成部件
     攤平圖（頭、軀幹、左右臂）→ 程式去背切件。每角色只生一次部件，
     跨場景重用，一致性天然解決。
   - 場景：cel-shaded 插畫風（與角色一致，光影氛圍加重）。
   - 人工過目，不滿意單張重生成。
4. **BGM／音效**：免費授權音庫人工挑選（比照 `marketing/sound/`）。
5. **驗收**：schema 驗證 + 素材齊備檢查，通過才 commit。

## 前端體驗

- 直式手機優先（IG 導流），桌機置中窄欄。
- 畫面：全螢幕場景圖為底、NPC 紙娃娃立繪疊於其上、底部第二人稱敘事
  文字卡；tap 逐段推進，選擇點浮出選項按鈕。
- 紙娃娃動效（CSS／Framer Motion）：待機呼吸（軀幹微縮放、手臂微擺）、
  說話頭部微動、進退場 fade + slide。目標「人物是活的」，不做骨架 IK。
- 場景 cross-fade；BGM 依節點指令淡入淡出；入口「開始體驗」按鈕同時
  解鎖行動瀏覽器音訊。
- 進度存 localStorage，中斷可續玩。
- 結尾：結局頁 → 內建問卷 → 感謝頁附 IG 追蹤連結。

## 數據與問卷（Supabase）

- `story_events`：`session_id`（前端匿名 UUID）、`story_slug`、
  `event_type`（`start` / `node_enter` / `choice_made` /
  `ending_reached` / `survey_submitted`）、`payload` jsonb、
  `created_at`。流失點以 session 最後一筆 `node_enter` 推算。
- `story_surveys`：`session_id`、`story_slug`、`answers` jsonb、
  `created_at`。
- RLS：兩表皆 anon insert-only（只能寫不能讀）。
- 寫入 fire-and-forget，失敗不影響體驗。

問卷（3 必答 + 2 選答）：

1. 「你有多投入這個故事？」1–5
2. 「會想每週體驗一個新的歷史故事嗎？」會／可能／不會
3. 「印象最深或最出戲的地方？」開放題
4. （選）「如果未來部分劇本收費，你的意願？」會付／看價格／不會
5. （選）「願意接受簡短訪談的話，留下 IG 帳號」

## IG 邀請與成敗判準

- 用現有 Lorescape IG 帳號發貼文 + 限動（連結貼紙）邀請，內容走
  marketing gate 流程。
- 判準（可調）：≥30 人開始；完成率 ≥50%；沉浸感平均 ≥4.0；
  「想每週玩：會」≥40%。達標投入第二階段；未達則看流失點與開放題
  決定調整或收手。

## 測試與錯誤處理

- 單元測試：分支流轉邏輯（reducer）、script.json schema 驗證。
- CI：素材齊備檢查。
- 上線前人工走完所有分支；劇本內容靠人工審稿。
- 素材預載下一節點；載入失敗顯示重試；音訊解鎖失敗則靜音繼續。

## 第一階段執行順序

1. 從 daily_stories 篩 5 個候選故事給使用者選定。
2. 劇本 script.json（含 schema 定義）。
3. Gemini 生圖產線腳本 + 素材產出。
4. `story/` 引擎實作 + Supabase migrations + 部署。
5. IG 邀請素材與發布。
6. 收 feedback、對照判準做 go/no-go。
