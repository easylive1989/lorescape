# Story 工作台（/editor）設計

日期：2026-08-09
狀態：已與使用者確認設計方向（本檔為書面 spec，待使用者審閱）

## 背景與目標

沉浸式故事站（`story/`）已上線第一部劇本《千日之後》，之後維持一週一部。
目前產完劇本與美術後，任何調整（文字、分支、部件位置、背景圖）都要改
JSON 或重跑合成腳本。目標是提供一個本地工作台，讓使用者在瀏覽器裡：

1. 編輯文本：段落、選項文字、結局標題與文案、intro、標題、catalog blurb。
2. 編輯順序與結構：段落排序、節點增刪、分支指向（視覺化節點圖）。
3. 編輯角色骨骼與站位：各部件位置縮放（每角色一份、全場景生效）、
   每節點 cast 的 left/center/right 與 talking。
4. 指定美術素材：每節點背景圖從既有 assets 挑選或上傳新檔；角色部件換檔。

同時，Claude 直接改動磁碟上的內容檔時，工作台必須即時反映（反向亦然）。

## 已確認的關鍵決策

| 決策點 | 結論 |
|---|---|
| 骨骼資料 | 改資料驅動：部件圖回緊裁小圖 + 新增 `layout.json`，播放器執行時定位（放棄「烤進 PNG」） |
| 形態 | story 專案內建 dev-only 路由 `/editor`，預覽直接用真播放器元件；不進 production bundle |
| 儲存模式 | 即時自動存（debounce 寫回磁碟）；磁碟是唯一真相；衝突 last-write-wins + 畫面提示 |
| 骨骼粒度 | 每角色一份，全場景生效（不做 per-node 覆寫） |
| 結構編輯 | 視覺化節點圖（React Flow / @xyflow/react），拉線改指向 |
| 素材來源 | 既有檔挑選 + 上傳新檔（伺服端自動規格化） |

## 架構

```
story/
├── vite.config.ts            # + editorApiPlugin()（dev only）
├── plugins/editor-api/       # Vite plugin：讀寫 API + file watcher + SSE
├── src/
│   ├── editor/               # /editor 路由（DEV 守衛 + lazy import）
│   │   ├── EditorPage.tsx    # 三欄框架
│   │   ├── panels/           # 節點導覽、屬性面板、素材選擇器
│   │   ├── stage/            # 舞台預覽（重用播放器元件）+ 骨骼拖拉
│   │   ├── graph/            # React Flow 節點圖
│   │   └── api.ts            # 前端 API client + SSE 訂閱
│   ├── engine/schema.ts      # + layout.json schema 與驗證
│   └── components/CharacterSprite.tsx  # 改讀 layout 定位
└── public/content/
    ├── index.json            # catalog（自 src/data/catalog.ts 遷入）
    └── <slug>/
        ├── script.json
        ├── art.json
        ├── layout.json       # 新增：骨骼定位資料
        └── assets/
```

### Vite plugin（editor-api）

- `configureServer` 掛 middleware，僅存在於 dev server：
  - `GET /__editor/content/<slug>/<file>.json`：讀 JSON。
  - `PUT /__editor/content/<slug>/<file>.json`：Schema 驗證通過才寫入；
    驗證失敗回 400 與錯誤明細（絕不寫壞資料）。
  - `POST /__editor/content/<slug>/assets`：上傳圖檔。背景自動 cover 裁
    900×1600；部件收去背 PNG（自動去背為後續項目）。壓縮沿用 pngquant
    （若本機無 pngquant 則跳過壓縮並回報）。
  - `GET /__editor/events`：SSE。plugin 以 chokidar watch
    `public/content/**`，變更時推 `{ type, slug, file }`。
- 寫入時同步更新記憶中的 mtime，避免自己的寫入觸發的 watch 事件被誤判
  為外部變更（自迴圈）。

### 即時更新（雙向）

- 工作台編輯 → debounce（500ms）PUT → 磁碟。
- Claude / 其他程序改磁碟 → chokidar → SSE → 工作台重抓該檔：
  - 目前未編輯的欄位：直接套用新值。
  - 正在編輯的欄位與外部值衝突：外部值覆蓋（last-write-wins），
    顯著 toast 提示「內容已被外部更新」。
- 素材圖以 `?mtime=<ts>` 破快取即時換圖。
- 需停用 Vite 對 `public/content/**` 的預設 full-reload（改由 SSE 精準
  更新，避免編輯器整頁重載遺失狀態）；`/play` 頁在 dev 的行為不變。

## 骨骼資料化（前置改造）

### layout.json 格式

```json
{
  "canvas": { "width": 1024, "height": 1536 },
  "characters": {
    "anne": {
      "head":     { "cx": 0.505, "top": 0.030, "height": 0.225 },
      "torso":    { "cx": 0.500, "top": 0.195, "height": 0.780 },
      "leftArm":  { "cx": 0.325, "top": 0.228, "height": 0.350 },
      "rightArm": { "cx": 0.640, "top": 0.215, "height": 0.350 }
    }
  }
}
```

- `cx`/`top`/`height` 為基準畫布比例；寬度由部件圖原始長寬比推得
  （與現行合成腳本同一套數學）。
- zod schema：四部件必備、數值範圍檢查；`validateLayout` 併入載入流程，
  缺 `layout.json` 或缺角色時報明確錯誤（不做隱性 fallback）。

### 播放器改動

- `CharacterSprite` 接收該角色 layout，改為：sprite 容器內每部件
  `position:absolute`，以 `left/top/width/height` 百分比呈現（等價於
  現行烤圖數學）；動畫（breathe/sway/nod）與 transform-origin 邏輯不變，
  origin 改依 layout 推算（頸線 = head.top + 頭高比例、肩線 = arm.top）。
- 雙人縮放與靠邊規則（character.css 的 :has 規則）不變。
- 《千日之後》部件圖以暫存區保留的緊裁原圖重新放回 assets（不需重新
  生成），layout.json 以現行合成參數起始。
- `CONTENT_VERSION` bump。

### catalog 遷移

- `src/data/catalog.ts` 資料移至 `public/content/index.json`，HomePage 改
  fetch；工作台可編輯 blurb 等欄位。之後週更上新故事不再改程式碼。

## 工作台 UI

三欄式（桌機瀏覽器使用，不做行動版）：

1. **左欄：故事與節點導覽**
   - 故事切換（讀 index.json）。
   - 節點清單（顯示 id 與首段摘要），選取後中欄／右欄同步；
     清單支援拖拉排序（影響 script.json 內 nodes 陣列順序）。
   - 「結構」分頁切到節點圖。
2. **中欄：舞台預覽（WYSIWYG）**
   - 以真播放器元件渲染目前節點：背景 + cast sprites + 字卡/選項；
     段落切換器預覽每段。
   - 骨骼模式：點選角色後各部件顯示外框，拖拉移動（`cx`/`top`）、
     角落手柄或滾輪縮放（`height`）；數值同步顯示於右欄可鍵入微調。
   - 手機外框（480px 寬）呈現，貼近實機。
3. **右欄：屬性面板**（隨選取對象切換）
   - 節點：背景圖選擇器（assets 縮圖 + 上傳）、cast 編輯
     （角色/站位/talking）、段落編輯（textarea 清單、增刪、拖拉）、
     選項編輯（文字 + 指向下拉）、ending 標題與文案。
   - 故事：標題、intro、catalog blurb。
   - 角色：部件數值、部件圖換檔。
4. **節點圖（React Flow）**
   - 節點卡片顯示 id 與摘要；邊 = next / 各選項 / ending 標記。
   - 拉線改指向、新增節點（自動接入）、刪除節點（斷鏈警示）。
   - schema 驗證即時跑：斷鏈、孤兒節點、無終點路徑標紅，
     驗證不過的變更不寫入磁碟。

## 排除範圍（YAGNI）

- 音訊（BGM/SFX）編輯。
- 新故事 scaffold（產故事仍由 Claude 產線負責）。
- 多人協作、鎖定、編輯歷史／undo（靠 git 版本控制）。
- 自動去背上傳部件（第一版收已去背 PNG）。
- 部署／行動版工作台（僅本地 dev）。

## 測試

- **engine/schema**：layout schema 驗證、缺件錯誤（vitest）。
- **CharacterSprite**：依 layout 產生的 style 定位正確（元件測試）。
- **plugin**：讀寫/驗證/上傳規格化抽純函式測（node 環境 vitest），
  驗證失敗不落盤。
- **editor UI**：關鍵互動元件測試——自動存 debounce、SSE 更新合併與
  衝突提示、節點圖驗證擋存。
- **遷移驗收**：`/play` 視覺與現況一致（同參數等價）；工作台拖動安妮
  頭部後，`/play` 重整同步；`npm run build` 產物不含 editor 與
  @xyflow（bundle 檢查）。

## 風險

- Vite 預設 publicDir full-reload 與 SSE 精準更新的取捨需在 plugin 內
  處理乾淨，避免編輯狀態遺失（實作時以 `server.watcher` 設定驗證）。
- React Flow 為新依賴（dev 路由 lazy chunk）；需確認 build 排除乾淨。
- 骨骼從烤圖改執行時定位是全站視覺回歸點，遷移後需逐場景比對。
