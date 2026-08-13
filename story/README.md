# story — 沉浸式互動劇本引擎

`story/` 是獨立的 Vite + React SPA：播放多結局互動劇本（例如《千日之後》），
並內建本機開發用的視覺化劇本工作台。與 `frontend/`（Flutter App 本體）、
`backend/`（narration API）互不依賴，是獨立產線的一環——目前用於每日故事的
沉浸式劇本 demo，資料以純檔案（`public/content/<slug>/`）為準，未接
Supabase。

## 執行方式

```bash
npm install
npm run dev     # 啟動 Vite dev server（含編輯器 API middleware）
npm run build   # tsc -b && vite build，production build
npm test        # vitest run
```

## 路由

| 路徑 | 內容 |
|---|---|
| `/` | 劇本選單首頁 |
| `/play/:slug` | 播放頁——讀取 `public/content/<slug>/{script,art}.json` 播放劇本 |
| `/editor` | **工作台**（僅 `npm run dev` 開發模式，`import.meta.env.DEV` 守衛；不進 production bundle） |

## 資料結構

一個劇本 = `public/content/<slug>/` 下兩份檔案：

- `script.json`：節點（段落、選項、cast 站位、背景、結局）、
  角色定義（`id`/`name`/`image`：單張去背全身圖路徑）、`startNode`。
  段落是 `{ text, speaker? }`：`speaker` 是角色 id 時，對話泡泡從該角色頭上
  出來、其他人壓暗；省略即旁白，走畫面下方的框。`speaker` 必須在該節點的
  `cast` 內（`validateScript` 會擋），畫外音一律用旁白寫。
  段落與選項都可以帶 `when`（`flag` 或 `!flag`）決定要不要出現；選項可以帶
  `set: string[]`，選到時把 flag 記進進度。`validateScript` 會擋：`when` 參照
  沒有任何選項 `set` 過的 flag、節點沒有任何無條件段落、有選項的節點無條件
  選項少於兩個。flag 只增不減，存進 localStorage 的進度會帶著它。
- `art.json`：素材生成用的風格與角色描述設定。

`public/content/index.json` 是劇本 catalog（slug/title/place/blurb），
`/` 首頁與 `/editor` 的劇本下拉選單都讀這份。

## 工作台（`/editor`）

本機開發用的視覺化劇本編輯器，透過 Vite plugin（`plugins/editor-api/`）
掛一組 `/__editor/*` API middleware，直接讀寫 `public/content/` 下的檔案。

### 啟動

```bash
cd story
npm run dev
# 瀏覽器開啟終端機顯示的網址 + /editor
```

左欄選擇劇本後，三欄式版面：左欄「節點」清單（可拖曳排序、上下移）／
「結構」節點圖分頁；中欄舞台預覽（WYSIWYG，即時反映右欄的編輯）；右欄
視左欄選取內容切換「故事設定」或「節點屬性」面板。

### 能編什麼

- **文本**：標題、地點、intro、catalog blurb、各節點段落文字（可新增／
  刪除／上下移排序）。
- **順序**：節點清單拖曳排序、單一節點的段落排序。
- **結構圖**（左欄「結構」分頁，React Flow）：節點卡片可「在後面插入
  節點」「刪除節點」；拖曳連線可把某個 `next`／選項改指向另一個既有節點
  （存檔前會先跑 `validateScript`，通過才送出）。刪除仍被其他節點指向的
  節點、或刪除 `startNode` 會被擋下並跳出可關閉的錯誤 toast，不會寫檔。
- **角色站位／說話者**：每個角色是單張去背全身圖（`characters/<id>/full.png`），
  不再有骨骼／部件編輯；節點屬性面板可調整每個 cast 成員的站位（左／中／
  右），並在每個段落上選擇說話者（旁白或台上任一角色）。站位的視覺效果交由
  `character.css` 的 `.sprite--left/center/right` 定位與縮放。刪除或抽換 cast
  成員時，指向他的段落 `speaker` 會自動清空／改指，避免存檔被驗證擋下。
- **flag 與顯示條件**：選項可設定 `set`（逗號分隔），段落與選項都可挑
  「顯示條件」。中欄預覽下方有一排 flag 開關，用來切換預覽的 flag 狀態。
- **背景／角色圖素材**：節點屬性面板「背景」與故事設定面板「角色圖」都
  有「更換」按鈕，展開素材選圖器（縮圖列表 + 上傳）。
- **素材上傳規格化**：背景（`scenes/`）上傳的任意比例圖片，前端用
  canvas 依「置中裁切」（cover）規則統一裁成 900×1600 再送出；角色圖
  （`characters/<id>/`）上傳則原檔直傳、保留原始比例。

### 磁碟即真相與 SSE 行為

工作台不維護資料庫或額外狀態——`public/content/` 底下的檔案本身就是唯一
事實來源：

- 編輯後 500ms debounce，透過 `PUT /__editor/content/<slug>/<file>` 直接
  覆寫對應 JSON 檔（樂觀 UI，PUT 失敗時錯誤訊息顯示、不覆蓋已編輯的畫面
  狀態）。
- Vite plugin 用 `chokidar` 監看 `public/content/`，任何變動（含外部工具
  或人工直接改檔，例如 Claude 直接編輯 `script.json`）都會經
  `GET /__editor/events`（SSE）廣播給所有開著的工作台分頁，分頁收到後會
  重新 GET 該檔並更新畫面——**雙向同步**，不限工作台自己的寫入。
- 自寫入抑制：PUT 觸發的檔案變更會在 1500ms 內被同一個 plugin 實例的
  `SelfWriteGuard` 識別為自己剛寫的，不會重複廣播回同一個工作台造成
  迴響。
- 外部更新覆蓋本地畫面時（last-write-wins），畫面上方會跳出顯著提示
  「內容已被外部更新：`<檔名>`」（`role="status"`），約 4 秒後自動消失；
  同一份檔案在這段時間內再次被外部改動，計時會重新開始。

### pngquant（選配）

背景圖上傳後端會嘗試呼叫本機 `pngquant` 壓縮（`--quality=70-92`）。若機
器沒裝 `pngquant`，壓縮呼叫會靜默失敗並回傳「skipped」，**不會**擋住上
傳流程——裝了就享受較小檔案，沒裝也完全能用。

### 已知偏差

- **dev 模式 `/play` 對內容變更不會自動重整**：`vite.config.ts` 把
  `public/content/**` 加進 `server.watch.ignored`，避免 Vite 的
  full-reload 洗掉工作台編輯狀態；副作用是在編輯器裡改了內容後，開著的
  `/play` 分頁不會自動反映，需要手動重新整理分頁才看得到最新版本。

## 測試

```bash
npm test        # vitest run，全專案含 plugins/editor-api 與 src/editor
```

`test/` 與 `src/` 結構相對應；`plugins/editor-api/*.test.ts` 涵蓋 API 純
函式邏輯，SSE／chokidar 的即時行為以手動驗證為主（見
`.superpowers/sdd/2026-08-09-story-workbench/task-*-report.md`）。
