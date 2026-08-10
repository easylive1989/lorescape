# ADR 0008：story 角色改用單張全身圖（取代四部件紙娃娃）

日期：2026-08-10
狀態：已採用（取代 ADR 0007）

## 背景

ADR 0007 把四部件紙娃娃的定位資料化（layout.json + 執行時定位），但部件
拆開後有兩個代價：

1. 部件各自動畫（呼吸/擺臂/點頭）會拉開緊裁圖之間的接縫，動起來破圖；
   先以「移除部件動畫、整體微呼吸」止血，分層動畫名存實亡。
2. 工作台需要骨骼編輯器維護各部件相對位置，維護成本高於價值——
   對「一週一部劇本」的節奏而言，角色只要站對位置就夠了。

## 決策

- 角色改為**單張去背全身圖**：`script.json` 的 `characters[].image`
  （如 `characters/anne/full.png`），由生成的洋紅底全身參考圖
  （`_reference.png` 保留原檔）經 chroma-key 去背而來。
- `CharacterSprite` 渲染單一 `<img>`（`object-fit: contain`、貼底置中）；
  站位仍走 cast 的 left/center/right 與雙人縮放規則。
- **layout.json 廢除**：schema、loader、editor-api 驗證、產線
  （layout_migrate、tighten CLI、ensure_layout_entry）一併移除。
- 工作台移除骨骼編輯；角色相關編輯只剩站位（NodePanel 的 cast）與
  整張角色圖換檔（StoryPanel）。
- `CONTENT_VERSION` bump 為 '5'（部件 → 單圖為不相容內容形狀變更）。

## 後果

- 破圖問題從根本消失；動畫維持進場 + 整體微呼吸。
- 產線簡化：每角色一次生成、一次去背；週更成本下降。
- 放棄分層動畫的表現力。若日後要恢復紙娃娃（BACKLOG F19），素材需
  加重疊裕度並恢復 layout 資料層——屆時另立 ADR。
