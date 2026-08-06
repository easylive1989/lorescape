# 沉浸式歷史故事體驗 Demo（第一階段）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打造獨立小站 `story.lorescape.app`：第二人稱分支歷史故事體驗（cel-shaded 場景 + 紙娃娃 NPC + BGM），含 Gemini 素材產線、Supabase 事件/問卷回收，並完成第一個劇本上線與 IG 測試邀請。

**Architecture:** 頂層新增 `story/`（Vite + React + TS 靜態站，引擎與劇本內容分離：一個劇本 = `public/content/<slug>/` 一個資料夾）；素材產線放 `scripts/story_assets/`（uv Python，呼叫 Gemini image model）；數據回收走 Supabase 兩張 anon insert-only 表。部署為 Firebase Hosting 第二個 site。

**Tech Stack:** Vite + React 19 + TypeScript（strict）、zod、@supabase/supabase-js v2、vitest + @testing-library/react、Python 3.11 + google-genai + Pillow、Firebase Hosting multi-site、GitHub Actions。

**Spec:** `docs/superpowers/specs/2026-08-06-immersive-story-demo-design.md`

## Global Constraints

- Node 22 / npm（比照 landing）；Python 用 `scripts/` 既有 uv 專案（`uv run`）。
- 機密只放 `.env`（`VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` / `GEMINI_API_KEY`），不進版控。
- 文案與文件一律繁中（技術名詞除外）；demo 只做繁中。
- 生圖模型：`gemini-2.5-flash-image`；角色部件以純洋紅背景 `#FF00FF` 生成後 chroma-key 去背。
- 事件表 `story_events` 與問卷表 `story_surveys`：RLS anon **insert-only**（不可 select）。
- 手機直式優先；主角不現身；單劇本規模：8–12 節點、2–3 選擇點、2 結局、5–8 場景圖、1–3 NPC。
- 每個 frontend task 完成須 `npm test`（vitest）全綠；Python task 須 `uv run pytest` 全綠。
- Commit message 繁中、比照現有慣例（`feat(story): …`、`chore(scripts): …`）。

---

## Task 總覽與依賴

| # | Task | 型態 | 依賴 |
|---|---|---|---|
| 1 | 候選故事篩選（5 選 1） | 內容/互動 | — |
| 2 | `story/` scaffold + 路由 + vitest | code | — |
| 3 | 劇本 schema + 驗證 + demo 劇本 | code | 2 |
| 4 | 播放邏輯 player | code | 3 |
| 5 | PlayPage：背景/文字卡/推進/選項 | code | 4 |
| 6 | CharacterSprite 紙娃娃動效 | code | 3 |
| 7 | AudioManager | code | 2 |
| 8 | 進度保存與續玩 | code | 4 |
| 9 | 素材預載與錯誤重試 | code | 5 |
| 10 | Supabase migrations | code | — |
| 11 | analytics client（埋點） | code | 2, 10 |
| 12 | 結局頁 + 問卷 + 感謝頁 | code | 5, 11 |
| 13 | HomePage + 手機版型 polish | code | 5 |
| 14 | Firebase multi-site + deploy-story.yml + CI | code/ops | 2 |
| 15 | 場景圖生成腳本 | code | — |
| 16 | 角色部件生成 + 去背切件 | code | 15 |
| 17 | 素材齊備檢查器 | code | 15, 16 |
| 18 | 劇本撰寫（選定故事 → script.json） | 內容/互動 | 1, 3 |
| 19 | 素材產出與驗收 | 內容/互動 | 16, 17, 18 |
| 20 | 部署上線 + 全分支走測 | ops | 12–14, 19 |
| 21 | IG 邀請素材與發布 | 內容/互動 | 20 |
| 22 | Feedback 匯總 + go/no-go | 內容/互動 | 21 |

---

### Task 1: 候選故事篩選（5 選 1）

**型態：** 內容/互動任務（無程式碼產出，deliverable 是候選清單與使用者選定結果）。

**Files:**
- 無（產出貼在對話中；選定結果記入 Task 18 的劇本）

- [ ] **Step 1: 確認 daily_stories 欄位**

Read `supabase/migrations/20260510000000_create_daily_story_tables.sql` 與後續 alter migrations（`20260527120000_add_paragraphs_to_daily_stories.sql` 等），取得 `daily_stories` / `daily_story_places` 確切欄位名。

- [ ] **Step 2: 撈出所有已發布故事**

用 publisher/.env 的 Supabase 憑證走 REST（唯讀）：

```bash
set -a; source publisher/.env; set +a
curl -s "$SUPABASE_URL/rest/v1/daily_stories?select=*,daily_story_places(*)" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" > /tmp/claude/daily_stories.json
```

（若 .env 內鍵名不同，以實際為準；只讀不寫。）

- [ ] **Step 3: 篩選候選**

篩選判準（依 spec）：
1. 國外景點，台灣人熟悉度高（京都、羅馬、巴黎等知名旅遊地標優先）。
2. 故事長度足夠（paragraphs 總字數多、敘事完整）。
3. 有戲劇性：有具體人物、衝突、事件轉折，適合改編為第二人稱分支劇本。

- [ ] **Step 4: 產出 5 個候選給使用者**

每個候選附：地點名、故事一句話梗概、為何適合改編（戲劇性亮點）、預想的虛構小人物視角。等使用者選定 1 個才算完成。

---

### Task 2: `story/` scaffold + 路由 + vitest

**Files:**
- Create: `story/package.json`, `story/tsconfig.json`, `story/vite.config.ts`, `story/index.html`, `story/.gitignore`, `story/.env.example`
- Create: `story/src/main.tsx`, `story/src/App.tsx`, `story/src/pages/HomePage.tsx`, `story/src/pages/PlayPage.tsx`, `story/src/styles/global.css`
- Test: `story/src/App.test.tsx`, `story/src/test/setup.ts`

**Interfaces:**
- Produces: 路由 `/`（`HomePage`）與 `/play/:slug`（`PlayPage`，此階段為佔位）；`npm test` / `npm run build` 可用。

- [ ] **Step 1: scaffold 專案**

```bash
cd story && npm init -y
npm i react react-dom react-router-dom zod @supabase/supabase-js
npm i -D typescript vite @vitejs/plugin-react vitest jsdom \
  @testing-library/react @testing-library/user-event @testing-library/jest-dom \
  @types/react @types/react-dom
```

`story/package.json` scripts：

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "test": "vitest run"
  }
}
```

`story/vite.config.ts`：

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
  },
})
```

（`test` 欄位需 `/// <reference types="vitest/config" />` 於檔首。）

`story/src/test/setup.ts`：

```ts
import '@testing-library/jest-dom/vitest'
```

`story/tsconfig.json`：strict、`"jsx": "react-jsx"`、`"moduleResolution": "bundler"`、`"types": ["vite/client"]`。
`story/.gitignore`：`node_modules`, `dist`, `.env`。
`story/.env.example`：

```
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

- [ ] **Step 2: 寫失敗測試（路由）**

`story/src/App.test.tsx`：

```tsx
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { AppRoutes } from './App'

test('首頁顯示站名', () => {
  render(<MemoryRouter initialEntries={['/']}><AppRoutes /></MemoryRouter>)
  expect(screen.getByText('Lorescape 故事體驗')).toBeInTheDocument()
})

test('/play/:slug 進入播放頁', () => {
  render(<MemoryRouter initialEntries={['/play/demo']}><AppRoutes /></MemoryRouter>)
  expect(screen.getByTestId('play-page')).toBeInTheDocument()
})
```

- [ ] **Step 3: 跑測試確認失敗**

Run: `npm test`　Expected: FAIL（AppRoutes 不存在）

- [ ] **Step 4: 最小實作**

`story/src/App.tsx`：

```tsx
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { HomePage } from './pages/HomePage'
import { PlayPage } from './pages/PlayPage'

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/play/:slug" element={<PlayPage />} />
    </Routes>
  )
}

export function App() {
  return <BrowserRouter><AppRoutes /></BrowserRouter>
}
```

`HomePage.tsx` 佔位：`<h1>Lorescape 故事體驗</h1>`；`PlayPage.tsx` 佔位：`<div data-testid="play-page" />`。`main.tsx` 掛載 `<App />` 並 import `styles/global.css`（先只放 `* { margin: 0; box-sizing: border-box; }` 與深色底）。

- [ ] **Step 5: 跑測試、build、commit**

Run: `npm test && npm run build`　Expected: PASS
（repo root pre-commit hook 只檢查 Dart，無影響。）

```bash
git add story && git commit -m "feat(story): scaffold 沉浸式故事體驗小站（Vite + React + vitest）"
```

---

### Task 3: 劇本 schema + 驗證 + demo 劇本

**Files:**
- Create: `story/src/engine/schema.ts`
- Create: `story/public/content/demo/script.json`、`story/public/content/demo/assets/`（佔位 SVG 素材）
- Test: `story/src/engine/schema.test.ts`

**Interfaces:**
- Produces:
  - `scriptSchema`（zod）、型別 `Script`, `ScriptNode`, `Character`, `CastMember`, `Choice`
  - `validateScript(data: unknown): Script` — zod 驗證 + 引用完整性檢查，失敗 throw `Error`（訊息含欄位路徑）
  - 之後所有 task 依賴的劇本型別（欄位如下，後續 task 不得改名）：

```ts
type Character = {
  id: string; name: string
  parts: { head: string; torso: string; leftArm: string; rightArm: string }
}
type CastMember = { character: string; position: 'left' | 'center' | 'right'; talking?: boolean }
type Choice = { text: string; to: string }
type ScriptNode = {
  id: string; background: string; bgm?: string
  cast?: CastMember[]; paragraphs: string[]           // min 1
  next?: string; choices?: Choice[]; ending?: { title: string }  // 三擇一
}
type Script = {
  slug: string; title: string; place: string; intro: string
  startNode: string; characters: Character[]; nodes: ScriptNode[]
}
```

- [ ] **Step 1: 寫失敗測試**

`story/src/engine/schema.test.ts`：

```ts
import { validateScript } from './schema'

const valid = {
  slug: 'demo', title: '測試故事', place: '測試地', intro: '你是一名學徒。',
  startNode: 'n1',
  characters: [{ id: 'master', name: '師傅', parts: {
    head: 'characters/master/head.png', torso: 'characters/master/torso.png',
    leftArm: 'characters/master/left-arm.png', rightArm: 'characters/master/right-arm.png' } }],
  nodes: [
    { id: 'n1', background: 'scenes/n1.png', bgm: 'audio/main.mp3',
      cast: [{ character: 'master', position: 'center', talking: true }],
      paragraphs: ['第一段', '第二段'], choices: [
        { text: '往左', to: 'end-a' }, { text: '往右', to: 'end-b' }] },
    { id: 'end-a', background: 'scenes/n1.png', paragraphs: ['結局A'], ending: { title: '結局A' } },
    { id: 'end-b', background: 'scenes/n1.png', paragraphs: ['結局B'], ending: { title: '結局B' } },
  ],
}

test('合法劇本通過並回傳型別化物件', () => {
  expect(validateScript(valid).startNode).toBe('n1')
})

test('startNode 不存在時 throw', () => {
  expect(() => validateScript({ ...valid, startNode: 'nope' })).toThrow(/startNode/)
})

test('choices 指向不存在節點時 throw', () => {
  const bad = structuredClone(valid)
  bad.nodes[0].choices![0].to = 'ghost'
  expect(() => validateScript(bad)).toThrow(/ghost/)
})

test('節點 next/choices/ending 必須恰好一個', () => {
  const bad = structuredClone(valid)
  delete (bad.nodes[2] as Record<string, unknown>).ending
  expect(() => validateScript(bad)).toThrow(/恰好一個/)
})

test('cast 引用未定義角色時 throw', () => {
  const bad = structuredClone(valid)
  bad.nodes[0].cast![0].character = 'ghost'
  expect(() => validateScript(bad)).toThrow(/ghost/)
})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `npm test -- schema`　Expected: FAIL（schema.ts 不存在）

- [ ] **Step 3: 實作 schema.ts**

```ts
import { z } from 'zod'

export const characterSchema = z.object({
  id: z.string().min(1), name: z.string().min(1),
  parts: z.object({ head: z.string(), torso: z.string(), leftArm: z.string(), rightArm: z.string() }),
})
export const castMemberSchema = z.object({
  character: z.string(), position: z.enum(['left', 'center', 'right']),
  talking: z.boolean().optional(),
})
export const choiceSchema = z.object({ text: z.string().min(1), to: z.string().min(1) })
export const nodeSchema = z.object({
  id: z.string().min(1), background: z.string().min(1), bgm: z.string().optional(),
  cast: z.array(castMemberSchema).optional(),
  paragraphs: z.array(z.string().min(1)).min(1),
  next: z.string().optional(),
  choices: z.array(choiceSchema).min(2).max(3).optional(),
  ending: z.object({ title: z.string().min(1) }).optional(),
})
export const scriptSchema = z.object({
  slug: z.string().min(1), title: z.string().min(1), place: z.string().min(1),
  intro: z.string().min(1), startNode: z.string().min(1),
  characters: z.array(characterSchema),
  nodes: z.array(nodeSchema).min(1),
})

export type Character = z.infer<typeof characterSchema>
export type CastMember = z.infer<typeof castMemberSchema>
export type Choice = z.infer<typeof choiceSchema>
export type ScriptNode = z.infer<typeof nodeSchema>
export type Script = z.infer<typeof scriptSchema>

export function validateScript(data: unknown): Script {
  const script = scriptSchema.parse(data)
  const nodeIds = new Set(script.nodes.map((n) => n.id))
  const charIds = new Set(script.characters.map((c) => c.id))
  if (!nodeIds.has(script.startNode)) throw new Error(`startNode 不存在：${script.startNode}`)
  for (const node of script.nodes) {
    const endCount = [node.next, node.choices, node.ending].filter((x) => x !== undefined).length
    if (endCount !== 1) throw new Error(`節點 ${node.id}：next/choices/ending 必須恰好一個`)
    if (node.next && !nodeIds.has(node.next)) throw new Error(`節點 ${node.id} 的 next 指向不存在節點：${node.next}`)
    for (const c of node.choices ?? [])
      if (!nodeIds.has(c.to)) throw new Error(`節點 ${node.id} 的選項指向不存在節點：${c.to}`)
    for (const m of node.cast ?? [])
      if (!charIds.has(m.character)) throw new Error(`節點 ${node.id} 引用未定義角色：${m.character}`)
  }
  return script
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `npm test -- schema`　Expected: PASS

- [ ] **Step 5: 建 demo 劇本與佔位素材**

`story/public/content/demo/script.json`：與測試 fixture 同構但擴為 4 節點（n1 → n2 有 next 線性推進、n2 有 2 選項、2 結局），文字用任意繁中佔位敘事。素材為手寫佔位 SVG（後續開發用，不需 Gemini）：

- `assets/scenes/n1.svg`、`n2.svg`：`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 1600"><rect width="900" height="1600" fill="#3a4a5a"/></svg>`（第二張換色 `#5a4a3a`）
- `assets/characters/master/{head,torso,left-arm,right-arm}.svg`：各為不同色塊矩形（例如 head 圓形 120×120、torso 200×300、雙臂 60×220），方便肉眼辨識部件動作。
- script.json 中的素材路徑對應改成 `.svg`。
- `assets/audio/` 先留空資料夾（加 `.gitkeep`）；demo 劇本不填 `bgm`。

- [ ] **Step 6: commit**

```bash
git add story && git commit -m "feat(story): 劇本 schema 驗證與 demo 佔位劇本"
```

---

### Task 4: 播放邏輯 player

**Files:**
- Create: `story/src/engine/player.ts`
- Test: `story/src/engine/player.test.ts`

**Interfaces:**
- Consumes: `Script`, `ScriptNode`（Task 3）
- Produces:

```ts
type PlayStatus = 'playing' | 'choosing' | 'ended'
type PlayState = { nodeId: string; paragraphIndex: number; status: PlayStatus }
function initState(script: Script): PlayState
function currentNode(script: Script, state: PlayState): ScriptNode
function advance(script: Script, state: PlayState): PlayState   // tap 推進
function choose(script: Script, state: PlayState, index: number): PlayState
```

規則：`advance` 段落未完 → `paragraphIndex + 1`；段落完且有 `next` → 跳該節點第 0 段；有 `choices` → `status: 'choosing'`（不動段落）；有 `ending` → `status: 'ended'`。`choose` 僅在 `choosing` 有效，跳到 `choices[index].to`；其他情況回傳原 state（純函式、不 mutate）。

- [ ] **Step 1: 寫失敗測試**

`story/src/engine/player.test.ts`（fixture 沿用 schema.test 的 `valid` 抽成共用檔 `story/src/test/fixtures.ts` export `demoScript`，schema.test 一併改用）：

```ts
import { initState, advance, choose, currentNode } from './player'
import { demoScript } from '../test/fixtures'

test('initState 從 startNode 第 0 段開始', () => {
  expect(initState(demoScript)).toEqual({ nodeId: 'n1', paragraphIndex: 0, status: 'playing' })
})

test('advance 推進段落', () => {
  const s = advance(demoScript, initState(demoScript))
  expect(s.paragraphIndex).toBe(1)
})

test('段落結束遇 choices 進入 choosing', () => {
  let s = initState(demoScript)
  s = advance(demoScript, s)  // 第二段
  s = advance(demoScript, s)  // 段落用盡 → choosing
  expect(s.status).toBe('choosing')
})

test('choose 跳到目標節點', () => {
  let s = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing' as const }
  s = choose(demoScript, s, 0)
  expect(s).toEqual({ nodeId: 'end-a', paragraphIndex: 0, status: 'playing' })
})

test('ending 節點段落用盡後 status ended', () => {
  let s = { nodeId: 'end-a', paragraphIndex: 0, status: 'playing' as const }
  s = advance(demoScript, s)
  expect(s.status).toBe('ended')
})

test('choosing 狀態下 advance 不動', () => {
  const s = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing' as const }
  expect(advance(demoScript, s)).toEqual(s)
})

test('currentNode 取得節點', () => {
  expect(currentNode(demoScript, initState(demoScript)).id).toBe('n1')
})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `npm test -- player`　Expected: FAIL

- [ ] **Step 3: 實作 player.ts**

```ts
import type { Script, ScriptNode } from './schema'

export type PlayStatus = 'playing' | 'choosing' | 'ended'
export type PlayState = { nodeId: string; paragraphIndex: number; status: PlayStatus }

export function initState(script: Script): PlayState {
  return { nodeId: script.startNode, paragraphIndex: 0, status: 'playing' }
}

export function currentNode(script: Script, state: PlayState): ScriptNode {
  const node = script.nodes.find((n) => n.id === state.nodeId)
  if (!node) throw new Error(`節點不存在：${state.nodeId}`)
  return node
}

export function advance(script: Script, state: PlayState): PlayState {
  if (state.status !== 'playing') return state
  const node = currentNode(script, state)
  if (state.paragraphIndex < node.paragraphs.length - 1)
    return { ...state, paragraphIndex: state.paragraphIndex + 1 }
  if (node.next) return { nodeId: node.next, paragraphIndex: 0, status: 'playing' }
  if (node.choices) return { ...state, status: 'choosing' }
  return { ...state, status: 'ended' }
}

export function choose(script: Script, state: PlayState, index: number): PlayState {
  if (state.status !== 'choosing') return state
  const node = currentNode(script, state)
  const target = node.choices?.[index]
  if (!target) return state
  return { nodeId: target.to, paragraphIndex: 0, status: 'playing' }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `npm test`　Expected: 全部 PASS（含改用 fixtures 的 schema.test）

- [ ] **Step 5: commit**

```bash
git add story && git commit -m "feat(story): 分支播放邏輯 player（advance/choose/ending）"
```

---

### Task 5: PlayPage 場景渲染：背景、文字卡、tap 推進、選項

**Files:**
- Create: `story/src/data/loadScript.ts`, `story/src/components/SceneView.tsx`, `story/src/components/TextCard.tsx`, `story/src/components/ChoiceList.tsx`, `story/src/styles/play.css`
- Modify: `story/src/pages/PlayPage.tsx`
- Test: `story/src/pages/PlayPage.test.tsx`

**Interfaces:**
- Consumes: `validateScript`（Task 3）、player（Task 4）
- Produces:
  - `loadScript(slug: string): Promise<Script>` — `fetch('/content/<slug>/script.json')` + `validateScript`
  - `assetUrl(slug: string, path: string): string` — 回傳 `/content/<slug>/assets/<path>`
  - `SceneView({ script, state, slug, onAdvance, onChoose, children })` — 佈局容器；`TextCard({ text, onTap })`；`ChoiceList({ choices, onChoose })`
  - PlayPage 流程：載入 → intro 畫面（「開始體驗」鈕，之後 Task 7 掛音訊解鎖）→ 逐段推進 → 選項 → `status === 'ended'` 時先顯示 `data-testid="ending"` 佔位（Task 12 替換）

- [ ] **Step 1: 寫失敗測試**

`story/src/pages/PlayPage.test.tsx`（mock `fetch` 回 demo fixture；用 `userEvent`）：

```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { vi, beforeEach } from 'vitest'
import { PlayPage } from './PlayPage'
import { demoScript } from '../test/fixtures'

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify(demoScript))))
})

function renderPlay() {
  return render(
    <MemoryRouter initialEntries={['/play/demo']}>
      <Routes><Route path="/play/:slug" element={<PlayPage />} /></Routes>
    </MemoryRouter>,
  )
}

test('載入後顯示 intro 與開始按鈕', async () => {
  renderPlay()
  expect(await screen.findByText('你是一名學徒。')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: '開始體驗' })).toBeInTheDocument()
})

test('開始後顯示第一段，tap 推進到第二段', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  expect(screen.getByText('第一段')).toBeInTheDocument()
  await userEvent.click(screen.getByTestId('text-card'))
  expect(screen.getByText('第二段')).toBeInTheDocument()
})

test('段落結束顯示選項，選擇後跳結局節點', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByRole('button', { name: '往左' }))
  expect(screen.getByText('結局A')).toBeInTheDocument()
})

test('結局段落結束後顯示 ending 佔位', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByRole('button', { name: '往左' }))
  await userEvent.click(screen.getByTestId('text-card'))
  expect(screen.getByTestId('ending')).toBeInTheDocument()
})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `npm test -- PlayPage`　Expected: FAIL

- [ ] **Step 3: 實作**

`loadScript.ts`：

```ts
import { validateScript, type Script } from '../engine/schema'

export async function loadScript(slug: string): Promise<Script> {
  const res = await fetch(`/content/${slug}/script.json`)
  if (!res.ok) throw new Error(`劇本載入失敗：HTTP ${res.status}`)
  return validateScript(await res.json())
}

export function assetUrl(slug: string, path: string): string {
  return `/content/${slug}/assets/${path}`
}
```

`PlayPage.tsx`（核心骨架）：

```tsx
import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { loadScript } from '../data/loadScript'
import { initState, advance, choose, currentNode, type PlayState } from '../engine/player'
import type { Script } from '../engine/schema'
import { SceneView } from '../components/SceneView'

export function PlayPage() {
  const { slug = '' } = useParams()
  const [script, setScript] = useState<Script | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [started, setStarted] = useState(false)
  const [state, setState] = useState<PlayState | null>(null)

  useEffect(() => {
    loadScript(slug).then(setScript).catch((e: Error) => setError(e.message))
  }, [slug])

  if (error) return <div data-testid="play-page">{error}</div>
  if (!script) return <div data-testid="play-page">載入中…</div>
  if (!started)
    return (
      <div data-testid="play-page" className="intro">
        <h1>{script.title}</h1>
        <p>{script.intro}</p>
        <button onClick={() => { setState(initState(script)); setStarted(true) }}>開始體驗</button>
      </div>
    )
  if (!state) return null
  return (
    <div data-testid="play-page">
      {state.status === 'ended'
        ? <div data-testid="ending">{currentNode(script, state).ending?.title}</div>
        : <SceneView
            script={script} state={state} slug={slug}
            onAdvance={() => setState(advance(script, state))}
            onChoose={(i) => setState(choose(script, state, i))}
          />}
    </div>
  )
}
```

`SceneView.tsx`：以 `currentNode` 取節點，`<div className="scene" style={{ backgroundImage: url(assetUrl(...)) }}>`，內含（依 `state.status`）`TextCard`（`data-testid="text-card"`，顯示 `node.paragraphs[state.paragraphIndex]`，onClick 呼叫 `onAdvance`）或 `ChoiceList`（每個選項一個 `<button>`）。`play.css`：`.scene` 滿版 `background-size: cover`、文字卡固定底部半透明深色圓角卡。

- [ ] **Step 4: 跑測試確認通過**

Run: `npm test`　Expected: PASS

- [ ] **Step 5: 手動確認 + commit**

Run: `npm run dev` → 開 `http://localhost:5173/play/demo` 走一遍 demo 劇本。

```bash
git add story && git commit -m "feat(story): PlayPage 場景渲染與分支推進"
```

---

### Task 6: CharacterSprite 紙娃娃動效

**Files:**
- Create: `story/src/components/CharacterSprite.tsx`, `story/src/styles/character.css`
- Modify: `story/src/components/SceneView.tsx`（渲染 cast）
- Test: `story/src/components/CharacterSprite.test.tsx`

**Interfaces:**
- Consumes: `Character`, `CastMember`（Task 3）、`assetUrl`（Task 5）
- Produces: `CharacterSprite({ character, member, slug }: { character: Character; member: CastMember; slug: string })`

DOM 結構與動效（純 CSS）：

```html
<div class="sprite sprite--center is-talking" data-testid="sprite-master">
  <img class="sprite__part sprite__arm-left"  src=".../left-arm.svg" alt="" />
  <img class="sprite__part sprite__arm-right" src=".../right-arm.svg" alt="" />
  <img class="sprite__part sprite__torso"     src=".../torso.svg" alt="" />
  <img class="sprite__part sprite__head"      src=".../head.svg" alt="" />
</div>
```

`character.css` 動效：`.sprite` 進場 `fade-slide-in 0.6s`；`.sprite__torso` 待機 `breathe 3.2s infinite`（scaleY 1→1.015）；`.sprite__arm-*` `sway 3.2s infinite`（rotate ±2deg，transform-origin 肩點）；`.is-talking .sprite__head` `nod 0.9s infinite`（translateY 0→2px + rotate 1deg）。站位 `.sprite--left/center/right` 以絕對定位排在場景下緣。

- [ ] **Step 1: 寫失敗測試**

```tsx
import { render, screen } from '@testing-library/react'
import { CharacterSprite } from './CharacterSprite'
import { demoScript } from '../test/fixtures'

const master = demoScript.characters[0]

test('渲染四個部件圖', () => {
  render(<CharacterSprite character={master} member={{ character: 'master', position: 'center' }} slug="demo" />)
  const sprite = screen.getByTestId('sprite-master')
  expect(sprite.querySelectorAll('img')).toHaveLength(4)
  expect(sprite.querySelector('.sprite__head')).toHaveAttribute(
    'src', '/content/demo/assets/characters/master/head.png')
})

test('talking 時掛 is-talking class；否則不掛', () => {
  const { rerender } = render(
    <CharacterSprite character={master} member={{ character: 'master', position: 'left', talking: true }} slug="demo" />)
  expect(screen.getByTestId('sprite-master')).toHaveClass('is-talking', 'sprite--left')
  rerender(<CharacterSprite character={master} member={{ character: 'master', position: 'left' }} slug="demo" />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-talking')
})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `npm test -- CharacterSprite`　Expected: FAIL

- [ ] **Step 3: 實作元件與 CSS**（依上述 DOM/動效規格；`SceneView` 對 `node.cast ?? []` 逐一渲染 `CharacterSprite`，key 為 character id）

- [ ] **Step 4: 跑測試確認通過**

Run: `npm test`　Expected: PASS

- [ ] **Step 5: 手動確認動效（dev server 看 demo 佔位部件會呼吸/擺動）+ commit**

```bash
git add story && git commit -m "feat(story): 紙娃娃 CharacterSprite 與待機/說話動效"
```

---

### Task 7: AudioManager

**Files:**
- Create: `story/src/audio/audioManager.ts`
- Modify: `story/src/pages/PlayPage.tsx`（開始按鈕呼叫 `unlock()`；節點 bgm 變化時 `playBgm`）
- Test: `story/src/audio/audioManager.test.ts`

**Interfaces:**
- Produces:

```ts
export class AudioManager {
  unlock(): void                 // 使用者手勢中呼叫；之後 play 才有效
  playBgm(src: string): void     // 同曲不重播；換曲 1s crossfade（舊 fade out 後 pause）
  playSfx(src: string): void     // 一次性播放
  stop(): void
}
export const audioManager: AudioManager  // 模組單例
```

- [ ] **Step 1: 寫失敗測試**（stub `Audio`）

```ts
import { vi, beforeEach, test, expect } from 'vitest'
import { AudioManager } from './audioManager'

class FakeAudio {
  static instances: FakeAudio[] = []
  src: string; volume = 1; loop = false; paused = true
  play = vi.fn(async () => { this.paused = false })
  pause = vi.fn(() => { this.paused = true })
  constructor(src: string) { this.src = src; FakeAudio.instances.push(this) }
}

beforeEach(() => {
  FakeAudio.instances = []
  vi.stubGlobal('Audio', FakeAudio)
  vi.useFakeTimers()
})

test('未 unlock 前 playBgm 不播放', () => {
  const am = new AudioManager()
  am.playBgm('/a.mp3')
  expect(FakeAudio.instances).toHaveLength(0)
})

test('unlock 後 playBgm 播放且 loop', () => {
  const am = new AudioManager()
  am.unlock(); am.playBgm('/a.mp3')
  expect(FakeAudio.instances[0].loop).toBe(true)
  expect(FakeAudio.instances[0].play).toHaveBeenCalled()
})

test('同曲重複呼叫不重播', () => {
  const am = new AudioManager()
  am.unlock(); am.playBgm('/a.mp3'); am.playBgm('/a.mp3')
  expect(FakeAudio.instances).toHaveLength(1)
})

test('換曲 crossfade 後舊曲 pause', () => {
  const am = new AudioManager()
  am.unlock(); am.playBgm('/a.mp3'); am.playBgm('/b.mp3')
  vi.advanceTimersByTime(1100)
  expect(FakeAudio.instances[0].pause).toHaveBeenCalled()
  expect(FakeAudio.instances[1].play).toHaveBeenCalled()
})
```

- [ ] **Step 2: 跑測試確認失敗**　Run: `npm test -- audio`

- [ ] **Step 3: 實作**：`unlock()` 設 `unlocked = true`；`playBgm` 未解鎖或同 src 直接 return；crossfade 用 `setInterval` 每 100ms 調 volume（舊 -0.1、新 +0.1），1s 後 clear + 舊曲 `pause()`；`playSfx` 建新 `Audio` 播放即棄。PlayPage：開始按鈕 handler 加 `audioManager.unlock()`；`useEffect` 監聽 `currentNode(script, state).bgm`，有值就 `playBgm(assetUrl(slug, bgm))`。

- [ ] **Step 4: 跑測試確認通過**　Run: `npm test`　Expected: PASS

- [ ] **Step 5: commit**

```bash
git add story && git commit -m "feat(story): AudioManager 音訊解鎖與 BGM crossfade"
```

---

### Task 8: 進度保存與續玩

**Files:**
- Create: `story/src/data/progress.ts`
- Modify: `story/src/pages/PlayPage.tsx`
- Test: `story/src/data/progress.test.ts`, `story/src/pages/PlayPage.test.tsx`（新增續玩測試）

**Interfaces:**
- Consumes: `PlayState`（Task 4）
- Produces:

```ts
function saveProgress(slug: string, state: PlayState): void      // localStorage key: `story-progress:<slug>`
function loadProgress(slug: string): PlayState | null            // 壞資料回 null
function clearProgress(slug: string): void
```

- [ ] **Step 1: 寫失敗測試**

`progress.test.ts`：save 後 load 相等；load 不存在回 null；localStorage 存壞 JSON 回 null；clear 後回 null。
`PlayPage.test.tsx` 新增：

```tsx
test('有進度時 intro 顯示「繼續上次」且從存檔恢復', async () => {
  localStorage.setItem('story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 1, status: 'playing' }))
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '繼續上次' }))
  expect(screen.getByText('第二段')).toBeInTheDocument()
})

test('ended 時清除進度', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  // …走到結局（同 Task 5 的操作序列）…
  expect(localStorage.getItem('story-progress:demo')).toBeNull()
})
```

（測試檔 `beforeEach` 加 `localStorage.clear()`。）

- [ ] **Step 2: 跑測試確認失敗**　Run: `npm test -- progress PlayPage`

- [ ] **Step 3: 實作**：progress.ts 用 try/catch 包 `JSON.parse`；PlayPage：每次 `setState` 後（`useEffect` 監聽 state）`saveProgress`；`status === 'ended'` 時 `clearProgress`；intro 畫面若 `loadProgress` 有值，主按鈕文字改「繼續上次」（沿用存檔 state），下方加次要「從頭開始」鈕（clear + initState）。

- [ ] **Step 4: 跑測試確認通過**　Run: `npm test`

- [ ] **Step 5: commit**

```bash
git add story && git commit -m "feat(story): 進度保存與續玩"
```

---### Task 9: 素材預載與錯誤重試

**Files:**
- Create: `story/src/data/preload.ts`
- Modify: `story/src/pages/PlayPage.tsx`
- Test: `story/src/data/preload.test.ts`, `story/src/pages/PlayPage.test.tsx`（載入失敗重試測試）

**Interfaces:**
- Consumes: `Script`, `assetUrl`
- Produces: `preloadNode(script: Script, slug: string, nodeId: string): void` — 對該節點與其所有直接後繼節點（next / 每個 choice.to）的 `background` 各建一個 `new Image()` 設 `src`（fire-and-forget，重複呼叫靠模組內 `Set` 去重）。

- [ ] **Step 1: 寫失敗測試**

`preload.test.ts`：stub `Image`（如 Task 7 的 FakeAudio 模式，收集 instances），驗證：(1) 對 n1 呼叫會載入 n1 與 end-a/end-b 的背景；(2) 重複呼叫不重載。
`PlayPage.test.tsx` 新增：fetch mock 先回 500 → 顯示錯誤與「重试」按鈕（文案「重新載入」）；點擊後 fetch 改回 200 → 正常顯示 intro。

- [ ] **Step 2: 跑測試確認失敗**　Run: `npm test -- preload PlayPage`

- [ ] **Step 3: 實作**：preload.ts 如規格；PlayPage 的 error 分支加「重新載入」按鈕（重跑 `loadScript`）；`useEffect` 監聽 `state?.nodeId`，呼叫 `preloadNode`。

- [ ] **Step 4: 跑測試確認通過**　Run: `npm test`

- [ ] **Step 5: commit**

```bash
git add story && git commit -m "feat(story): 節點素材預載與載入錯誤重試"
```

---

### Task 10: Supabase migrations（story_events / story_surveys）

**Files:**
- Create: `supabase/migrations/20260806000000_create_story_demo_tables.sql`

**Interfaces:**
- Produces: 兩張表供 Task 11 寫入；anon **insert-only**。

- [ ] **Step 1: 寫 migration**

```sql
-- 沉浸式故事體驗 demo 的匿名回收表。
-- 前端（story.lorescape.app）以 anon key 直寫；insert-only，禁止讀取，
-- 分析一律走 service role（本地腳本）。
CREATE TABLE IF NOT EXISTS public.story_events (
  id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  story_slug TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN (
    'start', 'node_enter', 'choice_made', 'ending_reached', 'survey_submitted'
  )),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.story_surveys (
  id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  story_slug TEXT NOT NULL,
  answers JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.story_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_surveys ENABLE ROW LEVEL SECURITY;

CREATE POLICY story_events_anon_insert ON public.story_events
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY story_surveys_anon_insert ON public.story_surveys
  FOR INSERT TO anon WITH CHECK (true);

GRANT INSERT ON public.story_events TO anon;
GRANT INSERT ON public.story_surveys TO anon;
```

- [ ] **Step 2: 套用並驗證**

依現有流程 `supabase db push`（或使用者慣用的套用方式）。驗證：用 anon key `curl -X POST "$SUPABASE_URL/rest/v1/story_events"` 插一筆測試列成功（`Prefer: return=minimal`）；用 anon key GET 同表應得 0 列/權限拒絕。測試列以 service role 刪除。

- [ ] **Step 3: commit**

```bash
git add supabase && git commit -m "feat(supabase): 故事 demo 事件與問卷表（anon insert-only）"
```

---

### Task 11: analytics client（事件埋點）

**Files:**
- Create: `story/src/data/analytics.ts`
- Modify: `story/src/pages/PlayPage.tsx`（埋 start / node_enter / choice_made / ending_reached）
- Test: `story/src/data/analytics.test.ts`

**Interfaces:**
- Consumes: Task 10 的表結構
- Produces:

```ts
type StoryEventType = 'start' | 'node_enter' | 'choice_made' | 'ending_reached' | 'survey_submitted'
function getSessionId(): string   // sessionStorage 'story-session-id'，無則 crypto.randomUUID() 產生
function trackEvent(slug: string, type: StoryEventType, payload?: Record<string, unknown>): void
  // fire-and-forget：內部 insert 失敗只 console.warn，不 throw
function submitSurvey(slug: string, answers: Record<string, unknown>): Promise<boolean>
  // 成功 true / 失敗 false；成功後同時 trackEvent('survey_submitted')
```

Supabase client：模組內以 `import.meta.env.VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY` 建立；env 缺值時所有函式靜默 no-op（本地 dev 不設 env 也能玩）。

- [ ] **Step 1: 寫失敗測試**

`analytics.test.ts`：`vi.mock('@supabase/supabase-js')` 讓 `createClient` 回傳 `{ from: vi.fn(() => ({ insert: insertMock })) }`；設 `vi.stubEnv('VITE_SUPABASE_URL', 'http://x')` 等。測：(1) `getSessionId` 兩次呼叫相同、清 sessionStorage 後不同；(2) `trackEvent` 呼叫 `from('story_events').insert` 且帶 session_id/story_slug/event_type/payload；(3) insert reject 時不 throw；(4) `submitSurvey` 成功回 true 並追加 survey_submitted 事件；(5) env 缺值時 no-op（`createClient` 未被呼叫）。

- [ ] **Step 2: 跑測試確認失敗**　Run: `npm test -- analytics`

- [ ] **Step 3: 實作 + PlayPage 埋點**

PlayPage：開始按鈕 → `trackEvent(slug, 'start')`；state.nodeId 變化的 `useEffect` → `node_enter`（payload `{ node: nodeId }`）；`choose` 包一層 handler → `choice_made`（payload `{ node, index, text }`）；`status === 'ended'` 首次 → `ending_reached`（payload `{ node }`）。

- [ ] **Step 4: 跑測試確認通過**　Run: `npm test`

- [ ] **Step 5: commit**

```bash
git add story && git commit -m "feat(story): 匿名事件埋點（fire-and-forget）"
```

---

### Task 12: 結局頁 + 問卷 + 感謝頁

**Files:**
- Create: `story/src/components/EndingView.tsx`, `story/src/components/SurveyForm.tsx`, `story/src/styles/ending.css`
- Modify: `story/src/pages/PlayPage.tsx`（`data-testid="ending"` 佔位換成 EndingView 流程）
- Test: `story/src/components/SurveyForm.test.tsx`, `story/src/pages/PlayPage.test.tsx`（結局流程改測 EndingView）

**Interfaces:**
- Consumes: `submitSurvey`（Task 11）
- Produces:
  - `EndingView({ endingTitle, slug })` — 三階段：結局標題卡（「你走到了：<title>」+「留下你的感受」鈕）→ `SurveyForm` → 感謝頁（IG 連結 `https://www.instagram.com/lorescape.app/`，文案「追蹤 IG，下週有新故事」+「再玩一次」連結回 `/play/<slug>`）
  - `SurveyForm({ onSubmit }: { onSubmit: (answers: Record<string, unknown>) => Promise<boolean> })`

問卷欄位（answers keys 固定，Task 22 分析依賴）：
`immersion`（1–5 radio，必答）、`weekly_interest`（'yes'|'maybe'|'no' radio，必答）、`memorable`（textarea，必答）、`pay_intent`（'yes'|'depends'|'no' radio，選答）、`ig_handle`（text，選答）。未填必答項時送出鈕 disabled。

- [ ] **Step 1: 寫失敗測試**

`SurveyForm.test.tsx`：(1) 必答未填時送出鈕 disabled；(2) 填齊必答後 enabled，送出時 `onSubmit` 收到正確 answers 物件；(3) onSubmit 回 false 顯示「送出失敗，再試一次」。
`PlayPage.test.tsx`：結局 → 點「留下你的感受」→ 出現問卷 → 送出（mock submitSurvey 回 true）→ 顯示感謝頁與 IG 連結。

- [ ] **Step 2: 跑測試確認失敗**　Run: `npm test -- Survey PlayPage`

- [ ] **Step 3: 實作**（表單用 controlled state；radio group 用 fieldset+legend 保無障礙；感謝頁 IG 連結 `target="_blank" rel="noopener"`）

- [ ] **Step 4: 跑測試確認通過**　Run: `npm test`

- [ ] **Step 5: commit**

```bash
git add story && git commit -m "feat(story): 結局頁、內建問卷與感謝頁"
```

---

### Task 13: HomePage + 手機版型 polish

**Files:**
- Create: `story/src/data/catalog.ts`, `story/src/styles/home.css`
- Modify: `story/src/pages/HomePage.tsx`, `story/src/styles/global.css`, `story/src/styles/play.css`
- Test: `story/src/pages/HomePage.test.tsx`

**Interfaces:**
- Produces: `catalog: { slug: string; title: string; place: string; blurb: string }[]`（手動維護的劇本清單，週更時往上加；demo 劇本不列入）。HomePage 渲染劇本卡片連到 `/play/<slug>`。

- [ ] **Step 1: 寫失敗測試**：catalog 塞一筆測試資料時 HomePage 顯示該劇本卡與連結 href。
- [ ] **Step 2: 跑測試確認失敗**　Run: `npm test -- HomePage`
- [ ] **Step 3: 實作**：HomePage 標題 + 一句站台說明（「用第二人稱走進歷史現場」）+ 劇本卡片列表；版型：深色底、桌機 `max-width: 480px` 置中（模擬手機直式）、`.scene` 用 `100dvh`；統一字體（system font stack + 思源黑體 fallback）。
- [ ] **Step 4: 跑測試確認通過**　Run: `npm test && npm run build`
- [ ] **Step 5: commit**

```bash
git add story && git commit -m "feat(story): 首頁劇本選單與手機版型"
```

---

### Task 14: Firebase multi-site + deploy-story.yml + CI

**Files:**
- Modify: `firebase.json`（hosting 改陣列 + targets）、`.firebaserc`（target 對映）、`.github/workflows/deploy-landing.yml`（deploy step 加 `target: landing`）
- Create: `.github/workflows/deploy-story.yml`
- Modify: `.github/workflows/ci.yml`（加 story job：npm ci + test + build）

**Interfaces:**
- Consumes: Task 2 的 build 產物 `story/dist`
- Produces: 手動觸發即可部署 story 站；CI 對 story 跑測試。

- [ ] **Step 1: 一次性建立 Hosting site（手動）**

```bash
firebase hosting:sites:create story-lorescape --project instant-explore-7b442
```

（site id 若被占用改 `lorescape-story` 並同步後續設定。）Firebase console → Hosting → story site → 新增自訂網域 `story.lorescape.app`，依指示到 DNS 加 A/TXT 記錄（此步需使用者操作網域 DNS）。

- [ ] **Step 2: 改 firebase.json / .firebaserc**

`firebase.json` 的 `hosting` 改為陣列：原設定加上 `"target": "landing"` 為第一個元素；第二個元素：

```json
{
  "target": "story",
  "public": "story/dist",
  "ignore": ["firebase.json", "**/node_modules/**"],
  "rewrites": [{ "source": "**", "destination": "/index.html" }],
  "headers": [
    { "source": "**/*.@(js|css|png|svg|webp|mp3)",
      "headers": [{ "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }] },
    { "source": "**/*.@(html|json)",
      "headers": [{ "key": "Cache-Control", "value": "public, max-age=300" }] }
  ],
  "cleanUrls": true
}
```

`.firebaserc`：

```json
{
  "projects": { "default": "instant-explore-7b442" },
  "targets": {
    "instant-explore-7b442": {
      "hosting": { "landing": ["instant-explore-7b442"], "story": ["story-lorescape"] }
    }
  }
}
```

- [ ] **Step 3: deploy-landing.yml 加 target**

deploy step 的 `with:` 增加 `target: landing`（否則 hosting 陣列化後 action 不知道部署哪個）。

- [ ] **Step 4: 建 deploy-story.yml**

```yaml
name: Deploy Story
on:
  workflow_dispatch:

jobs:
  deploy-story:
    name: Deploy Story to Firebase Hosting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { ref: master }
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
          cache-dependency-path: story/package-lock.json
      - name: Install dependencies
        working-directory: story
        run: npm ci --no-audit --no-fund
      - name: Test
        working-directory: story
        run: npm test
      - name: Build
        working-directory: story
        env:
          VITE_SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          VITE_SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
        run: npm run build
      - name: Deploy to Firebase Hosting (live)
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_INSTANT_EXPLORE_7B442 }}
          channelId: live
          projectId: instant-explore-7b442
          target: story
```

（secrets 沿用 landing 既有的三個，無需新增。`SUPABASE_ANON_KEY` 若現有 secret 名不同，以 repo settings 實際為準。）

- [ ] **Step 5: ci.yml 加 story job**

比照既有 job 風格新增：

```yaml
  story:
    name: Story site tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: "npm"
          cache-dependency-path: story/package-lock.json
      - run: npm ci --no-audit --no-fund
        working-directory: story
      - run: npm test
        working-directory: story
      - run: npm run build
        working-directory: story
```

（若 ci.yml 有 path filter 慣例，加上 `story/**`。）

- [ ] **Step 6: 驗證與 commit**

本地 `cd story && npm run build && firebase deploy --only hosting:story` 打一次確認 multi-site 設定正確、landing 不受影響（`firebase deploy --only hosting:landing` dry 檢查 public 路徑仍對）。開 `https://story-lorescape.web.app/play/demo` 走一遍。

```bash
git add firebase.json .firebaserc .github && git commit -m "chore(story): Firebase multi-site 與 story 站部署/CI workflow"
```

---

### Task 15: 場景圖生成腳本（scripts/story_assets）

**Files:**
- Create: `scripts/story_assets/__init__.py`, `scripts/story_assets/manifest.py`, `scripts/story_assets/gemini.py`, `scripts/story_assets/generate.py`
- Create: `scripts/story_assets_gen.py`（CLI 入口）
- Test: `scripts/tests/test_story_assets_manifest.py`, `scripts/tests/test_story_assets_generate.py`

**Interfaces:**
- Produces:
  - 劇本旁新增 `art.json`（與 script.json 同層，格式如下；Task 18 一起撰寫）：

```json
{
  "style": "clean cel-shaded illustration, bold clean outlines, flat colors with soft shading, dramatic lighting, vertical composition",
  "scenes": { "scenes/n1.png": "1890s Kyoto street at dusk, ..." },
  "characters": { "master": "middle-aged craftsman, indigo work clothes, ..." }
}
```

  - `manifest.py`：

```python
@dataclass
class SceneJob:
    rel_path: str   # e.g. "scenes/n1.png"
    prompt: str     # style + scene prompt 合成
def load_scene_jobs(content_dir: Path) -> list[SceneJob]
    # 讀 script.json 所有 node.background 與 art.json；
    # background 缺 prompt 或 prompt 無對應 background → raise ValueError
```

  - `gemini.py`：

```python
IMAGE_MODEL = "gemini-2.5-flash-image"
def generate_image(client, prompt: str, reference_png: bytes | None = None) -> bytes
    # generate_content(model=IMAGE_MODEL, contents=[prompt] (+ reference Part))，
    # 取第一個 inline_data 回傳 bytes；無圖像 part → raise RuntimeError
```

  - `generate.py`：`run_scenes(content_dir, client, only: str | None)` — 逐 job 生成寫入 `assets/<rel_path>`；檔案已存在則跳過（`--force` 覆蓋）；`only` 過濾單一 rel_path。
  - CLI：`uv run python story_assets_gen.py scenes --slug <slug> [--only scenes/n1.png] [--force]`（content dir 定為 `../story/public/content/<slug>`；`GEMINI_API_KEY` 由 `.env` 載入，沿用 scripts 的 dotenv 慣例）。

- [ ] **Step 1: 寫失敗測試**

`test_story_assets_manifest.py`：tmp_path 建 script.json（兩節點）+ art.json；(1) 回傳兩個 SceneJob 且 prompt = style + ", " + scene prompt；(2) art.json 缺某 background 的 prompt → ValueError 訊息含該路徑；(3) art.json 有多餘 scene key → ValueError。
`test_story_assets_generate.py`：fake client（`generate_content` 回帶 `inline_data.data=b'png'` 的假 response 物件）；(1) `run_scenes` 寫出檔案內容 `b'png'`；(2) 已存在時跳過不呼叫 client；(3) `force=True` 覆蓋；(4) response 無 inline_data → RuntimeError。

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd scripts && uv run pytest tests/test_story_assets_manifest.py tests/test_story_assets_generate.py -v`　Expected: FAIL

- [ ] **Step 3: 實作四個模組與 CLI**（gemini.py 的 reference 用 `types.Part.from_bytes(data=reference_png, mime_type='image/png')`；CLI 用 argparse，client 以 `genai.Client(api_key=os.environ['GEMINI_API_KEY'])` 建立——沿用 `google-genai`，已在 publisher 依賴中，scripts 透過 lorescape-publisher 取得；若 import 失敗則在 scripts pyproject dependencies 明列 `google-genai>=1,<2` 後 `uv sync`）

- [ ] **Step 4: 跑測試確認通過**

Run: `cd scripts && uv run pytest -v`　Expected: PASS（既有測試也不能壞）

- [ ] **Step 5: commit**

```bash
git add scripts && git commit -m "feat(scripts): 故事場景圖 Gemini 生成產線"
```

---

### Task 16: 角色部件生成 + 去背切件

**Files:**
- Create: `scripts/story_assets/characters.py`, `scripts/story_assets/cutout.py`
- Modify: `scripts/story_assets_gen.py`（加 `characters` 子命令）
- Test: `scripts/tests/test_story_assets_cutout.py`, `scripts/tests/test_story_assets_characters.py`

**Interfaces:**
- Consumes: `generate_image`（Task 15）、art.json 的 `characters` 段、script.json 的 `characters[].parts`
- Produces:
  - `cutout.py`：

```python
MAGENTA = (255, 0, 255)
def chroma_key(png_bytes: bytes, threshold: int = 60) -> bytes
    # RGBA 化；與 MAGENTA 的歐氏距離 < threshold 的像素 alpha=0；
    # 依不透明像素 bbox 裁切；回傳 PNG bytes
```

  - `characters.py`：`run_characters(content_dir, client, only: str | None)`：
    1. 每角色先生成全身參考圖 `assets/characters/<id>/_reference.png`（prompt = style + 角色 prompt + "full body, front facing, standing, plain solid magenta background #FF00FF, single character, no text"）。
    2. 以參考圖為 reference，對四部件各呼叫一次 `generate_image`（prompt 模板：`"ONLY the {part} of this exact character, same style and colors, nothing else, centered, plain solid magenta background #FF00FF"`，part ∈ head / torso / left arm / right arm）→ `chroma_key` → 寫入 script.json `parts` 宣告的對應路徑。
    3. 已存在跳過 / `--force` 覆蓋 / `only` 過濾 `<id>` 或 `<id>:head`。

- [ ] **Step 1: 寫失敗測試**

`test_story_assets_cutout.py`：用 Pillow 現做 10×10 測試圖（洋紅底 + 中央 4×4 紅方塊）→ chroma_key 後：(1) PNG 尺寸為 4×4（bbox 裁切）；(2) 全部像素不透明且為紅色；(3) 全洋紅圖 → raise ValueError（無前景）。
`test_story_assets_characters.py`：fake client 記錄呼叫；(1) 一角色共 5 次生成呼叫（1 參考 + 4 部件），部件檔案落在 script.json 宣告路徑；(2) 部件 prompt 含 "ONLY the head"；(3) 參考圖已存在時不重生參考、只生缺的部件。

- [ ] **Step 2: 跑測試確認失敗**　Run: `cd scripts && uv run pytest tests/test_story_assets_cutout.py tests/test_story_assets_characters.py -v`

- [ ] **Step 3: 實作**（fake 部件圖在測試中直接用 cutout 測試同款洋紅底 PNG bytes）

- [ ] **Step 4: 跑測試確認通過**　Run: `cd scripts && uv run pytest -v`

- [ ] **Step 5: commit**

```bash
git add scripts && git commit -m "feat(scripts): 角色部件生成與洋紅 chroma-key 去背"
```

---

### Task 17: 素材齊備檢查器

**Files:**
- Create: `scripts/story_assets/check.py`
- Modify: `scripts/story_assets_gen.py`（加 `check` 子命令）
- Test: `scripts/tests/test_story_assets_check.py`

**Interfaces:**
- Consumes: script.json 結構
- Produces: `check_content(content_dir: Path) -> list[str]` — 回傳缺漏清單（空 = 通過）：所有 `node.background`、`node.bgm`、`characters[].parts.*` 對應檔案存在於 `assets/`。CLI `check --slug <slug>` 缺漏時列出並 exit 1。

- [ ] **Step 1: 寫失敗測試**：tmp 內容齊全 → 空 list；刪一個部件檔 → 清單含該路徑；bgm 未填的節點不要求音檔。
- [ ] **Step 2: 跑測試確認失敗**　Run: `cd scripts && uv run pytest tests/test_story_assets_check.py -v`
- [ ] **Step 3: 實作**
- [ ] **Step 4: 跑測試確認通過**　Run: `cd scripts && uv run pytest -v`
- [ ] **Step 5: commit**

```bash
git add scripts && git commit -m "feat(scripts): 劇本素材齊備檢查器"
```

---

### Task 18: 劇本撰寫（選定故事 → script.json + art.json）

**型態：** 內容/互動任務（與使用者協作，人工審稿）。

**Files:**
- Create: `story/public/content/<正式 slug>/script.json`, `.../art.json`
- Modify: `story/src/data/catalog.ts`（上架該劇本）

- [ ] **Step 1: 依 Task 1 選定的故事寫劇本大綱**：虛構小人物主角設定、8–12 節點流程圖（含 2–3 選擇點、2 結局）、每節點場景與出場 NPC（1–3 個）。給使用者確認大綱。
- [ ] **Step 2: 寫全文**：第二人稱敘事，每節點 2–5 段、每段 40–90 字（手機文字卡一屏內）；史實錨點以原 daily story 與 Wikipedia 為準，虛構情節不得篡改史實結局。
- [ ] **Step 3: 寫 art.json**：整體 style prompt（cel-shaded 規格，鎖定使用者參考圖風格描述）+ 每場景 prompt + 每角色 prompt（外觀、服裝、年代考據）。
- [ ] **Step 4: 驗證**：`npm test` 不管內容，但手動跑一段 Node 腳本或在 dev server 載入 `/play/<slug>` 確認 `validateScript` 通過；`uv run python story_assets_gen.py check --slug <slug>` 此時會列出全部缺漏素材（預期，清單即 Task 19 的工作量）。
- [ ] **Step 5: 使用者審稿後 commit**

```bash
git add story && git commit -m "feat(story): <地點>劇本《<標題>》"
```

---

### Task 19: 素材產出與驗收

**型態：** 內容/互動任務（跑產線 + 人工挑選）。

- [ ] **Step 1: 生場景圖**：`uv run python story_assets_gen.py scenes --slug <slug>`；逐張人工過目，不滿意的 `--only <path> --force` 重生（必要時微調 art.json prompt）。
- [ ] **Step 2: 生角色**：`... characters --slug <slug>`；先驗收 `_reference.png`（風格是否貼近使用者參考圖），OK 才續生部件；部件去背品質不佳時調 threshold 或重生。
- [ ] **Step 3: 在 dev server 檢視**：`/play/<slug>` 走一遍，確認部件組裝比例與站位自然（必要時在 script.json 加站位微調或改 CSS 部件錨點）。
- [ ] **Step 4: 挑 BGM/音效**：從免費授權音庫（Pixabay Music / FreePD，比照 `marketing/sound/` 的做法與授權紀錄）挑 1–2 首 BGM 與翻頁/選擇音效，放入 `assets/audio/`，script.json 填 `bgm`。授權來源記在該資料夾 `SOURCES.md`。
- [ ] **Step 5: 齊備檢查 + commit**：`story_assets_gen.py check --slug <slug>` 通過；`npm test && npm run build`。

```bash
git add story && git commit -m "feat(story): 《<標題>》場景與角色素材"
```

---

### Task 20: 部署上線 + 全分支走測

**型態：** ops。

- [ ] **Step 1:** GitHub Actions 手動觸發 `Deploy Story`。
- [ ] **Step 2:** 手機實機開 `https://story.lorescape.app/play/<slug>`：走完**所有分支路徑**（照 script.json 畫出的分支樹逐條走），檢查：文字斷行、部件動效、BGM 播放與切換、選擇後跳轉、結局 → 問卷 → 感謝頁。
- [ ] **Step 3:** 驗數據：Supabase 後台（service role）確認 story_events 有本次走測的事件、story_surveys 有測試問卷；刪除測試資料。
- [ ] **Step 4:** demo 佔位劇本此時從 catalog 隱藏（`/play/demo` 仍可直連，首頁不列）。有改動則 commit。

---

### Task 21: IG 邀請素材與發布

**型態：** 內容/互動任務。

- [ ] **Step 1:** 撰寫 IG 貼文 + 限動文案（品牌語氣依 `MARKETING.md`；hook 圍繞「第二人稱走進歷史現場」+ 邀請當測試員），視覺用劇本場景圖做 1–3 張卡。
- [ ] **Step 2:** 跑 marketing-gate skill 品質檢查，過關才發。
- [ ] **Step 3:** 使用者確認後發布（貼文 + 限動連結貼紙指向 `https://story.lorescape.app`）。發布本身走現有 IG 流程，由使用者或 publish 工具執行。

---

### Task 22: Feedback 匯總 + go/no-go

**型態：** 內容/互動任務（邀請後累積約一週執行）。

- [ ] **Step 1:** 以 service role 撈 `story_events` / `story_surveys`（唯讀 REST，同 Task 1 方式）。
- [ ] **Step 2:** 計算對照判準：開始人數（distinct session with `start`）≥30；完成率（`ending_reached`/`start`）≥50%；`immersion` 平均 ≥4.0；`weekly_interest` 中 `yes` 佔比 ≥40%。另整理：流失節點分布（各 session 最後 `node_enter`）、選擇分布、`memorable` 開放題摘要、`pay_intent` 分布。
- [ ] **Step 3:** 產出 go/no-go 報告給使用者（含未達標時的調整建議），結論由使用者定奪。

---

## Self-Review 紀錄

- Spec 覆蓋：spec 執行順序 1–6 對映 Task 1 / 3+18 / 15–17+19 / 2–14 / 21 / 22；問卷五題對映 Task 12 的 answers keys；判準數字對映 Task 22。無缺口。
- Placeholder 掃描：內容/互動任務（1、18、19、21、22）之步驟為操作指令與驗收條件，非程式碼佔位；code task 均附實碼或明確規格。
- 型別一致性：`PlayState`/`validateScript`/`assetUrl`/`trackEvent`/`submitSurvey` 等簽名在 Interfaces 區塊統一，後續 task 引用相同名稱。
