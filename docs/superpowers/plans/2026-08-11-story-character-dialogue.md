# story 人物對話與頭上對話泡泡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 `story/` 的劇本每一段都能標註說話者，說話者是角色時對話泡泡從該角色頭上出現、非說話者壓暗，旁白仍走畫面下方的框。

**Architecture:** 節點的 `paragraphs` 從 `string[]` 換成 `{ text, speaker? }[]`，`speaker` 是角色 id、省略即旁白，並由 `validateScript` 強制 `speaker` 必須在該節點的 `cast` 內。`SceneView` 依當前段落有無 `speaker` 二選一渲染 `SpeechBubble`（絕對定位在 sprite 容器上緣附近）或既有的 `TextCard`；推進的點擊區從 `TextCard` 上移到 `.scene`，因為對白段沒有下方框可點。播放狀態機（`engine/player.ts`）完全不動。

**Tech Stack:** Vite 8、React 19、TypeScript 7、zod 4、vitest 4（jsdom）、@testing-library/react

## Global Constraints

- **npm 指令在 `story/` 目錄下執行**：`npm test`（= `vitest run`）、`npm run build`（= `tsc -b && vite build`）、`npm run dev`
- **git 指令在 repo root（`lorescape/`）執行**——各 task 的 commit 步驟寫的是 `story/...` 開頭的路徑
- 段落 key 名維持 `paragraphs`、`PlayState.paragraphIndex` 不改名——本計畫不做 `paragraphs` → `lines` 的改名
- 泡泡視覺沿用 `.text-card` 的調性：背景 `rgba(10, 10, 10, 0.72)`、圓角 `1rem`、文字 `#f5f5f5`、`line-height: 1.6`
- `.sprite` 的尺寸與位移一律用 `.scene` 的相對單位（`%` 或 `cqw`），**絕不用 viewport 單位**——`.scene` 有 `max-width: 480px`，vw 在寬螢幕會與它脫節
- 泡泡不得放進 `.sprite`：`.sprite` 有 `pointer-events: none`，且 breathe 動畫在寫 `scaleY`
- 不在台上的人不能說話——畫外音一律用旁白寫
- 每個 commit 前 `npm test` 必須全綠
- 文件與 commit message 用繁體中文（技術名詞除外）

---

## 檔案結構

| 檔案 | 責任 | 動作 |
|---|---|---|
| `src/engine/schema.ts` | 劇本 schema 與 `validateScript` 的跨欄位規則 | 修改 |
| `src/engine/content.test.ts` | 守門測試：`public/content/` 下的真實劇本必須通過驗證 | 新建 |
| `src/components/SpeechBubble.tsx` | 對話泡泡的 markup（純呈現，無邏輯） | 新建 |
| `src/components/SpeechBubble.test.tsx` | 泡泡的測試 | 新建 |
| `src/components/SceneView.tsx` | 場景組裝：決定泡泡／旁白框、傳 dimmed、承接推進點擊 | 修改 |
| `src/components/SceneView.test.tsx` | 場景分支的測試 | 新建 |
| `src/components/TextCard.tsx` | 旁白框（移除 onTap，點擊改由 `.scene` 承接） | 修改 |
| `src/components/CharacterSprite.tsx` | 角色立繪（`talking` → `dimmed`） | 修改 |
| `src/styles/character.css` | sprite 與泡泡的定位、壓暗 | 修改 |
| `src/styles/play.css` | `.scene` 加 container context | 修改 |
| `src/editor/panels/NodePanel.tsx` | 節點屬性面板：段落說話者下拉、cast 一致性 | 修改 |
| `src/editor/panels/NodeList.tsx` | 節點清單摘要（讀 `paragraphs[0].text`） | 修改 |
| `src/editor/graph/graphMath.ts` | 新節點的預設段落 | 修改 |
| `src/test/fixtures.ts` | 測試用劇本 | 修改 |
| `public/content/*/script.json` | 兩篇劇本內容 | 修改 |

`src/engine/player.ts`、`src/editor/useStory.ts`、`src/editor/stage/StagePreview.tsx`、`src/data/progress.ts` **不需修改**——它們只碰 `paragraphs.length` 與 `paragraphIndex`，不碰段落內容。

---

## Task 1: 段落資料形狀遷移

把段落從字串換成物件、移除 `talking`、加上 `speaker` 的驗證規則，並把所有讀取端同步改掉。這個 task 刻意做成一次到位的原子遷移——拆開會留下無法通過 `tsc -b` 的中間狀態。**做完行為與現在完全一樣**，只是資料形狀換了。

**Files:**
- Modify: `src/engine/schema.ts`
- Modify: `src/engine/schema.test.ts`
- Create: `src/engine/content.test.ts`
- Modify: `src/test/fixtures.ts`
- Modify: `src/data/preload.test.ts:13-16`
- Modify: `src/components/SceneView.tsx:38`
- Modify: `src/components/CharacterSprite.tsx`
- Modify: `src/components/CharacterSprite.test.tsx:17-23`
- Modify: `src/editor/panels/NodeList.tsx:99`
- Modify: `src/editor/panels/NodeList.test.tsx:14`
- Modify: `src/editor/panels/NodePanel.tsx:26-32, 69-97, 172-179`
- Modify: `src/editor/panels/NodePanel.test.tsx`
- Modify: `src/editor/graph/graphMath.ts:107`
- Modify: `src/editor/graph/graphMath.test.ts:72`
- Modify: `src/editor/stage/StagePreview.test.tsx:17`
- Modify: `public/content/pompeii-bakery/script.json`
- Modify: `public/content/tower-of-london-anne/script.json`

**Interfaces:**
- Consumes: 無（第一個 task）
- Produces:
  - `export const paragraphSchema` 與 `export type Paragraph = { text: string; speaker?: string }`
  - `ScriptNode['paragraphs']: Paragraph[]`
  - `CastMember` 不再有 `talking`
  - `CharacterSprite` 的 props：`{ character: Character; member: CastMember; slug: string; dimmed?: boolean }`（本 task 只先移除 `talking`／`is-talking`，`dimmed` 由 Task 4 加入）

- [ ] **Step 1: 寫 schema 的失敗測試**

在 `src/engine/schema.test.ts` 的 `cast 引用未定義角色時 throw` 之後加兩個測試：

```ts
test('段落 speaker 不在該節點 cast 內時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].paragraphs[0].speaker = 'master'
  bad.nodes[0].cast = []
  expect(() => validateScript(bad)).toThrow(/說話者不在台上/)
})

test('段落 speaker 指向未定義角色時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].paragraphs[0].speaker = 'ghost'
  expect(() => validateScript(bad)).toThrow(/ghost/)
})

test('段落 speaker 在 cast 內時通過', () => {
  const ok = structuredClone(demoScript)
  ok.nodes[0].paragraphs[0].speaker = 'master'
  expect(validateScript(ok).nodes[0].paragraphs[0].speaker).toBe('master')
})
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `npm test -- src/engine/schema.test.ts`
Expected: FAIL——fixtures 的 `paragraphs` 還是字串，`bad.nodes[0].paragraphs[0].speaker = ...` 會是 TypeScript 型別錯誤／執行時無效

- [ ] **Step 3: 改 schema**

`src/engine/schema.ts`——在 `choiceSchema` 之前加入 `paragraphSchema`，改 `castMemberSchema` 與 `nodeSchema`：

```ts
export const characterSchema = z.object({
  id: z.string().min(1), name: z.string().min(1),
  image: z.string().min(1),
})
export const castMemberSchema = z.object({
  character: z.string(), position: z.enum(['left', 'center', 'right']),
})
// speaker 省略 = 旁白（走畫面下方的 .text-card）；有值 = 該角色說話，泡泡從他頭上出來。
export const paragraphSchema = z.object({
  text: z.string().min(1), speaker: z.string().optional(),
})
export const choiceSchema = z.object({ text: z.string().min(1), to: z.string().min(1) })
export const nodeSchema = z.object({
  id: z.string().min(1), background: z.string().min(1), bgm: z.string().optional(),
  cast: z.array(castMemberSchema).optional(),
  paragraphs: z.array(paragraphSchema).min(1),
  next: z.string().optional(),
  choices: z.array(choiceSchema).min(2).max(3).optional(),
  ending: z.object({ title: z.string().min(1) }).optional(),
})
```

型別匯出加一行：

```ts
export type Paragraph = z.infer<typeof paragraphSchema>
```

`validateScript` 的 `for (const node of script.nodes)` 迴圈內，在 cast 檢查之後補上段落檢查：

```ts
    for (const m of node.cast ?? [])
      if (!charIds.has(m.character)) throw new Error(`節點 ${node.id} 引用未定義角色：${m.character}`)
    // speaker 必須是已定義角色，且必須在台上——泡泡要有錨點，畫外音一律用旁白寫。
    const castIds = new Set((node.cast ?? []).map((m) => m.character))
    node.paragraphs.forEach((p, i) => {
      if (p.speaker === undefined) return
      if (!charIds.has(p.speaker))
        throw new Error(`節點 ${node.id} 第 ${i + 1} 段引用未定義角色：${p.speaker}`)
      if (!castIds.has(p.speaker))
        throw new Error(`節點 ${node.id} 第 ${i + 1} 段的說話者不在台上：${p.speaker}`)
    })
```

- [ ] **Step 4: 改 fixtures**

`src/test/fixtures.ts` 整份替換為：

```ts
import type { Script } from '../engine/schema'

export const demoScript: Script = {
  slug: 'demo', title: '測試故事', place: '測試地', intro: '你是一名學徒。',
  startNode: 'n1',
  characters: [{ id: 'master', name: '師傅', image: 'characters/master/full.png' }],
  nodes: [
    { id: 'n1', background: 'scenes/n1.png', bgm: 'audio/main.mp3',
      cast: [{ character: 'master', position: 'center' }],
      paragraphs: [{ text: '第一段' }, { text: '第二段' }], choices: [
        { text: '往左', to: 'end-a' }, { text: '往右', to: 'end-b' }] },
    { id: 'end-a', background: 'scenes/n1.png', paragraphs: [{ text: '結局A' }], ending: { title: '結局A' } },
    { id: 'end-b', background: 'scenes/n1.png', paragraphs: [{ text: '結局B' }], ending: { title: '結局B' } },
    // n2：附加在陣列末端、無入邊的 next 型節點，只供 graphMath retarget 測試使用；
    // 不影響既有節點的順序/索引，其餘測試不受影響。
    { id: 'n2', background: 'scenes/n1.png', paragraphs: [{ text: '過場' }], next: 'end-b' },
  ],
}
```

- [ ] **Step 5: 執行 schema 測試確認通過**

Run: `npm test -- src/engine/schema.test.ts`
Expected: PASS（全部 10 個測試）

- [ ] **Step 6: 遷移兩篇真實劇本**

在 `story/` 目錄下執行這段一次性轉換（字串段落 → `{ text }`、移除所有 `talking`）：

```bash
python3 - <<'PY'
import json, pathlib
for slug in ['pompeii-bakery', 'tower-of-london-anne']:
    p = pathlib.Path(f'public/content/{slug}/script.json')
    d = json.loads(p.read_text(encoding='utf-8'))
    for node in d['nodes']:
        node['paragraphs'] = [
            para if isinstance(para, dict) else {'text': para}
            for para in node['paragraphs']
        ]
        for member in node.get('cast', []):
            member.pop('talking', None)
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(slug, 'ok')
PY
```

- [ ] **Step 7: 寫真實劇本的守門測試**

建立 `src/engine/content.test.ts`：

```ts
import { readFileSync } from 'node:fs'
import { validateScript, catalogSchema } from './schema'

// public/content/ 下的劇本是播放頁的唯一事實來源，格式壞掉在 CI 就要擋下，
// 不能等到瀏覽器載入才炸。
const catalog = catalogSchema.parse(
  JSON.parse(readFileSync('public/content/index.json', 'utf8')),
)

test.each(catalog.stories.map((s) => s.slug))('%s 的 script.json 通過驗證', (slug) => {
  const raw = JSON.parse(readFileSync(`public/content/${slug}/script.json`, 'utf8'))
  expect(() => validateScript(raw)).not.toThrow()
})
```

- [ ] **Step 8: 執行守門測試確認通過**

Run: `npm test -- src/engine/content.test.ts`
Expected: PASS（兩篇各一個測試）

- [ ] **Step 9: 改所有讀取端**

`src/components/SceneView.tsx:38`——把段落文字改成讀 `.text`：

```tsx
        <TextCard text={node.paragraphs[state.paragraphIndex].text} onTap={onAdvance} />
```

`src/components/CharacterSprite.tsx`——移除 `talking`／`is-talking`（`is-talking` 從來沒有對應的 CSS，是死設定）：

```tsx
import { assetUrl } from '../data/loadScript'
import type { CastMember, Character } from '../engine/schema'

export function CharacterSprite({ character, member, slug }: {
  character: Character; member: CastMember; slug: string
}) {
  const className = ['sprite', `sprite--${member.position}`].join(' ')
  return (
    <div className={className} data-testid={`sprite-${character.id}`}>
      <img
        className="sprite__image"
        src={assetUrl(slug, character.image)}
        alt=""
      />
    </div>
  )
}
```

`src/components/CharacterSprite.test.tsx`——刪掉 `talking 時掛 is-talking class；否則不掛` 整個測試（第 17–23 行），保留第一個測試。

`src/editor/panels/NodeList.tsx:99`：

```tsx
              summary={node.paragraphs[0]?.text.slice(0, SUMMARY_LENGTH) ?? ''}
```

`src/editor/panels/NodeList.test.tsx:14`：

```ts
  expect(screen.getByText(demoScript.nodes[0].paragraphs[0].text.slice(0, 12), { exact: false })).toBeInTheDocument()
```

`src/editor/graph/graphMath.ts:107`：

```ts
    paragraphs: [{ text: '（新段落）' }],
```

`src/editor/graph/graphMath.test.ts:72`：

```ts
  expect(inserted.paragraphs).toEqual([{ text: '（新段落）' }])
```

`src/editor/stage/StagePreview.test.tsx:17`：

```ts
    expect(screen.getByText(demoScript.nodes[0].paragraphs[0].text)).toBeInTheDocument()
```

`src/data/preload.test.ts:13-16`——三個節點的段落改物件：

```ts
    { id: 'n1', background: 'scenes/n1.png', paragraphs: [{ text: '第一段' }], choices: [
      { text: '往左', to: 'end-a' }, { text: '往右', to: 'end-b' }] },
    { id: 'end-a', background: 'scenes/end-a.png', paragraphs: [{ text: '結局A' }], ending: { title: '結局A' } },
    { id: 'end-b', background: 'scenes/end-b.png', paragraphs: [{ text: '結局B' }], ending: { title: '結局B' } },
```

- [ ] **Step 10: 改編輯器的段落編輯（物件化 + 移除 talking checkbox）**

`src/editor/panels/NodePanel.tsx`——import 加 `Paragraph`：

```tsx
import type { CastMember, Choice, Paragraph, Script, ScriptNode } from '../../engine/schema'
```

段落區塊的四個 helper（第 26–32 行）：

```tsx
  // 段落
  const updateParagraph = (index: number, patch: Partial<Paragraph>) =>
    onChange({
      ...node,
      paragraphs: node.paragraphs.map((p, i) => (i === index ? { ...p, ...patch } : p)),
    })
  const addParagraph = () => onChange({ ...node, paragraphs: [...node.paragraphs, { text: '' }] })
  const removeParagraph = (index: number) =>
    onChange({ ...node, paragraphs: node.paragraphs.filter((_, i) => i !== index) })
  const moveParagraph = (index: number, delta: number) =>
    onChange({ ...node, paragraphs: moveItem(node.paragraphs, index, delta) })
```

textarea 的 value 與 onChange（第 71–75 行）：

```tsx
            <textarea
              className="node-panel__textarea"
              value={paragraph.text}
              onChange={(e) => updateParagraph(index, { text: e.target.value })}
            />
```

移除 cast 的「說話中」checkbox——刪掉第 172–179 行整個 `<label className="node-panel__checkbox">` 區塊。

- [ ] **Step 11: 改 NodePanel 測試**

`src/editor/panels/NodePanel.test.tsx`——四處段落斷言改物件：

```ts
test('編輯段落文字回傳新節點', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  const box = screen.getAllByRole('textbox')[0]
  fireEvent.change(box, { target: { value: '新文字' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [{ text: '新文字' }, ...node.paragraphs.slice(1)],
  }))
})
```

`新增與刪除段落` 的第一個斷言改為 `paragraphs: [...node.paragraphs, { text: '' }]`，第二個維持 `node.paragraphs.slice(1)` 不變。`段落可用↓與下一段落交換順序` 的斷言維持 `[node.paragraphs[1], node.paragraphs[0]]` 不變。

`cast 編輯角色、位置與說話中` 改名並砍掉 talking 段落：

```ts
test('cast 編輯角色與位置', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)

  const position = screen.getAllByRole('combobox', { name: '位置' })[0]
  fireEvent.change(position, { target: { value: 'left' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [{ ...node.cast![0], position: 'left' }],
  }))
})
```

- [ ] **Step 12: 執行全部測試**

Run: `npm test`
Expected: PASS，全綠

- [ ] **Step 13: 型別檢查與 build**

Run: `npm run build`
Expected: 成功，無 TypeScript 錯誤

- [ ] **Step 14: Commit**

```bash
git add -A story/src story/public/content
git commit -m "refactor(story): 段落改為 { text, speaker? } 物件並移除 cast.talking"
```

---

## Task 2: SpeechBubble 元件與定位樣式

**Files:**
- Create: `src/components/SpeechBubble.tsx`
- Create: `src/components/SpeechBubble.test.tsx`
- Modify: `src/styles/character.css`
- Modify: `src/styles/play.css:1-16`

**Interfaces:**
- Consumes: Task 1 的 `Paragraph`（本 task 不直接用，只用純字串 props）
- Produces: `SpeechBubble({ name, text, position }: { name: string; text: string; position: 'left' | 'center' | 'right' })`，渲染 `data-testid="speech-bubble"` 的元素，class 為 `bubble bubble--<position>`

- [ ] **Step 1: 寫失敗測試**

建立 `src/components/SpeechBubble.test.tsx`：

```tsx
import { render, screen } from '@testing-library/react'
import { SpeechBubble } from './SpeechBubble'

test('渲染角色名與對白文字', () => {
  render(<SpeechBubble name="師傅" text="八十一個。" position="center" />)
  const bubble = screen.getByTestId('speech-bubble')
  expect(bubble).toHaveTextContent('師傅')
  expect(bubble).toHaveTextContent('八十一個。')
})

test('依站位掛上對應的 class', () => {
  const { rerender } = render(<SpeechBubble name="師傅" text="嗯。" position="left" />)
  expect(screen.getByTestId('speech-bubble')).toHaveClass('bubble', 'bubble--left')
  rerender(<SpeechBubble name="師傅" text="嗯。" position="right" />)
  expect(screen.getByTestId('speech-bubble')).toHaveClass('bubble--right')
})
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `npm test -- src/components/SpeechBubble.test.tsx`
Expected: FAIL，`Failed to resolve import "./SpeechBubble"`

- [ ] **Step 3: 建立元件**

`src/components/SpeechBubble.tsx`：

```tsx
import type { CastMember } from '../engine/schema'

export function SpeechBubble({ name, text, position }: {
  name: string; text: string; position: CastMember['position']
}) {
  return (
    <div className={`bubble bubble--${position}`} data-testid="speech-bubble">
      <span className="bubble__name">{name}</span>
      <p className="bubble__text">{text}</p>
    </div>
  )
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `npm test -- src/components/SpeechBubble.test.tsx`
Expected: PASS（2 個測試）

- [ ] **Step 5: 加上 container context**

`src/styles/play.css` 的 `.scene` 補一行（放在 `position: relative` 之後）：

```css
.scene {
  position: relative;
  /* 對話泡泡要用 cqw 換算 sprite 高度（sprite 高 = 寬 × 1.5，寬是 .scene 寬的
     72%／58%）。.scene 有 max-width: 480px，用 vw 會在寬螢幕上與它脫節。 */
  container-type: inline-size;
```

- [ ] **Step 6: 加上泡泡樣式**

`src/styles/character.css` 檔尾附加：

```css
/* 對話泡泡：錨在 sprite 容器上緣附近。
   「頭頂」的精確 y 座標程式拿不到——.sprite 是 2:3 容器、圖片 object-fit:
   contain 貼底，頭在圖裡的高度由構圖決定。可靠的錨點只有容器上緣；因為角色圖
   規格就是 1024×1536（正好 2:3），容器上緣 ≈ 圖片上緣 ≈ 頭頂附近。
   泡泡刻意不放進 .sprite：.sprite 有 pointer-events: none，且 breathe 動畫在
   寫 scaleY，放進去泡泡會跟著抖。 */
.bubble {
  position: absolute;
  /* 高於 .text-card 的 1 */
  z-index: 2;
  /* --sprite-h 由 SceneView 依台上人數給（108cqw 單人／87cqw 兩人以上），
     減 4cqw 讓泡泡底緣略壓進頭頂上方，不會浮太遠。 */
  bottom: calc(var(--sprite-h, 108cqw) - 4cqw);
  max-width: 78cqw;
  padding: 0.75rem 1rem;
  border-radius: 1rem;
  background-color: rgba(10, 10, 10, 0.72);
  color: #f5f5f5;
  line-height: 1.6;
  /* 推進的點擊由 .scene 承接，泡泡不吃事件 */
  pointer-events: none;
  animation: fade-slide-in 0.3s ease-out both;
}

.bubble__name {
  display: block;
  margin-bottom: 0.25rem;
  font-size: 0.75rem;
  color: rgba(245, 245, 245, 0.6);
}

.bubble__text {
  margin: 0;
}

.bubble--left {
  left: 4cqw;
}

.bubble--center {
  left: 50%;
  /* 與 .sprite--center 同理：與 transform 分開寫，避免被進場動畫蓋掉 */
  translate: -50% 0;
}

.bubble--right {
  right: 4cqw;
}

/* 尖角：從泡泡底緣往下指向角色。 */
.bubble::after {
  content: '';
  position: absolute;
  bottom: -8px;
  border-left: 8px solid transparent;
  border-right: 8px solid transparent;
  border-top: 8px solid rgba(10, 10, 10, 0.72);
}

.bubble--left::after {
  left: 24px;
}

.bubble--center::after {
  left: 50%;
  translate: -50% 0;
}

.bubble--right::after {
  right: 24px;
}
```

- [ ] **Step 7: 執行全部測試**

Run: `npm test`
Expected: PASS，全綠

- [ ] **Step 8: Commit**

```bash
git add story/src/components/SpeechBubble.tsx story/src/components/SpeechBubble.test.tsx story/src/styles/character.css story/src/styles/play.css
git commit -m "feat(story): 新增對話泡泡元件與頭上定位樣式"
```

---

## Task 3: SceneView 分支——對白出泡泡、旁白出下框、點擊區上移

**Files:**
- Modify: `src/components/SceneView.tsx`
- Create: `src/components/SceneView.test.tsx`
- Modify: `src/components/TextCard.tsx`
- Modify: `src/pages/PlayPage.test.tsx`

**Interfaces:**
- Consumes: Task 2 的 `SpeechBubble({ name, text, position })`；Task 1 的 `Paragraph`
- Produces:
  - `.scene` 元素帶 `data-testid="scene"`，`onClick` 在 `state.status === 'playing'` 時呼叫 `onAdvance()`
  - `TextCard({ text }: { text: string })`——**不再有 `onTap` prop**

- [ ] **Step 1: 寫失敗測試**

建立 `src/components/SceneView.test.tsx`：

```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { SceneView } from './SceneView'
import { demoScript } from '../test/fixtures'
import type { Script } from '../engine/schema'
import type { PlayState } from '../engine/player'

// 第一段旁白、第二段由 master 說；用於驗證同一節點內兩種段落的切換。
const script: Script = structuredClone(demoScript)
script.nodes[0].paragraphs = [{ text: '第一段' }, { text: '第二段', speaker: 'master' }]

const playing = (paragraphIndex: number): PlayState =>
  ({ nodeId: 'n1', paragraphIndex, status: 'playing' })

test('旁白段渲染下方旁白框，不出現泡泡', () => {
  render(<SceneView script={script} state={playing(0)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(screen.getByTestId('text-card')).toHaveTextContent('第一段')
  expect(screen.queryByTestId('speech-bubble')).not.toBeInTheDocument()
})

test('對白段渲染角色頭上的泡泡，不出現旁白框', () => {
  render(<SceneView script={script} state={playing(1)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  const bubble = screen.getByTestId('speech-bubble')
  expect(bubble).toHaveTextContent('第二段')
  expect(bubble).toHaveTextContent('師傅')
  expect(bubble).toHaveClass('bubble--center')
  expect(screen.queryByTestId('text-card')).not.toBeInTheDocument()
})

test('playing 時點 scene 推進', async () => {
  const onAdvance = vi.fn()
  render(<SceneView script={script} state={playing(0)} slug="demo" onAdvance={onAdvance} onChoose={() => {}} />)
  await userEvent.click(screen.getByTestId('scene'))
  expect(onAdvance).toHaveBeenCalledTimes(1)
})

test('choosing 時點 scene 不推進，且渲染選項', async () => {
  const onAdvance = vi.fn()
  const state: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing' }
  render(<SceneView script={script} state={state} slug="demo" onAdvance={onAdvance} onChoose={() => {}} />)
  await userEvent.click(screen.getByTestId('scene'))
  expect(onAdvance).not.toHaveBeenCalled()
  expect(screen.getByRole('button', { name: '往左' })).toBeInTheDocument()
  expect(screen.queryByTestId('speech-bubble')).not.toBeInTheDocument()
})

test('台上人數決定 --sprite-h', () => {
  const { container, rerender } = render(
    <SceneView script={script} state={playing(0)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(container.querySelector<HTMLElement>('.scene')!.style.getPropertyValue('--sprite-h')).toBe('108cqw')

  const twoOnStage = structuredClone(script)
  twoOnStage.characters.push({ id: 'apprentice', name: '學徒', image: 'characters/apprentice/full.png' })
  twoOnStage.nodes[0].cast = [
    { character: 'master', position: 'left' },
    { character: 'apprentice', position: 'right' },
  ]
  rerender(<SceneView script={twoOnStage} state={playing(0)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(container.querySelector<HTMLElement>('.scene')!.style.getPropertyValue('--sprite-h')).toBe('87cqw')
})
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `npm test -- src/components/SceneView.test.tsx`
Expected: FAIL，`Unable to find an element by: [data-testid="scene"]`

- [ ] **Step 3: 改 SceneView**

`src/components/SceneView.tsx` 整份替換：

```tsx
import type { CSSProperties, ReactNode } from 'react'
import { assetUrl } from '../data/loadScript'
import { currentNode, type PlayState } from '../engine/player'
import type { Script } from '../engine/schema'
import { CharacterSprite } from './CharacterSprite'
import { SpeechBubble } from './SpeechBubble'
import { TextCard } from './TextCard'
import { ChoiceList } from './ChoiceList'

export function SceneView({
  script,
  state,
  slug,
  onAdvance,
  onChoose,
  children,
}: {
  script: Script
  state: PlayState
  slug: string
  onAdvance: () => void
  onChoose: (index: number) => void
  children?: ReactNode
}) {
  const node = currentNode(script, state)
  const characterById = new Map(script.characters.map((character) => [character.id, character]))
  const cast = node.cast ?? []
  const paragraph = node.paragraphs[state.paragraphIndex]
  // validateScript 保證 speaker 一定在 cast 內，這裡仍取 member 才拿得到站位；
  // 兩者都在才視為對白段，否則退回旁白框。
  const speakerMember = paragraph.speaker
    ? cast.find((member) => member.character === paragraph.speaker)
    : undefined
  const speaker = speakerMember ? characterById.get(speakerMember.character) : undefined

  return (
    <div
      className="scene"
      data-testid="scene"
      style={{
        backgroundImage: `url(${assetUrl(slug, node.background)})`,
        // sprite 高 = 寬 × 1.5，寬是 .scene 寬的 72%（單人）／58%（兩人以上），
        // 對齊 character.css 的 .sprite 寬度規則。
        '--sprite-h': cast.length >= 2 ? '87cqw' : '108cqw',
      } as CSSProperties}
      // 對白段沒有下方框可點，推進的點擊區改由整個場景承接。choosing 時不吃
      // 點擊，否則點選項會連帶推進。
      onClick={() => { if (state.status === 'playing') onAdvance() }}
    >
      {cast.map((member) => {
        const character = characterById.get(member.character)
        return character ? (
          <CharacterSprite key={character.id} character={character} member={member} slug={slug} />
        ) : null
      })}
      {children}
      {state.status === 'choosing' && node.choices ? (
        <ChoiceList choices={node.choices} onChoose={onChoose} />
      ) : speaker && speakerMember ? (
        <SpeechBubble name={speaker.name} text={paragraph.text} position={speakerMember.position} />
      ) : (
        <TextCard text={paragraph.text} />
      )}
    </div>
  )
}
```

- [ ] **Step 4: 改 TextCard**

`src/components/TextCard.tsx` 整份替換——移除 `onTap`，否則點擊會先觸發 TextCard 再冒泡到 `.scene`，一次點擊推進兩段：

```tsx
export function TextCard({ text }: { text: string }) {
  return (
    <div className="text-card" data-testid="text-card">
      <p>{text}</p>
    </div>
  )
}
```

- [ ] **Step 5: 執行 SceneView 測試確認通過**

Run: `npm test -- src/components/SceneView.test.tsx`
Expected: PASS（5 個測試）

- [ ] **Step 6: 改 PlayPage 測試的點擊目標**

`src/pages/PlayPage.test.tsx`——11 處 `screen.getByTestId('text-card')` 全部改為 `screen.getByTestId('scene')`：

在 `story/` 目錄下執行：

```bash
sed -i '' "s/getByTestId('text-card')/getByTestId('scene')/g" src/pages/PlayPage.test.tsx
```

- [ ] **Step 7: 執行全部測試**

Run: `npm test`
Expected: PASS，全綠

- [ ] **Step 8: 型別檢查與 build**

Run: `npm run build`
Expected: 成功

- [ ] **Step 9: Commit**

```bash
git add story/src/components story/src/pages/PlayPage.test.tsx
git commit -m "feat(story): 對白段改出頭上泡泡，推進點擊區上移到 scene"
```

---

## Task 4: 非說話者壓暗

**Files:**
- Modify: `src/components/CharacterSprite.tsx`
- Modify: `src/components/CharacterSprite.test.tsx`
- Modify: `src/components/SceneView.tsx`
- Modify: `src/components/SceneView.test.tsx`
- Modify: `src/styles/character.css`

**Interfaces:**
- Consumes: Task 3 的 `SceneView`
- Produces: `CharacterSprite` 新增 optional prop `dimmed?: boolean`，為 true 時 class 加上 `is-dimmed`

- [ ] **Step 1: 寫失敗測試**

`src/components/CharacterSprite.test.tsx` 檔尾附加：

```tsx
test('dimmed 時掛 is-dimmed class；否則不掛', () => {
  const { rerender } = render(
    <CharacterSprite character={master} member={{ character: 'master', position: 'left' }} slug="demo" dimmed />)
  expect(screen.getByTestId('sprite-master')).toHaveClass('is-dimmed', 'sprite--left')
  rerender(
    <CharacterSprite character={master} member={{ character: 'master', position: 'left' }} slug="demo" />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-dimmed')
})
```

`src/components/SceneView.test.tsx` 檔尾附加：

```tsx
test('對白段只壓暗非說話者，旁白段誰都不壓暗', () => {
  const twoOnStage = structuredClone(script)
  twoOnStage.characters.push({ id: 'apprentice', name: '學徒', image: 'characters/apprentice/full.png' })
  twoOnStage.nodes[0].cast = [
    { character: 'master', position: 'left' },
    { character: 'apprentice', position: 'right' },
  ]

  const { rerender } = render(
    <SceneView script={twoOnStage} state={playing(1)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-dimmed')
  expect(screen.getByTestId('sprite-apprentice')).toHaveClass('is-dimmed')

  rerender(
    <SceneView script={twoOnStage} state={playing(0)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-dimmed')
  expect(screen.getByTestId('sprite-apprentice')).not.toHaveClass('is-dimmed')
})
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `npm test -- src/components/CharacterSprite.test.tsx src/components/SceneView.test.tsx`
Expected: FAIL——`Expected element to have class "is-dimmed"`

- [ ] **Step 3: 改 CharacterSprite**

`src/components/CharacterSprite.tsx`：

```tsx
import { assetUrl } from '../data/loadScript'
import type { CastMember, Character } from '../engine/schema'

export function CharacterSprite({ character, member, slug, dimmed = false }: {
  character: Character; member: CastMember; slug: string; dimmed?: boolean
}) {
  const className = ['sprite', `sprite--${member.position}`, dimmed ? 'is-dimmed' : '']
    .filter(Boolean).join(' ')
  return (
    <div className={className} data-testid={`sprite-${character.id}`}>
      <img
        className="sprite__image"
        src={assetUrl(slug, character.image)}
        alt=""
      />
    </div>
  )
}
```

- [ ] **Step 4: SceneView 傳入 dimmed**

`src/components/SceneView.tsx` 的 cast map 改為：

```tsx
      {cast.map((member) => {
        const character = characterById.get(member.character)
        return character ? (
          <CharacterSprite
            key={character.id}
            character={character}
            member={member}
            slug={slug}
            // 旁白段沒有說話者，誰都不壓暗。
            dimmed={speakerMember !== undefined && member.character !== speakerMember.character}
          />
        ) : null
      })}
```

- [ ] **Step 5: 加壓暗樣式**

`src/styles/character.css` 的 `.sprite` 規則內，在 `pointer-events: none;` 之後補一行：

```css
  transition: filter 0.3s ease;
```

並在 `.sprite + .sprite` 規則之後插入：

```css
/* 對白段時壓暗非說話者，與泡泡的尖角一起指出誰在說話。 */
.sprite.is-dimmed {
  filter: brightness(0.6);
}
```

- [ ] **Step 6: 執行測試確認通過**

Run: `npm test -- src/components/CharacterSprite.test.tsx src/components/SceneView.test.tsx`
Expected: PASS

- [ ] **Step 7: 執行全部測試**

Run: `npm test`
Expected: PASS，全綠

- [ ] **Step 8: Commit**

```bash
git add story/src/components story/src/styles/character.css
git commit -m "feat(story): 對白段壓暗非說話者"
```

---

## Task 5: 編輯器的說話者下拉與 cast 一致性

`speaker` 指到不在 cast 的角色會被 Task 1 的驗證擋下、存檔失敗，使用者會卡住卻看不出原因。所以刪除或抽換 cast 成員時必須連帶處理段落的 `speaker`。（spec 第 5 節只寫了「刪除」；抽換是同一個坑，一併處理。）

**Files:**
- Modify: `src/editor/panels/NodePanel.tsx`
- Modify: `src/editor/panels/NodePanel.test.tsx`
- Modify: `src/styles/editor.css`

**Interfaces:**
- Consumes: Task 1 的 `Paragraph` 與 `updateParagraph(index, patch)`
- Produces: 每段一個 `aria-label="說話者"` 的 `<select>`，`value` 為角色 id 或 `''`（旁白）

- [ ] **Step 1: 寫失敗測試**

`src/editor/panels/NodePanel.test.tsx` 檔尾附加：

```ts
test('說話者下拉列出旁白與台上角色，選取後寫入 speaker', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  const speaker = screen.getAllByRole('combobox', { name: '說話者' })[0]
  expect(speaker).toHaveValue('')
  expect(screen.getAllByRole('option', { name: '旁白' })[0]).toBeInTheDocument()

  fireEvent.change(speaker, { target: { value: 'master' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [{ text: node.paragraphs[0].text, speaker: 'master' }, ...node.paragraphs.slice(1)],
  }))
})

test('說話者選回旁白時移除 speaker 欄位', () => {
  const onChange = vi.fn()
  const withSpeaker: ScriptNode = {
    ...node,
    paragraphs: [{ text: '第一段', speaker: 'master' }, ...node.paragraphs.slice(1)],
  }
  render(<NodePanel script={demoScript} node={withSpeaker} slug="demo" onChange={onChange} />)
  fireEvent.change(screen.getAllByRole('combobox', { name: '說話者' })[0], { target: { value: '' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [{ text: '第一段' }, ...node.paragraphs.slice(1)],
  }))
  expect(onChange.mock.calls[0][0].paragraphs[0]).not.toHaveProperty('speaker')
})

test('刪除 cast 成員時清空指向他的段落 speaker', () => {
  const onChange = vi.fn()
  const withSpeaker: ScriptNode = {
    ...node,
    paragraphs: [{ text: '第一段', speaker: 'master' }, { text: '第二段' }],
  }
  render(<NodePanel script={demoScript} node={withSpeaker} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getAllByRole('button', { name: '刪除角色' })[0])
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [],
    paragraphs: [{ text: '第一段' }, { text: '第二段' }],
  }))
})

test('抽換 cast 角色時把段落 speaker 一併換過去', () => {
  const onChange = vi.fn()
  const twoCharScript: Script = {
    ...demoScript,
    characters: [
      ...demoScript.characters,
      { id: 'apprentice', name: '學徒', image: 'characters/apprentice/full.png' },
    ],
  }
  const withSpeaker: ScriptNode = {
    ...node,
    paragraphs: [{ text: '第一段', speaker: 'master' }, { text: '第二段' }],
  }
  render(<NodePanel script={twoCharScript} node={withSpeaker} slug="demo" onChange={onChange} />)
  fireEvent.change(screen.getAllByRole('combobox', { name: '角色' })[0], { target: { value: 'apprentice' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [{ character: 'apprentice', position: 'center' }],
    paragraphs: [{ text: '第一段', speaker: 'apprentice' }, { text: '第二段' }],
  }))
})
```

檔頭的 import 補上 `Script`：

```ts
import type { Script, ScriptNode } from '../../engine/schema'
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `npm test -- src/editor/panels/NodePanel.test.tsx`
Expected: FAIL，`Unable to find an accessible element with the role "combobox" and name "說話者"`

- [ ] **Step 3: 加說話者的 setter**

`src/editor/panels/NodePanel.tsx`——在 `moveParagraph` 之後加入。選回旁白時直接重建物件而不是塞 `speaker: undefined`，讓寫出的 JSON 乾淨：

```tsx
  const setSpeaker = (index: number, characterId: string) =>
    onChange({
      ...node,
      paragraphs: node.paragraphs.map((p, i) =>
        i !== index ? p : characterId ? { ...p, speaker: characterId } : { text: p.text }),
    })
```

- [ ] **Step 4: 加說話者下拉到段落列**

`src/editor/panels/NodePanel.tsx` 的段落 `<div className="node-panel__row">` 內，在 `<textarea>` **之前**插入：

```tsx
            <select
              className="node-panel__speaker"
              aria-label="說話者"
              value={paragraph.speaker ?? ''}
              onChange={(e) => setSpeaker(index, e.target.value)}
            >
              <option value="">旁白</option>
              {(node.cast ?? []).map((member) => (
                <option key={member.character} value={member.character}>
                  {script.characters.find((c) => c.id === member.character)?.name ?? member.character}
                </option>
              ))}
            </select>
```

- [ ] **Step 5: cast 的一致性處理**

`src/editor/panels/NodePanel.tsx`——`updateCast` 與 `removeCast` 整組替換。段落的 `speaker` 若指向被刪掉／被抽換的角色，就會讓存檔通不過 `validateScript`，所以在這裡一併修正：

```tsx
  // cast
  const updateCast = (index: number, patch: Partial<CastMember>) => {
    const previous = (node.cast ?? [])[index]?.character
    const nextCharacter = patch.character
    onChange({
      ...node,
      cast: (node.cast ?? []).map((m, i) => (i === index ? { ...m, ...patch } : m)),
      paragraphs:
        nextCharacter && previous && nextCharacter !== previous
          ? node.paragraphs.map((p) =>
              p.speaker === previous ? { ...p, speaker: nextCharacter } : p)
          : node.paragraphs,
    })
  }
  const addCast = () =>
    onChange({
      ...node,
      cast: [...(node.cast ?? []), { character: script.characters[0]?.id ?? '', position: 'center' }],
    })
  const removeCast = (index: number) => {
    const removed = (node.cast ?? [])[index]?.character
    onChange({
      ...node,
      cast: (node.cast ?? []).filter((_, i) => i !== index),
      paragraphs: node.paragraphs.map((p) => (p.speaker === removed ? { text: p.text } : p)),
    })
  }
```

- [ ] **Step 6: 加下拉的樣式**

`src/styles/editor.css` 檔尾附加：

```css
/* 說話者下拉夾在段落列最前面，寬度固定才不會被 textarea 擠掉。 */
.node-panel__speaker {
  flex: 0 0 auto;
  align-self: flex-start;
  max-width: 6rem;
}
```

- [ ] **Step 7: 執行 NodePanel 測試確認通過**

Run: `npm test -- src/editor/panels/NodePanel.test.tsx`
Expected: PASS

- [ ] **Step 8: 執行全部測試與 build**

Run: `npm test && npm run build`
Expected: 兩者皆成功

- [ ] **Step 9: Commit**

```bash
git add story/src/editor/panels/NodePanel.tsx story/src/editor/panels/NodePanel.test.tsx story/src/styles/editor.css
git commit -m "feat(story): 工作台可設定每段說話者並維持 cast 一致性"
```

---

## Task 6: 實機微調泡泡落點

CSS 的 `108cqw`／`87cqw`／`-4cqw`／`24px` 是幾何推算的起點，真實角色圖的頭頂位置由構圖決定，必須拿真素材看過才算數。這個 task 是唯一需要人眼確認的環節，**必須在內容改寫（Task 7、8）之前做**——否則改寫時看到的畫面不可信。

**Files:**
- Modify: `src/styles/character.css`（視目測結果調整 `.bubble` 的 `bottom` 與 `::after` 的水平偏移）

**Interfaces:**
- Consumes: Task 2–4 的成果
- Produces: 微調後的 `.bubble` 定位數值

- [ ] **Step 1: 準備一個臨時的對白段**

編輯 `public/content/pompeii-bakery/script.json`，把 n1 的第二段（`「八十一個。」她說。……` 那段）暫時加上 speaker：

```json
      { "text": "「八十一個。」她說。明天是節慶，鎮上訂了雙倍。她把第八十一個麵團收了邊，在上面按了一個小小的指印——她的記號，說這樣烤出來就認得哪一條是她的。", "speaker": "casta" }
```

- [ ] **Step 2: 啟動 dev server**

Run: `npm run dev`
開啟終端機顯示的網址 + `/play/pompeii-bakery`，點「開始體驗」後點一次畫面推進到第二段。

- [ ] **Step 3: 目測三件事並記錄**

- 泡泡底緣的尖角是否落在角色頭頂上方一小段（不重疊臉、也不浮在半空）
- 泡泡是否被 `.scene` 的上緣切掉（長對白時特別容易）
- 點畫面任一處是否正確推進；點到泡泡上也要能推進（`.bubble` 有 `pointer-events: none`）

- [ ] **Step 4: 調整數值**

依目測結果修改 `src/styles/character.css`：泡泡太高就把 `bottom: calc(var(--sprite-h, 108cqw) - 4cqw)` 的 `4cqw` 調大；被上緣切掉就再調大並縮 `max-width`；尖角沒對準角色就改 `.bubble--left::after` / `.bubble--right::after` 的 `24px`。每次改完瀏覽器會熱更新，重複到滿意為止。

- [ ] **Step 5: 用兩人同場再看一次**

暫時把 n1 的 cast 改成兩人（第二位用 `felix`，站位 `right`，`casta` 改 `left`），確認 `--sprite-h: 87cqw` 這條路徑的落點也正確，以及 `felix` 有被壓暗。看完把 cast 改回原樣。

- [ ] **Step 6: 還原臨時改動**

Run: `git checkout -- public/content/pompeii-bakery/script.json`
（`character.css` 的調整保留。）

- [ ] **Step 7: 執行全部測試**

Run: `npm test`
Expected: PASS，全綠

- [ ] **Step 8: Commit**

```bash
git add story/src/styles/character.css
git commit -m "style(story): 依實機目測微調對話泡泡落點"
```

---

## Task 7: 改寫 pompeii-bakery 為對白版

**Files:**
- Modify: `public/content/pompeii-bakery/script.json`（13 個節點、44 段）

**Interfaces:**
- Consumes: Task 1 的段落形狀與驗證規則、Task 5 的工作台
- Produces: 含 speaker 段落的 `pompeii-bakery` 劇本

**改寫規則（每個節點都要遵守）：**

1. 把已經用「」寫在旁白裡的對白抽成獨立的 speaker 段。**對白只搬既有的引號句，不無中生有。**
2. 抽出對白後，說話者必須在該節點的 `cast` 內。缺的就補進 `cast`，並給合理站位（單人 `center`；兩人一 `left` 一 `right`）。
3. **旁白密度是硬要求**：抽走對白後留下的旁白若只剩骨架（「她說。」），必須補寫回現有的顆粒度——環境、動作、身體感、第二人稱主角的內心。**每個旁白段至少兩到三句完整描寫**，不接受「火滅了。」「門開了。」這種單句舞台指示。**新增的只有旁白。**
4. 對白段保持短促自然，維持原本的口語感，不要為了「完整」而加長。
5. 段數會增加（全劇本從 44 段增到約 60–75 段），這是預期的。

**改寫範例**（n1 第二段，spec 已核可的樣板）：

原本一段——

> 「八十一個。」她說。明天是節慶，鎮上訂了雙倍。她把第八十一個麵團收了邊，在上面按了一個小小的指印——她的記號，說這樣烤出來就認得哪一條是她的。

改成三段——

```json
      { "text": "爐膛暖起來的時候卡絲塔進來，圍裙上還帶著外頭的夜氣。她沒說早安，直接走到案板前，把昨夜發好的麵團一個一個數過去，指節在每一團上按一下，像在點名。" },
      { "text": "「八十一個。」", "speaker": "casta" },
      { "text": "明天是節慶，鎮上訂了雙倍。她把第八十一個麵團收了邊，在上面按了一個小小的指印——她的記號，說這樣烤出來就認得哪一條是她的。你看著那個指印，想它待會會在爐裡變成什麼樣子。" }
```

- [ ] **Step 1: 逐節點改寫**

用 Read 讀 `public/content/pompeii-bakery/script.json`，從 n1 開始，一次處理一個節點，依上面五條規則改寫並用 Edit 寫回。每個節點做完再處理下一個，不要一次改完整份。

- [ ] **Step 2: 驗證格式**

Run: `npm test -- src/engine/content.test.ts`
Expected: PASS——若失敗，錯誤訊息會直接指出是哪個節點第幾段的 speaker 有問題，修掉再跑

- [ ] **Step 3: 實機通讀一遍**

Run: `npm run dev`
開 `/play/pompeii-bakery`，從頭點到底走完至少一條路線，確認：
- 泡泡出現在正確的角色頭上、非說話者有壓暗
- 沒有任何旁白段短到只剩一句舞台指示
- 對白與前後旁白讀起來是連貫的，不是被硬切開的

- [ ] **Step 4: 執行全部測試**

Run: `npm test`
Expected: PASS，全綠

- [ ] **Step 5: Commit**

```bash
git add story/public/content/pompeii-bakery/script.json
git commit -m "feat(story): pompeii-bakery 改寫為人物對話版"
```

---

## Task 8: 改寫 tower-of-london-anne 為對白版

**Files:**
- Modify: `public/content/tower-of-london-anne/script.json`（11 個節點、48 段）

**Interfaces:**
- Consumes: 同 Task 7
- Produces: 含 speaker 段落的 `tower-of-london-anne` 劇本

**改寫規則與 Task 7 完全相同，逐條重述（不要回頭翻 Task 7）：**

1. 把已經用「」寫在旁白裡的對白抽成獨立的 speaker 段。**對白只搬既有的引號句，不無中生有。**
2. 抽出對白後，說話者必須在該節點的 `cast` 內。缺的就補進 `cast`，並給合理站位（單人 `center`；兩人一 `left` 一 `right`）。角色為 `anne`、`kingston`、`thomas`。
3. **旁白密度是硬要求**：抽走對白後留下的旁白若只剩骨架，必須補寫回現有的顆粒度——環境、動作、身體感、第二人稱主角的內心。**每個旁白段至少兩到三句完整描寫**，不接受「火滅了。」「門開了。」這種單句舞台指示。**新增的只有旁白。**
4. 對白段保持短促自然，維持原本的口語感。
5. 全劇本從 48 段增到約 65–85 段，這是預期的。

**注意**：這篇有「她只問了一句『我可以帶我的女官嗎』」這種被轉述包住的引號句。轉述句（「她問了……」）**留在旁白**，只有直接引語才抽成 speaker 段；若要抽，就要把包住它的轉述動詞一併拿掉、讓對白獨立成句。兩種都可以，但同一句不能既留在旁白又出現在泡泡裡。

- [ ] **Step 1: 逐節點改寫**

用 Read 讀 `public/content/tower-of-london-anne/script.json`，從 n1 開始，一次處理一個節點，依上面五條規則改寫並用 Edit 寫回。

- [ ] **Step 2: 驗證格式**

Run: `npm test -- src/engine/content.test.ts`
Expected: PASS

- [ ] **Step 3: 實機通讀一遍**

Run: `npm run dev`
開 `/play/tower-of-london-anne`，從頭點到底走完至少一條路線，確認泡泡位置、壓暗、旁白密度與前後連貫。

- [ ] **Step 4: 執行全部測試**

Run: `npm test`
Expected: PASS，全綠

- [ ] **Step 5: Commit**

```bash
git add story/public/content/tower-of-london-anne/script.json
git commit -m "feat(story): tower-of-london-anne 改寫為人物對話版"
```

---

## Task 9: 更新 story/README.md

**Files:**
- Modify: `story/README.md`

**Interfaces:**
- Consumes: Task 1–8 的成果
- Produces: 與實作一致的文件

- [ ] **Step 1: 改「資料結構」段**

`story/README.md` 的資料結構說明目前寫「節點（段落、選項、cast 站位/talking、背景、結局）」，把 `script.json` 那一項改為：

```markdown
- `script.json`：節點（段落、選項、cast 站位、背景、結局）、
  角色定義（`id`/`name`/`image`：單張去背全身圖路徑）、`startNode`。
  段落是 `{ text, speaker? }`：`speaker` 是角色 id 時，對話泡泡從該角色頭上
  出來、其他人壓暗；省略即旁白，走畫面下方的框。`speaker` 必須在該節點的
  `cast` 內（`validateScript` 會擋），畫外音一律用旁白寫。
```

- [ ] **Step 2: 改「能編什麼」段**

「角色站位／talking」那一項改為：

```markdown
- **角色站位／說話者**：每個角色是單張去背全身圖（`characters/<id>/full.png`），
  不再有骨骼／部件編輯；節點屬性面板可調整每個 cast 成員的站位（左／中／
  右），並在每個段落上選擇說話者（旁白或台上任一角色）。站位的視覺效果交由
  `character.css` 的 `.sprite--left/center/right` 定位與縮放。刪除或抽換 cast
  成員時，指向他的段落 `speaker` 會自動清空／改指，避免存檔被驗證擋下。
```

- [ ] **Step 3: 確認沒有殘留的 talking 字眼**

Run: `grep -rn "talking" story/ --exclude-dir=node_modules --exclude-dir=dist`
Expected: 無輸出

- [ ] **Step 4: Commit**

```bash
git add story/README.md
git commit -m "docs(story): README 同步段落 speaker 與泡泡行為"
```

---

## 最終驗收

- [ ] Run: `cd story && npm test`——全綠
- [ ] Run: `cd story && npm run build`——`tsc -b` 與 `vite build` 皆成功
- [ ] Run: `cd story && npm run dev`，`/play/pompeii-bakery` 與 `/play/tower-of-london-anne` 各走完一條完整路線：對白出頭上泡泡、旁白出下方框、非說話者壓暗、點畫面推進、選項不被誤觸
- [ ] Run: `cd story && npm run dev`，`/editor` 選一篇劇本，改一段的說話者、刪一個 cast 成員，確認舞台預覽即時反映且存檔成功（無錯誤 toast）
