# story 引擎 choice flag 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓劇本的選項能留下 flag，段落與選項能依 flag 顯示或隱藏，使結局能依先前選擇真的分岔。

**Architecture:** `PlayState` 增加 `flags: string[]`。可見性判斷集中在 `player.ts` 的三個純函式（`matches` / `visibleParagraphs` / `visibleChoices`），播放頁與工作台預覽都只透過它們取內容。「整個節點被條件清空」與「選單一個都不剩」由 `validateScript` 靜態擋掉，執行期不寫防禦分支。

**Tech Stack:** TypeScript、React 19、zod（schema 驗證）、vitest + @testing-library/react（測試）、Vite。

## Global Constraints

- 一律在 `story/` 目錄下執行指令；測試用 `npx vitest run`，型別檢查用 `npx tsc -b`。
- flag 名稱格式：`^[a-z][a-z0-9-]*$`（kebab-case）。條件格式：`^!?[a-z][a-z0-9-]*$`。
- 條件只用**單一 `when` 欄位**，`!` 前綴表示否定。不得新增 `whenNot` 欄位。
- `PlayState.flags` 用 `string[]`，不得用 `Set`——它要 `JSON.stringify` 進 localStorage。
- flag 只增不減，沒有 unset。
- 節點背景不依 flag 切換，`nodeSchema` 不動。
- 註解與錯誤訊息用繁體中文，與既有程式碼一致。
- 每個 task 結束前 `npx vitest run` 全綠才能 commit。

---

### Task 1: schema 的條件欄位與四條守門規則

**Files:**
- Modify: `src/engine/schema.ts`
- Test: `src/engine/schema.test.ts`

**Interfaces:**
- Consumes: 無（第一個 task）
- Produces:
  - `Paragraph` 型別多 `when?: string`
  - `Choice` 型別多 `set?: string[]`、`when?: string`
  - `export function conditionFlag(condition: string): string` — 去掉 `!` 前綴取出 flag 名
  - `export function declaredFlags(script: Script): string[]` — 劇本內所有被 `set` 過的 flag，已排序去重

- [ ] **Step 1: 寫失敗的測試**

在 `src/engine/schema.test.ts` 末端加入：

```ts
test('when 格式非法時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].choices![0].set = ['sealed']
  bad.nodes[0].paragraphs.push({ text: '條件段', when: '!!sealed' })
  expect(() => validateScript(bad)).toThrow()
})

test('set 的 flag 名稱非法時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].choices![0].set = ['Sealed']
  expect(() => validateScript(bad)).toThrow()
})

test('when 參照從未被 set 過的 flag 時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].paragraphs.push({ text: '條件段', when: 'sealed' })
  expect(() => validateScript(bad)).toThrow(/從未設定過的 flag：sealed/)
})

test('when 參照的 flag 有 choice set 過就通過', () => {
  const ok = structuredClone(demoScript)
  ok.nodes[0].choices![0].set = ['sealed']
  ok.nodes[1].paragraphs.push({ text: '條件段', when: '!sealed' })
  expect(() => validateScript(ok)).not.toThrow()
})

test('節點的段落全部帶 when 時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].choices![0].set = ['sealed']
  bad.nodes[1].paragraphs = [{ text: '只有條件段', when: 'sealed' }]
  expect(() => validateScript(bad)).toThrow(/至少要有一段沒有 when/)
})

test('有 choices 的節點無條件選項少於兩個時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].choices = [
    { text: '往左', to: 'end-a', set: ['sealed'] },
    { text: '往右', to: 'end-b', when: 'sealed' },
  ]
  expect(() => validateScript(bad)).toThrow(/沒有 when 的選項至少要有兩個/)
})

test('declaredFlags 收集全劇本被 set 過的 flag', () => {
  const s = structuredClone(demoScript)
  s.nodes[0].choices![0].set = ['sealed', 'warned']
  s.nodes[0].choices![1].set = ['sealed']
  expect(declaredFlags(validateScript(s))).toEqual(['sealed', 'warned'])
})
```

把檔案第一行的 import 改成：

```ts
import { validateScript, catalogSchema, declaredFlags } from './schema'
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `npx vitest run src/engine/schema.test.ts`
Expected: FAIL——`declaredFlags` is not exported，以及新規則的 throw 沒有發生。

- [ ] **Step 3: 實作**

在 `src/engine/schema.ts` 的 `paragraphSchema` 之前加入兩個 regex：

```ts
// flag 名稱：kebab-case。條件多一個可選的 ! 前綴表示否定。用單一 when 欄位而
// 不是 when/whenNot 兩個——概念只有一個，也就沒有「兩邊同時給值」的組合要處理。
const FLAG_RE = /^[a-z][a-z0-9-]*$/
const CONDITION_RE = /^!?[a-z][a-z0-9-]*$/
```

把 `paragraphSchema` 與 `choiceSchema` 改成：

```ts
export const paragraphSchema = z.object({
  text: z.string().min(1), speaker: z.string().optional(),
  when: z.string().regex(CONDITION_RE).optional(),
})
export const choiceSchema = z.object({
  text: z.string().min(1), to: z.string().min(1),
  set: z.array(z.string().regex(FLAG_RE)).optional(),
  when: z.string().regex(CONDITION_RE).optional(),
})
```

在 `validateScript` 之前加入兩個匯出函式：

```ts
export function conditionFlag(condition: string): string {
  return condition.startsWith('!') ? condition.slice(1) : condition
}

export function declaredFlags(script: Script): string[] {
  const flags = new Set<string>()
  for (const node of script.nodes)
    for (const choice of node.choices ?? [])
      for (const flag of choice.set ?? []) flags.add(flag)
  return [...flags].sort()
}
```

在 `validateScript` 內、`for (const node of script.nodes)` 迴圈**之前**加入：

```ts
const flagNames = new Set(declaredFlags(script))
```

在同一個迴圈內、既有的 `endCount` 檢查之後加入：

```ts
// 條件段落／選項：整個節點被條件清空、或選單一個都不剩，執行期沒有合理的
// 退路（畫面要顯示什麼？玩家要點什麼？），因此靜態擋掉。無條件的那幾段／
// 那幾個選項在任何 flag 組合下都在，是這兩條規則的依據。
if (!node.paragraphs.some((p) => p.when === undefined))
  throw new Error(`節點 ${node.id}：至少要有一段沒有 when 的段落`)
if (node.choices && node.choices.filter((c) => c.when === undefined).length < 2)
  throw new Error(`節點 ${node.id}：沒有 when 的選項至少要有兩個`)
// when 打錯字在執行期只會表現成「那段永遠不出現」，靜態擋掉才找得到。
for (const condition of [
  ...node.paragraphs.map((p) => p.when),
  ...(node.choices ?? []).map((c) => c.when),
]) {
  if (condition === undefined) continue
  const flag = conditionFlag(condition)
  if (!flagNames.has(flag))
    throw new Error(`節點 ${node.id} 參照從未設定過的 flag：${flag}`)
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `npx vitest run src/engine/schema.test.ts && npx tsc -b`
Expected: PASS，型別檢查無錯。

- [ ] **Step 5: Commit**

```bash
git add src/engine/schema.ts src/engine/schema.test.ts
git commit -m "feat(story): schema 支援 choice flag 與條件段落／選項"
```

---

### Task 2: player 的 flags 與可見性函式

**Files:**
- Modify: `src/engine/player.ts`
- Modify: `src/test/fixtures.ts`
- Test: `src/engine/player.test.ts`

**Interfaces:**
- Consumes: Task 1 的 `Paragraph.when`、`Choice.set`、`Choice.when`、`conditionFlag`
- Produces:
  - `PlayState` 多 `flags: string[]`
  - `export function matches(condition: string | undefined, flags: string[]): boolean`
  - `export function visibleParagraphs(node: ScriptNode, flags: string[]): Paragraph[]`
  - `export function visibleChoices(node: ScriptNode, flags: string[]): Choice[]`
  - `src/test/fixtures.ts` 匯出 `flagScript: Script`

- [ ] **Step 1: 新增測試用 fixture**

在 `src/test/fixtures.ts` 末端加入：

```ts
// 條件段落／選項的測試用劇本：start 的選項會 set flag，mid 有一段條件段落與
// 一個條件選項，三個選項各指向不同節點以便驗證「可見索引」對到正確目標。
export const flagScript: Script = {
  slug: 'flags', title: 'flag 測試', place: '測試地', intro: '介紹',
  startNode: 'start',
  characters: [],
  nodes: [
    { id: 'start', background: 'scenes/n1.png',
      paragraphs: [{ text: '開場' }],
      choices: [
        { text: '封爐', to: 'mid', set: ['sealed'] },
        { text: '直接走', to: 'mid' },
      ] },
    { id: 'mid', background: 'scenes/n1.png',
      paragraphs: [
        { text: '共用' },
        { text: '封了爐才有的一段', when: 'sealed' },
        { text: '沒封才有的一段', when: '!sealed' },
      ],
      choices: [
        { text: '去港口', to: 'harbor', when: '!sealed' },
        { text: '走城門', to: 'gate' },
        { text: '躲起來', to: 'end' },
      ] },
    { id: 'harbor', background: 'scenes/n1.png', paragraphs: [{ text: '港口' }], next: 'end' },
    { id: 'gate', background: 'scenes/n1.png', paragraphs: [{ text: '城門' }], next: 'end' },
    { id: 'end', background: 'scenes/n1.png', paragraphs: [{ text: '結束' }], ending: { title: '結局' } },
  ],
}
```

- [ ] **Step 2: 寫失敗的測試**

把 `src/engine/player.test.ts` 的 import 改成：

```ts
import {
  initState, advance, choose, currentNode,
  matches, visibleParagraphs, visibleChoices, type PlayState,
} from './player'
import { demoScript, flagScript } from '../test/fixtures'
```

修正既有測試裡的 `PlayState` 字面值（三處）——`initState` 的期望值、第 21 行與第 27 行的 `let s: PlayState`、第 33 行的 `const s`，全部補上 `flags: []`；第 23 行 `expect(s).toEqual(...)` 的期望值也補 `flags: []`。

在檔案末端加入：

```ts
test('matches：沒有條件永遠成立', () => {
  expect(matches(undefined, [])).toBe(true)
})

test('matches：正條件看 flag 在不在', () => {
  expect(matches('sealed', ['sealed'])).toBe(true)
  expect(matches('sealed', [])).toBe(false)
})

test('matches：! 前綴是否定', () => {
  expect(matches('!sealed', [])).toBe(true)
  expect(matches('!sealed', ['sealed'])).toBe(false)
})

test('visibleParagraphs 濾掉條件不成立的段落', () => {
  const mid = flagScript.nodes.find((n) => n.id === 'mid')!
  expect(visibleParagraphs(mid, ['sealed']).map((p) => p.text))
    .toEqual(['共用', '封了爐才有的一段'])
  expect(visibleParagraphs(mid, []).map((p) => p.text))
    .toEqual(['共用', '沒封才有的一段'])
})

test('visibleChoices 濾掉條件不成立的選項', () => {
  const mid = flagScript.nodes.find((n) => n.id === 'mid')!
  expect(visibleChoices(mid, ['sealed']).map((c) => c.text)).toEqual(['走城門', '躲起來'])
  expect(visibleChoices(mid, []).map((c) => c.text)).toEqual(['去港口', '走城門', '躲起來'])
})

test('advance 以可見段落數判斷段落用盡', () => {
  // mid 帶 sealed 時可見兩段：index 1 已是最後一段，再推進就進 choosing。
  const s: PlayState = { nodeId: 'mid', paragraphIndex: 1, status: 'playing', flags: ['sealed'] }
  expect(advance(flagScript, s).status).toBe('choosing')
})

test('choose 的 index 對應可見選項而不是 JSON 位置', () => {
  const sealed: PlayState = { nodeId: 'mid', paragraphIndex: 1, status: 'choosing', flags: ['sealed'] }
  expect(choose(flagScript, sealed, 0).nodeId).toBe('gate')
  const open: PlayState = { nodeId: 'mid', paragraphIndex: 2, status: 'choosing', flags: [] }
  expect(choose(flagScript, open, 0).nodeId).toBe('harbor')
})

test('choose 把 set 併進 flags 並去重', () => {
  const s: PlayState = { nodeId: 'start', paragraphIndex: 0, status: 'choosing', flags: ['sealed'] }
  expect(choose(flagScript, s, 0).flags).toEqual(['sealed'])
  const fresh: PlayState = { nodeId: 'start', paragraphIndex: 0, status: 'choosing', flags: [] }
  expect(choose(flagScript, fresh, 0).flags).toEqual(['sealed'])
})

test('choose 沒有 set 的選項不動 flags', () => {
  const s: PlayState = { nodeId: 'start', paragraphIndex: 0, status: 'choosing', flags: ['sealed'] }
  expect(choose(flagScript, s, 1).flags).toEqual(['sealed'])
})
```

- [ ] **Step 3: 執行測試確認失敗**

Run: `npx vitest run src/engine/player.test.ts`
Expected: FAIL——`matches` is not exported。

- [ ] **Step 4: 實作**

把 `src/engine/player.ts` 整份改成：

```ts
import { conditionFlag, type Choice, type Paragraph, type Script, type ScriptNode } from './schema'

export type PlayStatus = 'playing' | 'choosing' | 'ended'
// flags 用陣列不用 Set：整個 PlayState 會 JSON.stringify 進 localStorage。
export type PlayState = {
  nodeId: string
  paragraphIndex: number
  status: PlayStatus
  flags: string[]
}

export function initState(script: Script): PlayState {
  return { nodeId: script.startNode, paragraphIndex: 0, status: 'playing', flags: [] }
}

export function currentNode(script: Script, state: PlayState): ScriptNode {
  const node = script.nodes.find((n) => n.id === state.nodeId)
  if (!node) throw new Error(`節點不存在：${state.nodeId}`)
  return node
}

// 可見性只在這三個函式裡判斷，播放頁與工作台預覽都經過它們取內容。
export function matches(condition: string | undefined, flags: string[]): boolean {
  if (condition === undefined) return true
  const has = flags.includes(conditionFlag(condition))
  return condition.startsWith('!') ? !has : has
}

export function visibleParagraphs(node: ScriptNode, flags: string[]): Paragraph[] {
  return node.paragraphs.filter((p) => matches(p.when, flags))
}

export function visibleChoices(node: ScriptNode, flags: string[]): Choice[] {
  return (node.choices ?? []).filter((c) => matches(c.when, flags))
}

export function advance(script: Script, state: PlayState): PlayState {
  if (state.status !== 'playing') return state
  const node = currentNode(script, state)
  if (state.paragraphIndex < visibleParagraphs(node, state.flags).length - 1)
    return { ...state, paragraphIndex: state.paragraphIndex + 1 }
  if (node.next) return { ...state, nodeId: node.next, paragraphIndex: 0, status: 'playing' }
  if (node.choices) return { ...state, status: 'choosing' }
  return { ...state, status: 'ended' }
}

export function choose(script: Script, state: PlayState, index: number): PlayState {
  if (state.status !== 'choosing') return state
  const node = currentNode(script, state)
  const target = visibleChoices(node, state.flags)[index]
  if (!target) return state
  // 依 set 的順序附加到尾端、已存在的跳過：順序穩定，存檔比對才不會因為排列
  // 不同而失效。flag 只增不減，沒有 unset。
  const flags = [...state.flags]
  for (const flag of target.set ?? []) if (!flags.includes(flag)) flags.push(flag)
  return { nodeId: target.to, paragraphIndex: 0, status: 'playing', flags }
}
```

注意 `advance` 裡兩處 `return` 改用 `{ ...state, ... }` 展開，否則 `flags` 會在跳節點時掉失。

- [ ] **Step 5: 執行測試確認通過**

Run: `npx vitest run src/engine/player.test.ts && npx tsc -b`
Expected: PASS。`tsc -b` 此時會在 `progress.ts`、`SceneView.tsx`、`StagePreview.tsx` 報 `flags` 缺漏——這是預期的，後續 task 會修。若要在本 task 保持綠燈，先只跑 vitest，`tsc -b` 留到 Task 4 結束再跑。

- [ ] **Step 6: Commit**

```bash
git add src/engine/player.ts src/engine/player.test.ts src/test/fixtures.ts
git commit -m "feat(story): PlayState 加 flags，段落與選項依條件過濾"
```

---

### Task 3: 舊存檔補上 flags

**Files:**
- Modify: `src/data/progress.ts`
- Test: `src/data/progress.test.ts`

**Interfaces:**
- Consumes: Task 2 的 `PlayState.flags`
- Produces: `loadProgress` 回傳的 `PlayState` 保證 `flags` 是字串陣列

- [ ] **Step 1: 寫失敗的測試**

把 `src/data/progress.test.ts` 第 5 行改成：

```ts
const state: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'playing', flags: ['sealed'] }
```

在檔案末端加入：

```ts
test('舊存檔沒有 flags 時補成空陣列', () => {
  localStorage.setItem(
    'story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 1, status: 'playing' }),
  )
  expect(loadProgress('demo')).toEqual({
    nodeId: 'n1', paragraphIndex: 1, status: 'playing', flags: [],
  })
})

test('flags 型別不對時補成空陣列', () => {
  localStorage.setItem(
    'story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 1, status: 'playing', flags: 'sealed' }),
  )
  expect(loadProgress('demo')?.flags).toEqual([])
})

test('合法 flags 原樣載入', () => {
  saveProgress('demo', state)
  expect(loadProgress('demo')?.flags).toEqual(['sealed'])
})
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `npx vitest run src/data/progress.test.ts`
Expected: FAIL——載入結果沒有 `flags` 欄位。

- [ ] **Step 3: 實作**

在 `src/data/progress.ts` 的 `isPlayState` 之後加入：

```ts
function normalizeFlags(value: unknown): string[] {
  return Array.isArray(value) && value.every((v) => typeof v === 'string') ? value : []
}
```

`isPlayState` **不檢查** `flags`（改版前的存檔沒有這個欄位，不算損壞），把 `loadProgress` 改成：

```ts
export function loadProgress(slug: string): PlayState | null {
  const raw = localStorage.getItem(storageKey(slug))
  if (!raw) return null
  try {
    const parsed: unknown = JSON.parse(raw)
    if (!isPlayState(parsed)) return null
    // 正規化在這裡做，呼叫端永遠拿得到合法的 flags。舊存檔因此會走 !flag 那
    // 一支——那份存檔本來就不含這個資訊，無法還原。
    return { ...parsed, flags: normalizeFlags((parsed as Record<string, unknown>).flags) }
  } catch {
    return null
  }
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `npx vitest run src/data/progress.test.ts`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add src/data/progress.ts src/data/progress.test.ts
git commit -m "feat(story): 舊存檔載入時補上空 flags"
```

---

### Task 4: 播放畫面吃可見清單

**Files:**
- Modify: `src/components/SceneView.tsx`
- Modify: `src/pages/PlayPage.tsx:104-110`
- Test: `src/components/SceneView.test.tsx`（`ChoiceList` 的條件行為由 `SceneView` 的測試涵蓋——它的 props 沒變，單獨測等於測 `Array.filter`）

**Interfaces:**
- Consumes: Task 2 的 `visibleParagraphs`、`visibleChoices`
- Produces: 無新 API；`SceneView` 與 `ChoiceList` 的對外 props 不變

- [ ] **Step 1: 寫失敗的測試**

`src/components/SceneView.test.tsx` 第 14 行的 helper 與第 40 行的字面值補上 `flags: []`：

```ts
const playing = (paragraphIndex: number): PlayState =>
  ({ nodeId: 'n1', paragraphIndex, status: 'playing', flags: [] })
```

```ts
const state: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing', flags: [] }
```

在 `src/components/SceneView.test.tsx` 末端加入：

```ts
test('條件段落依 flags 顯示', () => {
  render(
    <SceneView
      script={flagScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 1, status: 'playing', flags: ['sealed'] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.getByTestId('text-card')).toHaveTextContent('封了爐才有的一段')
})

test('條件不成立時該段不出現，索引落在另一段', () => {
  render(
    <SceneView
      script={flagScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 1, status: 'playing', flags: [] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.getByTestId('text-card')).toHaveTextContent('沒封才有的一段')
})

test('條件選項依 flags 出現或消失', () => {
  const { rerender } = render(
    <SceneView
      script={flagScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 2, status: 'choosing', flags: [] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.getByRole('button', { name: '去港口' })).toBeInTheDocument()
  rerender(
    <SceneView
      script={flagScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 1, status: 'choosing', flags: ['sealed'] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.queryByRole('button', { name: '去港口' })).not.toBeInTheDocument()
  expect(screen.getByRole('button', { name: '走城門' })).toBeInTheDocument()
})
```

把該檔的 fixture import 改成 `import { demoScript, flagScript } from '../test/fixtures'`。

- [ ] **Step 2: 執行測試確認失敗**

Run: `npx vitest run src/components/SceneView.test.tsx`
Expected: FAIL——「去港口」在 `sealed` 狀態下仍然出現。

- [ ] **Step 3: 實作**

`src/components/SceneView.tsx`：import 加上兩個函式

```ts
import { currentNode, visibleChoices, visibleParagraphs, type PlayState } from '../engine/player'
```

把取段落那三行改成：

```ts
// 越界的 paragraphIndex（編輯器刪段落後未同步、存檔進度指向已縮短的節點、或
// flag 讓可見段落變少）沒有 error boundary 可接，必須退回最後一段。
const paragraphs = visibleParagraphs(node, state.flags)
const paragraph = paragraphs[Math.min(state.paragraphIndex, paragraphs.length - 1)]
```

把 `ChoiceList` 那一行改成：

```ts
{state.status === 'choosing' && node.choices ? (
  <ChoiceList choices={visibleChoices(node, state.flags)} onChoose={onChoose} />
) : ...
```

`src/pages/PlayPage.tsx`：import 加上 `visibleChoices`，把 `onChoose` 內取文字那行改成

```ts
onChoose={(i) => {
  const node = currentNode(script, state)
  // 追蹤送的是玩家實際點了第幾個（可見索引），與 JSON 裡的位置可能不同。
  const text = visibleChoices(node, state.flags)[i]?.text
  trackEvent(slug, 'choice_made', { node: node.id, index: i, text })
  setState(choosePlayer(script, state, i))
}}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `npx vitest run && npx tsc -b`
Expected: 全部 PASS，型別檢查無錯（`StagePreview.tsx` 的 `flags` 缺漏在 Task 6 修；若此時 `tsc -b` 仍報錯，先在 `StagePreview.tsx` 的 `state` 字面值補 `flags: []` 讓型別過關，Task 6 再換成真正的 props）。

- [ ] **Step 5: Commit**

```bash
git add src/components/SceneView.tsx src/components/SceneView.test.tsx src/pages/PlayPage.tsx src/editor/stage/StagePreview.tsx
git commit -m "feat(story): 播放畫面依 flags 過濾段落與選項"
```

---

### Task 5: 工作台編輯 set 與 when

**Files:**
- Modify: `src/editor/panels/NodePanel.tsx`
- Test: `src/editor/panels/NodePanel.test.tsx`

**Interfaces:**
- Consumes: Task 1 的 `declaredFlags`
- Produces: 無新 API；`NodePanel` 的 props 不變

- [ ] **Step 1: 寫失敗的測試**

在 `src/editor/panels/NodePanel.test.tsx` 末端加入：

```ts
test('可以編輯選項要設定的 flag', async () => {
  const onChange = vi.fn()
  const node = demoScript.nodes[0]
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  const input = screen.getAllByLabelText('設定 flag')[0]
  fireEvent.change(input, { target: { value: 'sealed, warned' } })
  expect(onChange).toHaveBeenCalledWith(
    expect.objectContaining({
      choices: [
        expect.objectContaining({ set: ['sealed', 'warned'] }),
        expect.objectContaining({ text: '往右' }),
      ],
    }),
  )
})

test('清空 flag 輸入會移除 set 欄位', () => {
  const onChange = vi.fn()
  const node = structuredClone(demoScript.nodes[0])
  node.choices![0].set = ['sealed']
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.change(screen.getAllByLabelText('設定 flag')[0], { target: { value: '' } })
  expect(onChange.mock.calls[0][0].choices[0]).not.toHaveProperty('set')
})

test('段落的顯示條件下拉列出劇本內所有 flag 的正反兩版', () => {
  const script = structuredClone(demoScript)
  script.nodes[0].choices![0].set = ['sealed']
  render(
    <NodePanel script={script} node={script.nodes[0]} slug="demo" onChange={() => {}} />,
  )
  const select = screen.getAllByLabelText('顯示條件')[0]
  expect([...select.querySelectorAll('option')].map((o) => o.textContent))
    .toEqual(['無條件', 'sealed', '!sealed'])
})

test('選段落的顯示條件會寫進 when', () => {
  const onChange = vi.fn()
  const script = structuredClone(demoScript)
  script.nodes[0].choices![0].set = ['sealed']
  render(<NodePanel script={script} node={script.nodes[0]} slug="demo" onChange={onChange} />)
  fireEvent.change(screen.getAllByLabelText('顯示條件')[0], { target: { value: '!sealed' } })
  expect(onChange.mock.calls[0][0].paragraphs[0].when).toBe('!sealed')
})
```

若該檔尚未 import `vi`／`fireEvent`／`structuredClone` 所需項目，補齊 import。

- [ ] **Step 2: 執行測試確認失敗**

Run: `npx vitest run src/editor/panels/NodePanel.test.tsx`
Expected: FAIL——找不到 label「設定 flag」與「顯示條件」。

- [ ] **Step 3: 實作**

`src/editor/panels/NodePanel.tsx` import 加上：

```ts
import { declaredFlags } from '../../engine/schema'
```

在元件內、`updateParagraph` 附近加入條件選項清單與三個 handler：

```ts
// 下拉選項＝劇本內所有被 set 過的 flag 的正反兩版。沒有 flag 時只剩「無條件」。
const conditions = declaredFlags(script).flatMap((flag) => [flag, `!${flag}`])

const setParagraphWhen = (index: number, condition: string) =>
  onChange({
    ...node,
    paragraphs: node.paragraphs.map((p, i) => {
      if (i !== index) return p
      if (condition) return { ...p, when: condition }
      const { when: _when, ...rest } = p
      return rest
    }),
  })

const setChoiceWhen = (index: number, condition: string) =>
  onChange({
    ...node,
    choices: (node.choices ?? []).map((c, i) => {
      if (i !== index) return c
      if (condition) return { ...c, when: condition }
      const { when: _when, ...rest } = c
      return rest
    }),
  })

const setChoiceFlags = (index: number, raw: string) => {
  const flags = raw.split(',').map((s) => s.trim()).filter(Boolean)
  onChange({
    ...node,
    choices: (node.choices ?? []).map((c, i) => {
      if (i !== index) return c
      if (flags.length) return { ...c, set: flags }
      const { set: _set, ...rest } = c
      return rest
    }),
  })
}
```

在每個段落列的 speaker 下拉旁邊加入：

```tsx
<label>
  顯示條件
  <select
    aria-label="顯示條件"
    value={paragraph.when ?? ''}
    onChange={(e) => setParagraphWhen(index, e.target.value)}
  >
    <option value="">無條件</option>
    {conditions.map((c) => <option key={c} value={c}>{c}</option>)}
  </select>
</label>
```

在每個選項列的「刪除選項」按鈕之前加入：

```tsx
<label>
  設定 flag
  <input
    aria-label="設定 flag"
    value={(choice.set ?? []).join(', ')}
    placeholder="逗號分隔，如 sealed, warned"
    onChange={(e) => setChoiceFlags(index, e.target.value)}
  />
</label>
<label>
  顯示條件
  <select
    aria-label="顯示條件"
    value={choice.when ?? ''}
    onChange={(e) => setChoiceWhen(index, e.target.value)}
  >
    <option value="">無條件</option>
    {conditions.map((c) => <option key={c} value={c}>{c}</option>)}
  </select>
</label>
```

- [ ] **Step 4: 執行測試確認通過**

Run: `npx vitest run src/editor/panels/NodePanel.test.tsx && npx tsc -b`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add src/editor/panels/NodePanel.tsx src/editor/panels/NodePanel.test.tsx
git commit -m "feat(story): 工作台可編輯選項的 set 與段落／選項的顯示條件"
```

---

### Task 6: 工作台預覽的 flag 開關

**Files:**
- Modify: `src/editor/stage/StagePreview.tsx`
- Modify: `src/editor/EditorPage.tsx:45`, `src/editor/EditorPage.tsx:140-146`
- Test: `src/editor/stage/StagePreview.test.tsx`

**Interfaces:**
- Consumes: Task 1 的 `declaredFlags`、Task 2 的 `visibleParagraphs`
- Produces: `StagePreview` 新增兩個 props——`flags: string[]`、`onFlagsChange(next: string[]): void`

- [ ] **Step 1: 寫失敗的測試**

把該檔的 fixture import 改成 `import { demoScript, flagScript } from '../../test/fixtures'`，並在既有測試的每個 `StagePreview` 呼叫補上 `flags={[]} onFlagsChange={() => {}}`。然後在末端加入：

```ts
test('劇本有 flag 時列出開關', () => {
  const script = structuredClone(demoScript)
  script.nodes[0].choices![0].set = ['sealed']
  render(
    <StagePreview
      script={script} slug="demo" nodeId="n1" paragraphIndex={0}
      onParagraphChange={() => {}} flags={[]} onFlagsChange={() => {}}
    />,
  )
  expect(screen.getByLabelText('sealed')).not.toBeChecked()
})

test('切換開關把 flag 加進來', () => {
  const onFlagsChange = vi.fn()
  const script = structuredClone(demoScript)
  script.nodes[0].choices![0].set = ['sealed']
  render(
    <StagePreview
      script={script} slug="demo" nodeId="n1" paragraphIndex={0}
      onParagraphChange={() => {}} flags={[]} onFlagsChange={onFlagsChange}
    />,
  )
  fireEvent.click(screen.getByLabelText('sealed'))
  expect(onFlagsChange).toHaveBeenCalledWith(['sealed'])
})

test('預覽的段落總數只算可見段落', () => {
  render(
    <StagePreview
      script={flagScript} slug="flags" nodeId="mid" paragraphIndex={0}
      onParagraphChange={() => {}} flags={['sealed']} onFlagsChange={() => {}}
    />,
  )
  expect(screen.getByText('第 1/2 段')).toBeInTheDocument()
})
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `npx vitest run src/editor/stage/StagePreview.test.tsx`
Expected: FAIL——`flags` 不是已知的 prop，且段落總數算成 3。

- [ ] **Step 3: 實作**

`src/editor/stage/StagePreview.tsx`：

```tsx
import type { ReactNode } from 'react'
import { SceneView } from '../../components/SceneView'
import { visibleParagraphs, type PlayState } from '../../engine/player'
import { declaredFlags, type Script } from '../../engine/schema'

export function StagePreview(props: {
  script: Script
  slug: string
  nodeId: string
  paragraphIndex: number
  onParagraphChange(index: number): void
  flags: string[]
  onFlagsChange(next: string[]): void
  children?: ReactNode
}) {
  const { script, slug, nodeId, paragraphIndex, onParagraphChange, flags, onFlagsChange, children } = props
  const node = script.nodes.find((n) => n.id === nodeId) ?? script.nodes[0]
  // 段落總數要算可見的，否則切了 flag 之後「第 n/m 段」會對不上畫面。
  const total = visibleParagraphs(node, flags).length
  const isLast = paragraphIndex >= total - 1
  const showChoices = isLast && !!node.choices

  const state: PlayState = {
    nodeId: node.id,
    paragraphIndex,
    status: showChoices ? 'choosing' : 'playing',
    flags,
  }
  const allFlags = declaredFlags(script)

  const toggle = (flag: string) =>
    onFlagsChange(flags.includes(flag) ? flags.filter((f) => f !== flag) : [...flags, flag])
```

`return (...)` 以下的 JSX 除了下面要加的那一塊之外全部維持原樣。

在 `stage-frame__paragraph-nav` 那個 div **之後**加入（`allFlags` 為空時整塊不渲染）：

```tsx
{allFlags.length > 0 && (
  <div className="stage-frame__flags">
    {allFlags.map((flag) => (
      <label key={flag}>
        <input
          type="checkbox"
          aria-label={flag}
          checked={flags.includes(flag)}
          onChange={() => toggle(flag)}
        />
        {flag}
      </label>
    ))}
  </div>
)}
```

在 `src/styles/editor.css` 末端加入：

```css
.stage-frame__flags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  padding: 0.5rem 0.75rem;
  font-size: 0.8rem;
}

.stage-frame__flags label {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}
```

`src/editor/EditorPage.tsx`：第 45 行附近加上

```ts
const [previewFlags, setPreviewFlags] = useState<string[]>([])
```

並把 `StagePreview` 的呼叫補上兩個 props：

```tsx
<StagePreview
  script={script}
  slug={slug}
  nodeId={previewNodeId}
  paragraphIndex={paragraphIndex}
  onParagraphChange={setParagraphIndex}
  flags={previewFlags}
  onFlagsChange={setPreviewFlags}
/>
```

- [ ] **Step 4: 執行測試確認通過**

Run: `npx vitest run && npx tsc -b`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add src/editor/stage/StagePreview.tsx src/editor/stage/StagePreview.test.tsx src/editor/EditorPage.tsx src/styles/editor.css
git commit -m "feat(story): 工作台預覽加 flag 開關"
```

---

### Task 7: 套用到《八十一條麵包》並更新 README

**Files:**
- Modify: `public/content/pompeii-bakery/script.json`
- Modify: `README.md`

**Interfaces:**
- Consumes: 前六個 task 的全部功能
- Produces: 無

- [ ] **Step 1: 在 n3d 的封爐選項加上 flag**

把 `n3d` 的 choices 改成：

```json
"choices": [
  { "text": "現在就走", "to": "n4a" },
  { "text": "把爐封好再走——麵包快出爐了", "to": "n4b", "set": ["sealed"] }
]
```

- [ ] **Step 2: 收斂兩處 flash-forward**

`n4a2` 的最後兩段（「你們跑起來的時候…」與「那個按在麵團頂上的指印…」）改成一段：

```json
{ "text": "你們跑起來的時候，坊裡那座爐還開著口。火會自己滅掉，第二爐的八十一條會冷掉、塌下去，然後被灰蓋住。" }
```

`n4b2` 的最後一段（「裡面那八十一條會在黑暗裡烤到焦透…」）改成：

```json
{ "text": "裡面那八十一條會在黑暗裡烤到焦透，然後被灰整個封起來。你當時不知道自己剛剛做了什麼。" }
```

兩處都拿掉「指印」的預告，讓結局去講。

- [ ] **Step 3: 兩個結局各加一組條件段落**

`n9b3`（留下來的人）把「每一條都還看得出當初劃開的紋路。麵包比你留得久，名字是別人的。」這一段換成兩段條件段落：

```json
{
  "text": "每一條都還看得出當初劃開的紋路，其中一條的頂上有一個小小的凹痕。麵包比你留得久。名字是別人的。指印是她的。",
  "when": "sealed"
},
{
  "text": "每一條都還看得出當初劃開的紋路，可是沒有一條頂上有指印——那一爐從來沒有被封起來。麵包比你留得久，名字是別人的，而她留下的那個記號沒有。",
  "when": "!sealed"
}
```

`n9a2`（活下來的人）在「你手裡一直握著那枚銅髮針。」那段**之前**插入兩段條件段落：

```json
{
  "text": "很多年以後你才聽說，那間坊被挖出來的時候，爐是封著的，裡面的麵包一條不少。你數過的那個數字，有人替你數了第二遍。",
  "when": "sealed"
},
{
  "text": "很多年以後你才聽說，那間坊被挖出來的時候，爐門是開的。裡面什麼也沒有留下——你走的那天忘了關它，或者說，你根本沒有想過要關。",
  "when": "!sealed"
}
```

- [ ] **Step 4: 驗證劇本**

Run:
```bash
npx vite-node -e "
import {readFileSync} from 'node:fs'
import {validateScript} from './src/engine/schema.ts'
const s = validateScript(JSON.parse(readFileSync('public/content/pompeii-bakery/script.json','utf8')))
console.log('節點', s.nodes.length)
"
```
Expected: 印出節點數且不 throw。若 throw「至少要有一段沒有 when」，表示某節點的段落全被條件化，回頭檢查 Step 3。

- [ ] **Step 5: 更新 README**

在 `README.md` 的「資料結構」段落，`script.json` 那一項的說明後面加入：

```markdown
  段落與選項都可以帶 `when`（`flag` 或 `!flag`）決定要不要出現；選項可以帶
  `set: string[]`，選到時把 flag 記進進度。`validateScript` 會擋：`when` 參照
  沒有任何選項 `set` 過的 flag、節點沒有任何無條件段落、有選項的節點無條件
  選項少於兩個。flag 只增不減，存進 localStorage 的進度會帶著它。
```

在「工作台」段落的「角色站位／說話者」那一項之後加入：

```markdown
- **flag 與顯示條件**：選項可設定 `set`（逗號分隔），段落與選項都可挑
  「顯示條件」。中欄預覽下方有一排 flag 開關，用來切換預覽的 flag 狀態。
```

- [ ] **Step 6: 全部測試與 build**

Run: `npx vitest run && npx tsc -b && npm run build`
Expected: 全部 PASS。

- [ ] **Step 7: Commit**

```bash
git add public/content/pompeii-bakery/script.json README.md
git commit -m "feat(story): 龐貝的兩個結局依 sealed flag 分岔"
```

---

## 驗收

實作完成後手動確認（`npm run dev`，開 `/play/pompeii-bakery`）：

1. 選「把爐封好再走」→ 走到「留下來的人」結局，看得到「其中一條的頂上有一個小小的凹痕……指印是她的」
2. 選「現在就走」→ 同一個結局改成「沒有一條頂上有指印」
3. 兩條路各走一次「活下來的人」結局，確認插入的那段也跟著換
4. 開 `/editor`，選 `n3d`，確認選項列看得到「設定 flag = sealed」；切換中欄下方的 `sealed` 開關，確認 `n9b3` 的預覽段落跟著換
