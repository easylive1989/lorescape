# story 引擎：人物對話與頭上對話泡泡

**日期**：2026-08-11
**範圍**：`story/`（Vite + React SPA，含播放頁與 `/editor` 工作台）與 `story/public/content/` 下的兩篇既有劇本

## 問題

目前劇本的每個節點是 `paragraphs: string[]`，全部走畫面下方的 `.text-card`。角色對白是用「」直接寫進旁白句子裡（例：`「八十一個。」她說。明天是節慶……`），畫面上看不出誰在說話。`cast[].talking` 雖然存在，但只是節點層級的旗標，`CharacterSprite` 掛出 `is-talking` class 之後沒有任何 CSS 使用它——實際上是死設定。

要做的是把「說話者」下放到每一段：說話者是角色時，對話泡泡從該角色頭上出來；沒有說話者（旁白）才用下方的框。

## 設計

### 1. 資料模型（`src/engine/schema.ts`）

段落從字串變成物件：

```ts
export const paragraphSchema = z.object({
  text: z.string().min(1),
  speaker: z.string().optional(),   // 角色 id；省略 = 旁白
})
export type Paragraph = z.infer<typeof paragraphSchema>
```

- `nodeSchema.paragraphs` 改為 `z.array(paragraphSchema).min(1)`
- `castMemberSchema` 移除 `talking` 欄位
- key 名維持 `paragraphs`、`PlayState.paragraphIndex` 也不改名，把改動限縮在功能本身

`validateScript` 新增一條規則：每段的 `speaker` 必須同時是已定義角色**且**在該節點的 `cast` 內。違反時丟出

```
節點 <nodeId> 第 <n> 段的說話者不在台上：<speakerId>
```

不在台上的人說話（門外的聲音、遠處的喊叫）一律用旁白寫，引擎不支援畫外音。

`src/engine/player.ts` 完全不動——`advance()` 只看 `paragraphs.length`，不看段落內容的形狀。

### 2. 泡泡元件（新檔 `src/components/SpeechBubble.tsx`）

```tsx
export function SpeechBubble({ name, text, position }: {
  name: string; text: string; position: 'left' | 'center' | 'right'
}) {
  return (
    <div className={`bubble bubble--${position}`} data-testid="speech-bubble">
      <span className="bubble__name">{name}</span>
      <p className="bubble__text">{text}</p>
    </div>
  )
}
```

視覺沿用現有 `.text-card` 的調性——`rgba(10, 10, 10, 0.72)` 深色半透明底、圓角、`#f5f5f5` 文字——只多兩樣：一行淡色小字的角色名，以及一個用 `::after` 的 border 三角形做的尖角，依站位靠泡泡的左／中／右側，指向該角色。

### 3. 泡泡定位（`src/styles/character.css`）

**限制**：「頭頂」的精確 y 座標程式拿不到。`.sprite` 是 `aspect-ratio: 2/3` 的容器、圖片 `object-fit: contain` 貼底置中，頭在圖裡的高度由構圖決定。可靠的錨點只有 sprite 容器的上緣。因為角色圖規格就是 1024×1536（正好 2:3），容器上緣 ≈ 圖片上緣 ≈ 頭頂附近，這個近似可用。

作法：

- `.scene` 加 `container-type: inline-size`，讓泡泡能用 `cqw` 換算 sprite 高度（sprite 高 = 寬 × 1.5，寬是 scene 寬的 72%／58%，故高 ≈ `108cqw`／`87cqw`）
- 泡泡**不放進 `.sprite`**：`.sprite` 有 `pointer-events: none`，且 breathe 動畫在寫 `scaleY`，泡泡放進去會跟著抖。改為 `.scene` 的直接子元素——同一段只有一個說話者，所以畫面上最多一個 `.bubble`，不需要 wrapper
- `bottom: calc(var(--sprite-h) - 4cqw)`；`--sprite-h` 由 `SceneView` 以 inline style 給 `108cqw`（cast 只有一人）或 `87cqw`（cast 兩人以上），對齊現有 `.sprite` 的 72%／58% 寬度規則
- `left/center/right` 沿用與 `.sprite--*` 相同的水平定位規則；`max-width: 78cqw`
- `z-index: 2`（高於 `.text-card` 的 1）

CSS 的具體數字是起點，實作時在 `npm run dev` 拿真實素材目測微調落點與尖角偏移。

### 4. 場景渲染（`SceneView.tsx`、`CharacterSprite.tsx`）

`SceneView` 取出當前段落後分支：

- **對白段**（`speaker` 有值）：渲染 `SpeechBubble`，**下方 `TextCard` 不渲染**
- **旁白段**：維持現行 `TextCard`，不渲染泡泡

非說話者掛 `is-dimmed` → `filter: brightness(0.6)`，加 `transition: filter .3s`。旁白段沒有說話者，全部不壓暗。`CharacterSprite` 的 `member.talking` 判斷與 `is-talking` class 一併移除。

**推進的點擊區從 `TextCard` 上移到 `.scene`**——對白段沒有下方框可點。`.scene` 的 `onClick` 只在 `status === 'playing'` 時呼叫 `onAdvance`；`choosing` 時不吃點擊，避免誤觸跳過選項。`TextCard` 不再需要 `onTap` prop，但保留 `cursor: pointer` 的視覺提示。

### 5. 編輯器（`NodePanel.tsx`、`useStory.ts`、`graphMath.ts`）

- 每段 textarea 上方加一個「說話者」下拉：選項為 `旁白` ＋ 該節點 `cast` 的角色
- 移除 cast 的 talking checkbox
- **一致性處理**：從 cast 移除某角色時，指向他的段落 `speaker` 自動清空。否則存檔會被第 1 節的新驗證規則擋下，使用者會卡住卻看不出原因
- 段落的新增／刪除／排序改為操作物件；新段落預設 `{ text: '' }`
- `graphMath` 插入新節點的預設段落改為 `[{ text: '（新段落）' }]`
- `NodeList` 的節點摘要改讀 `node.paragraphs[0]?.text`
- `StagePreview` 不需改動——它透過 `SceneView` 渲染，自動反映新行為

### 6. 內容改寫（`pompeii-bakery`、`tower-of-london-anne`，共 92 段）

把已經用「」寫在旁白裡的對白抽成獨立的 speaker 段，並補上該節點 `cast` 缺的說話者（含站位）。移除所有 `talking` 欄位。

**旁白密度是硬要求。** 抽走引號對白後，剩下的旁白常常只剩「她說」這種骨架。為了不讓劇本退化成舞台指示，留下的旁白要補寫回現有的密度——環境、動作、身體感、第二人稱主角的內心，跟現況同樣的顆粒度。

- **新增的只有旁白**：對白只搬既有的引號句，不無中生有
- **每個旁白段至少兩到三句完整描寫**，不接受「火滅了。」「門開了。」這種單句舞台指示
- 段數預期從 92 段增加到約 130–160 段

改寫範例（`pompeii-bakery` n1 第二段）：

現況（一段）

> 「八十一個。」她說。明天是節慶，鎮上訂了雙倍。她把第八十一個麵團收了邊，在上面按了一個小小的指印——她的記號，說這樣烤出來就認得哪一條是她的。

改寫後（三段）

> 旁白：爐膛暖起來的時候卡絲塔進來，圍裙上還帶著外頭的夜氣。她沒說早安，直接走到案板前，把昨夜發好的麵團一個一個數過去，指節在每一團上按一下，像在點名。
>
> 卡絲塔（泡泡）：「八十一個。」
>
> 旁白：明天是節慶，鎮上訂了雙倍。她把第八十一個麵團收了邊，在上面按了一個小小的指印——她的記號，說這樣烤出來就認得哪一條是她的。你看著那個指印，想它待會會在爐裡變成什麼樣子。

兩篇改完各自跑 `validateScript` 確認通過。

### 7. 測試

- `schema.test.ts`：新段落形狀通過驗證；`speaker` 不在 cast 時被擋下；`speaker` 指向未定義角色時被擋下
- 新增 `SpeechBubble.test.tsx`：角色名與文字渲染、站位 class
- `SceneView` 的分支：對白段出現 `speech-bubble` 且無 `text-card`；旁白段相反；非說話者掛 `is-dimmed`、說話者不掛；旁白段所有人都不掛
- `CharacterSprite.test.tsx`：原本測 `is-talking` 的案例改測 `dimmed` prop
- `PlayPage.test.tsx`：11 處 `click(text-card)` 改為點 `.scene`；補一個 `choosing` 時點 `.scene` 不推進的案例
- `NodePanel.test.tsx`：說話者下拉的選項與變更；移除 cast 成員時 speaker 被清空；原本測 talking checkbox 的案例移除
- `test/fixtures.ts`、`data/preload.test.ts`、`graphMath.test.ts`：更新段落形狀

驗收：`npm test` 全綠、`npm run build`（含 `tsc -b`）通過，並在 `npm run dev` 的 `/play/pompeii-bakery` 實際確認泡泡位置、尖角指向與壓暗效果。

## 不做（YAGNI）

- 打字機逐字顯示效果
- 畫外音（不在台上的人說話）與旁白者名牌
- 對白的語音／TTS
- `paragraphs` → `lines` 的全面改名
