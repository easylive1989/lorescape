# ADR 0007：story 紙娃娃定位改為資料驅動（layout.json）

日期：2026-08-10
狀態：已採用

## 背景

沉浸式故事站（`story/`）的角色以四部件紙娃娃（head/torso/leftArm/rightArm）
呈現。第一版把各部件的位置縮放「烤進 PNG 像素」：合成腳本將緊裁部件圖
依參數貼回與 reference 同尺寸（1024×1536）的全畫布，播放器以四層 100%
疊放還原。參數只存在合成腳本中，調整任何部件都要重跑合成、重新部署圖檔，
工作台（/editor）也無從編輯。

## 決策

1. 部件圖回到**緊裁小圖**（alpha bbox crop）。
2. 新增 `content/<slug>/layout.json`：每角色每部件存
   `{ cx, top, height }`（相對 1024×1536 基準畫布的比例）；zod schema
   與 `validateLayout(data, script)`（缺角色即報錯）在
   `story/src/engine/schema.ts`。
3. `CharacterSprite` 執行時依 layout 以 inline style 百分比定位
   （`left: cx*100%`、`top: top*100%`、`height: height*100%`、
   `translate: -50% 0`，寬度由圖片長寬比自算）；`.sprite` 容器固定
   `aspect-ratio: 2 / 3` 維持基準畫布比例。
4. 既有故事的遷移為零誤差：對 registered PNG 的 alpha bbox 反推參數
   （`cx=(left+w/2)/1024` 等），即烤圖當下的位置本身
   （`scripts/story_assets/layout_migrate.py`，CLI `tighten --slug`）。
5. 角色生成產線（`characters.py`）在產出新角色時寫入預設 layout 條目，
   細調交給工作台的骨骼編輯。

## 後果

- 工作台拖拉部件即改 layout.json，`/play` 重整即生效——所見即線上所見。
- 素材與定位解耦：換部件圖不必重烤、調位置不必重生圖。
- `/content/**` 快取 1 小時且素材更新沿用同路徑，故凡「部署後客戶端拿
  新舊混合會壞版面」的內容形狀變更（如本次緊裁遷移），必須 bump
  `story/src/data/loadScript.ts` 的 `CONTENT_VERSION`（本次 3→4）。
- 播放器多一次 layout.json 請求與驗證；載入失敗走既有錯誤/重試 UI。
