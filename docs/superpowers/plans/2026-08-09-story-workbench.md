# Story 工作台（/editor）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 story Vite 專案內建 dev-only 工作台 `/editor`，可編輯劇本文本、分支結構（React Flow）、角色骨骼定位（layout.json 資料驅動）、背景與部件素材，並與磁碟雙向即時同步。

**Architecture:** 先把骨骼定位從「烤進 PNG」遷移為 `layout.json` 資料 + 播放器執行時定位（Phase A）；catalog 遷入 `content/index.json`（Phase B）；Vite plugin 提供 `/__editor/*` 讀寫 API + chokidar/SSE（Phase C）；`/editor` React UI 三欄式（Phase D）。磁碟是唯一真相，工作台即時自動存（debounce）、外部改動經 SSE 推播即時反映。

**Tech Stack:** Vite 7 + React 19 + TypeScript strict、zod、vitest（globals: true、jsdom；plugin 測試用 node 環境）、@xyflow/react（節點圖）、@dnd-kit/core + @dnd-kit/sortable（清單拖拉）、chokidar（vite 自帶依賴）、Python/Pillow（一次性遷移腳本，scripts/ uv 專案）。

**Spec:** `docs/superpowers/specs/2026-08-09-story-workbench-design.md`

## Global Constraints

- 一律在 `story/` 目錄下用 npm 指令（`npm test`、`npm run build`）；scripts/ 下用 `uv run`。
- UI 文案與註解用繁體中文（技術名詞除外）。
- TypeScript strict；`npm run build`（含 tsc -b）必須綠。
- editor 相關程式碼（`src/editor/**`、@xyflow/react、@dnd-kit）不得進 production bundle：路由以 `import.meta.env.DEV` 守衛 + `React.lazy` 動態 import。
- 所有寫入磁碟的內容必須先過 zod/validateScript/validateLayout 驗證，驗證不過回 400、不落盤。
- 內容檔路徑格式不變：`story/public/content/<slug>/{script.json,art.json,layout.json,assets/**}`；新增 `story/public/content/index.json`。
- 完成 Phase A 遷移時 `CONTENT_VERSION` bump 為 `'4'`。
- pngquant 為選配：伺服端找不到執行檔時跳過壓縮並在回應註明，不得失敗。
- 測試檔鏡射 src 結構；vitest `globals: true`（不需 import test/expect，但現有檔案有 import 也不強制移除）。

---

## Phase A：骨骼資料化

### Task 1: layout schema 與 validateLayout

**Files:**
- Modify: `story/src/engine/schema.ts`
- Test: `story/src/engine/schema.test.ts`（既有檔案，追加測試）

**Interfaces:**
- Consumes: 既有 `scriptSchema`、`Script`。
- Produces:
  ```ts
  export const partLayoutSchema: z.ZodObject  // { cx, top, height }
  export const layoutSchema: z.ZodObject
  export type PartLayout = { cx: number; top: number; height: number }
  export type Layout = {
    canvas: { width: number; height: number }
    characters: Record<string, { head: PartLayout; torso: PartLayout; leftArm: PartLayout; rightArm: PartLayout }>
  }
  export function validateLayout(data: unknown, script?: Script): Layout
  ```
  `validateLayout` 傳入 `script` 時，script.characters 每個 id 都必須存在於 layout.characters，缺了丟 `Error("layout.json 缺角色：<id>")`。

- [ ] **Step 1: 寫失敗測試**

在 `story/src/engine/schema.test.ts` 追加：

```ts
import { validateLayout, validateScript } from './schema'

const goodLayout = {
  canvas: { width: 1024, height: 1536 },
  characters: {
    anne: {
      head: { cx: 0.5, top: 0.03, height: 0.22 },
      torso: { cx: 0.5, top: 0.2, height: 0.78 },
      leftArm: { cx: 0.33, top: 0.23, height: 0.35 },
      rightArm: { cx: 0.64, top: 0.22, height: 0.35 },
    },
  },
}

test('validateLayout 接受合法 layout', () => {
  expect(validateLayout(goodLayout).characters.anne.head.cx).toBe(0.5)
})

test('validateLayout 拒絕缺部件', () => {
  const bad = structuredClone(goodLayout) as Record<string, unknown>
  delete (bad.characters as Record<string, Record<string, unknown>>).anne.torso
  expect(() => validateLayout(bad)).toThrow()
})

test('validateLayout 拒絕超界數值', () => {
  const bad = structuredClone(goodLayout)
  bad.characters.anne.head.height = 9
  expect(() => validateLayout(bad)).toThrow()
})

test('validateLayout 搭配 script 檢查缺角色', () => {
  const script = validateScript({
    slug: 's', title: 't', place: 'p', intro: 'i', startNode: 'n1',
    characters: [
      { id: 'anne', name: '安妮', parts: { head: 'a', torso: 'b', leftArm: 'c', rightArm: 'd' } },
      { id: 'kingston', name: '金斯頓', parts: { head: 'a', torso: 'b', leftArm: 'c', rightArm: 'd' } },
    ],
    nodes: [{ id: 'n1', background: 'bg.png', paragraphs: ['x'], ending: { title: 'end' } }],
  })
  expect(() => validateLayout(goodLayout, script)).toThrow(/kingston/)
})
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd story && npx vitest run src/engine/schema.test.ts`
Expected: FAIL（validateLayout is not exported）

- [ ] **Step 3: 實作**

在 `story/src/engine/schema.ts` 追加：

```ts
export const partLayoutSchema = z.object({
  cx: z.number().min(-0.5).max(1.5),
  top: z.number().min(-0.5).max(1.5),
  height: z.number().min(0.01).max(1.5),
})
export const layoutSchema = z.object({
  canvas: z.object({ width: z.number().positive(), height: z.number().positive() }),
  characters: z.record(z.string(), z.object({
    head: partLayoutSchema, torso: partLayoutSchema,
    leftArm: partLayoutSchema, rightArm: partLayoutSchema,
  })),
})
export type PartLayout = z.infer<typeof partLayoutSchema>
export type Layout = z.infer<typeof layoutSchema>

export function validateLayout(data: unknown, script?: Script): Layout {
  const layout = layoutSchema.parse(data)
  for (const character of script?.characters ?? [])
    if (!(character.id in layout.characters))
      throw new Error(`layout.json 缺角色：${character.id}`)
  return layout
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd story && npx vitest run src/engine/schema.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add story/src/engine/schema.ts story/src/engine/schema.test.ts
git commit -m "feat(story): layout.json schema 與 validateLayout"
```

---

### Task 2: 遷移腳本——registered PNG 裁回緊裁圖並產出 layout.json

**Files:**
- Create: `scripts/story_assets/layout_migrate.py`
- Modify: `scripts/story_assets_gen.py`（加 `tighten` 子命令）
- Modify: `scripts/story_assets/characters.py`（生成角色時補 layout 預設值）
- Test: `scripts/tests/test_layout_migrate.py`

**Interfaces:**
- Consumes: 現有 registered 全畫布部件 PNG（1024×1536、含透明邊）。
- Produces:
  ```python
  # layout_migrate.py
  PART_KEYS = ("head", "torso", "leftArm", "rightArm")
  def part_bbox_layout(png_bytes: bytes, canvas: tuple[int, int]) -> tuple[bytes, dict]:
      """回傳 (緊裁後 PNG bytes, {"cx","top","height"})，比例以 canvas 為分母。"""
  def migrate(content_dir: Path) -> dict:
      """就地把每角色四部件裁緊、寫 layout.json，回傳 layout dict。"""
  # characters.py
  DEFAULT_PART_LAYOUT = {
      "head": {"cx": 0.5, "top": 0.02, "height": 0.20},
      "torso": {"cx": 0.5, "top": 0.16, "height": 0.80},
      "leftArm": {"cx": 0.30, "top": 0.20, "height": 0.38},
      "rightArm": {"cx": 0.70, "top": 0.20, "height": 0.38},
  }
  def ensure_layout_entry(content_dir: Path, char_id: str) -> None:
      """layout.json 沒有該角色時寫入 DEFAULT_PART_LAYOUT（有就不動）。"""
  ```

原理：registered PNG 的部件位置就是要遷移的參數——對 alpha 通道取 bbox
`(left, top, w, h)`，則 `cx=(left+w/2)/1024`、`top=top/1536`、`height=h/1536`，
裁下 bbox 即緊裁圖。零誤差、不依賴任何外部參數。

- [ ] **Step 1: 寫失敗測試**

`scripts/tests/test_layout_migrate.py`：

```python
import json
from pathlib import Path

from PIL import Image

from story_assets.layout_migrate import migrate, part_bbox_layout


def _canvas_with_box(left, top, w, h, size=(1024, 1536)):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    for x in range(left, left + w):
        for y in range(top, top + h):
            im.putpixel((x, y), (200, 10, 10, 255))
    from io import BytesIO
    buf = BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


def test_part_bbox_layout_計算比例與緊裁():
    png = _canvas_with_box(left=412, top=46, w=200, h=300)
    tight, part = part_bbox_layout(png, (1024, 1536))
    assert abs(part["cx"] - (412 + 100) / 1024) < 1e-6
    assert abs(part["top"] - 46 / 1536) < 1e-6
    assert abs(part["height"] - 300 / 1536) < 1e-6
    from io import BytesIO
    im = Image.open(BytesIO(tight))
    assert im.size == (200, 300)


def test_migrate_寫入_layout_json(tmp_path: Path):
    content = tmp_path
    (content / "assets" / "characters" / "anne").mkdir(parents=True)
    script = {
        "slug": "s", "title": "t", "place": "p", "intro": "i", "startNode": "n1",
        "characters": [{"id": "anne", "name": "安妮", "parts": {
            "head": "characters/anne/head.png", "torso": "characters/anne/torso.png",
            "leftArm": "characters/anne/left-arm.png", "rightArm": "characters/anne/right-arm.png"}}],
        "nodes": [{"id": "n1", "background": "b.png", "paragraphs": ["x"], "ending": {"title": "e"}}],
    }
    (content / "script.json").write_text(json.dumps(script), encoding="utf-8")
    for name, box in {
        "head.png": (412, 46, 200, 300), "torso.png": (300, 300, 400, 1100),
        "left-arm.png": (250, 340, 150, 500), "right-arm.png": (600, 330, 150, 500),
    }.items():
        (content / "assets" / "characters" / "anne" / name).write_bytes(
            _canvas_with_box(*box))
    layout = migrate(content)
    saved = json.loads((content / "layout.json").read_text(encoding="utf-8"))
    assert saved == layout
    assert abs(layout["characters"]["anne"]["head"]["top"] - 46 / 1536) < 1e-6
    im = Image.open(content / "assets" / "characters" / "anne" / "torso.png")
    assert im.size == (400, 1100)
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd scripts && uv run pytest tests/test_layout_migrate.py -q`
Expected: FAIL（ModuleNotFoundError: layout_migrate）

- [ ] **Step 3: 實作 layout_migrate.py**

```python
"""把 registered 全畫布部件 PNG 裁回緊裁圖，並以其 bbox 產出 layout.json。"""
from __future__ import annotations

import json
from io import BytesIO
from pathlib import Path

from PIL import Image

PART_KEYS = ("head", "torso", "leftArm", "rightArm")
CANVAS = (1024, 1536)


def part_bbox_layout(png_bytes: bytes, canvas: tuple[int, int]) -> tuple[bytes, dict]:
    im = Image.open(BytesIO(png_bytes)).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("部件圖全透明，無法遷移")
    left, top, right, bottom = bbox
    w, h = right - left, bottom - top
    cw, ch = canvas
    part = {
        "cx": round((left + w / 2) / cw, 4),
        "top": round(top / ch, 4),
        "height": round(h / ch, 4),
    }
    buf = BytesIO()
    im.crop(bbox).save(buf, "PNG")
    return buf.getvalue(), part


def migrate(content_dir: Path) -> dict:
    script = json.loads((content_dir / "script.json").read_text(encoding="utf-8"))
    characters: dict[str, dict] = {}
    for character in script["characters"]:
        parts: dict[str, dict] = {}
        for key in PART_KEYS:
            rel = character["parts"][key]
            dest = content_dir / "assets" / rel
            tight, part = part_bbox_layout(dest.read_bytes(), CANVAS)
            dest.write_bytes(tight)
            parts[key] = part
        characters[character["id"]] = parts
    layout = {"canvas": {"width": CANVAS[0], "height": CANVAS[1]}, "characters": characters}
    (content_dir / "layout.json").write_text(
        json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return layout
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd scripts && uv run pytest tests/test_layout_migrate.py -q`
Expected: PASS

- [ ] **Step 5: characters.py 補 ensure_layout_entry + 測試**

`characters.py` 追加（含 `DEFAULT_PART_LAYOUT` 常數，見 Interfaces）：

```python
def ensure_layout_entry(content_dir: Path, char_id: str) -> None:
    layout_path = content_dir / "layout.json"
    layout = (json.loads(layout_path.read_text(encoding="utf-8"))
              if layout_path.exists()
              else {"canvas": {"width": 1024, "height": 1536}, "characters": {}})
    if char_id in layout["characters"]:
        return
    layout["characters"][char_id] = json.loads(json.dumps(DEFAULT_PART_LAYOUT))
    layout_path.write_text(
        json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
```

在 `run_characters` 的每個 character 迴圈結尾呼叫
`ensure_layout_entry(content_dir, char_id)`。

`scripts/tests/test_layout_migrate.py` 追加：

```python
def test_ensure_layout_entry_不覆蓋既有(tmp_path: Path):
    from story_assets.characters import ensure_layout_entry
    ensure_layout_entry(tmp_path, "anne")
    layout = json.loads((tmp_path / "layout.json").read_text(encoding="utf-8"))
    assert "anne" in layout["characters"]
    layout["characters"]["anne"]["head"]["cx"] = 0.42
    (tmp_path / "layout.json").write_text(json.dumps(layout), encoding="utf-8")
    ensure_layout_entry(tmp_path, "anne")
    layout2 = json.loads((tmp_path / "layout.json").read_text(encoding="utf-8"))
    assert layout2["characters"]["anne"]["head"]["cx"] == 0.42
```

Run: `cd scripts && uv run pytest tests/test_layout_migrate.py -q` → PASS

- [ ] **Step 6: story_assets_gen.py 加 `tighten` 子命令**

在既有 subparsers 加：

```python
tighten = subparsers.add_parser("tighten", help="registered 部件裁緊並產出 layout.json")
tighten.add_argument("--slug", required=True)
```

dispatch 到：

```python
from story_assets.layout_migrate import migrate
migrate(CONTENT_ROOT / args.slug)  # CONTENT_ROOT 沿用檔內既有的 content 路徑常數
```

Run: `cd scripts && uv run pytest -q`（全套）
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/story_assets/layout_migrate.py scripts/story_assets/characters.py scripts/story_assets_gen.py scripts/tests/test_layout_migrate.py
git commit -m "feat(scripts): registered 部件裁緊遷移與 layout.json 產出"
```

---

### Task 3: CharacterSprite 依 layout 執行時定位

**Files:**
- Modify: `story/src/components/CharacterSprite.tsx`
- Modify: `story/src/components/SceneView.tsx`（傳遞 layout）
- Modify: `story/src/styles/character.css`
- Test: `story/src/components/CharacterSprite.test.tsx`

**Interfaces:**
- Consumes: Task 1 的 `Layout`、`PartLayout`。
- Produces:
  ```tsx
  export function CharacterSprite(props: {
    character: Character; member: CastMember; slug: string; layout: Layout
  }): JSX.Element
  // SceneView 增加 prop：layout: Layout，轉傳給每個 CharacterSprite
  ```
  每部件 `<img>` 的 inline style：
  `left: cx*100%`、`top: top*100%`、`height: height*100%`、`translate: '-50% 0'`
  （width 不設，瀏覽器依圖片長寬比自算）。

- [ ] **Step 1: 改寫測試（先紅）**

`CharacterSprite.test.tsx` 改為：

```tsx
import { render, screen } from '@testing-library/react'
import { CharacterSprite } from './CharacterSprite'
import { assetUrl } from '../data/loadScript'
import { demoScript } from '../test/fixtures'
import type { Layout } from '../engine/schema'

const master = demoScript.characters[0]
const layout: Layout = {
  canvas: { width: 1024, height: 1536 },
  characters: {
    master: {
      head: { cx: 0.5, top: 0.03, height: 0.22 },
      torso: { cx: 0.5, top: 0.2, height: 0.78 },
      leftArm: { cx: 0.33, top: 0.23, height: 0.35 },
      rightArm: { cx: 0.64, top: 0.22, height: 0.35 },
    },
  },
}

test('渲染四個部件圖並依 layout 定位', () => {
  render(<CharacterSprite character={master} member={{ character: 'master', position: 'center' }} slug="demo" layout={layout} />)
  const sprite = screen.getByTestId('sprite-master')
  expect(sprite.querySelectorAll('img')).toHaveLength(4)
  const head = sprite.querySelector('.sprite__head') as HTMLElement
  expect(head).toHaveAttribute('src', assetUrl('demo', 'characters/master/head.png'))
  expect(head.style.left).toBe('50%')
  expect(head.style.top).toBe('3%')
  expect(head.style.height).toBe('22%')
})

test('talking 時掛 is-talking class；否則不掛', () => {
  const { rerender } = render(
    <CharacterSprite character={master} member={{ character: 'master', position: 'left', talking: true }} slug="demo" layout={layout} />)
  expect(screen.getByTestId('sprite-master')).toHaveClass('is-talking', 'sprite--left')
  rerender(<CharacterSprite character={master} member={{ character: 'master', position: 'left' }} slug="demo" layout={layout} />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-talking')
})
```

Run: `cd story && npx vitest run src/components/CharacterSprite.test.tsx` → FAIL

- [ ] **Step 2: 實作 CharacterSprite**

```tsx
import { assetUrl } from '../data/loadScript'
import type { CastMember, Character, Layout, PartLayout } from '../engine/schema'

const PART_CLASS: Record<keyof Character['parts'], string> = {
  leftArm: 'sprite__arm-left',
  rightArm: 'sprite__arm-right',
  torso: 'sprite__torso',
  head: 'sprite__head',
}

function partStyle(part: PartLayout) {
  return {
    left: `${part.cx * 100}%`,
    top: `${part.top * 100}%`,
    height: `${part.height * 100}%`,
    translate: '-50% 0',
  }
}

export function CharacterSprite({ character, member, slug, layout }: {
  character: Character; member: CastMember; slug: string; layout: Layout
}) {
  const charLayout = layout.characters[character.id]
  const className = ['sprite', `sprite--${member.position}`, member.talking ? 'is-talking' : '']
    .filter(Boolean).join(' ')
  return (
    <div className={className} data-testid={`sprite-${character.id}`}>
      {(Object.keys(PART_CLASS) as (keyof Character['parts'])[]).map((key) => (
        <img
          key={key}
          className={`sprite__part ${PART_CLASS[key]}`}
          style={partStyle(charLayout[key])}
          src={assetUrl(slug, character.parts[key])}
          alt=""
        />
      ))}
    </div>
  )
}
```

（渲染順序沿用現行：arm-left、arm-right、torso、head——object key 順序即
PART_CLASS 宣告順序。）

- [ ] **Step 3: character.css 調整**

- `.sprite`／雙人縮放規則：`height` 改為 `aspect-ratio: 2 / 3`（部件以百分比定位，容器必須維持基準畫布比例）：

```css
.sprite {
  position: absolute;
  bottom: 0;
  /* 部件以 layout.json 的基準畫布比例定位，容器必須固定 2:3
     （1024×1536），否則百分比定位變形。 */
  width: 72%;
  aspect-ratio: 2 / 3;
  animation: fade-slide-in 0.6s ease-out both;
  pointer-events: none;
}

.sprite:has(+ .sprite),
.sprite + .sprite {
  width: 58%;
}
```

- `.sprite__part` 拿掉 `inset/width/height/object-fit`（改由 inline style 定位），保留 `position: absolute; pointer-events: none;`。
- transform-origin 改為部件自身座標系（緊裁圖語意）：

```css
.sprite__torso { animation: breathe 3.2s ease-in-out infinite; transform-origin: center bottom; }
.sprite__arm-left, .sprite__arm-right { animation: sway 3.2s ease-in-out infinite; transform-origin: top center; }
.sprite__arm-right { animation-delay: -1.6s; }
.is-talking .sprite__head { animation: nod 0.9s ease-in-out infinite; transform-origin: 50% 70%; }
```

- [ ] **Step 4: SceneView 傳遞 layout**

`SceneView` props 加 `layout: Layout`，`<CharacterSprite ... layout={layout} />`。
連帶修 `SceneView` 的既有測試（若有）與 `PlayPage.tsx` 呼叫端——PlayPage 串接在 Task 4，此步先讓 `npx tsc -b` 通過的最小改法：PlayPage 暫以 `layout={layout!}` 之類寫法會違反 strict，正確做法是本 task 先不動 PlayPage、SceneView 測試用假 layout，`npm run build` 留到 Task 4 驗。

Run: `cd story && npx vitest run src/components` → PASS

- [ ] **Step 5: Commit**

```bash
git add story/src/components/CharacterSprite.tsx story/src/components/SceneView.tsx story/src/styles/character.css story/src/components/CharacterSprite.test.tsx
git commit -m "feat(story): CharacterSprite 依 layout.json 執行時定位"
```

---

### Task 4: PlayPage 載入 layout + 執行遷移 + 視覺驗收

**Files:**
- Create: `story/src/data/loadLayout.ts`
- Test: `story/src/data/loadLayout.test.ts`
- Modify: `story/src/pages/PlayPage.tsx`、`story/src/data/loadScript.ts`（CONTENT_VERSION）
- Modify: `story/public/content/tower-of-london-anne/`（跑遷移腳本產出）

**Interfaces:**
- Consumes: Task 1 `validateLayout`、Task 2 `tighten` CLI、Task 3 SceneView。
- Produces:
  ```ts
  // loadLayout.ts
  export async function loadLayout(slug: string, script: Script): Promise<Layout>
  // fetch `/content/${slug}/layout.json?v=${CONTENT_VERSION}` → validateLayout(json, script)
  ```
  PlayPage 以 `Promise.all([loadScript(slug), ...])` 後續載 layout，兩者就緒才 render SceneView。

- [ ] **Step 1: loadLayout 失敗測試**

```ts
// story/src/data/loadLayout.test.ts
import { loadLayout } from './loadLayout'
import { demoScript } from '../test/fixtures'

test('loadLayout 抓取並驗證 layout.json', async () => {
  const layout = {
    canvas: { width: 1024, height: 1536 },
    characters: { master: {
      head: { cx: 0.5, top: 0.03, height: 0.22 },
      torso: { cx: 0.5, top: 0.2, height: 0.78 },
      leftArm: { cx: 0.33, top: 0.23, height: 0.35 },
      rightArm: { cx: 0.64, top: 0.22, height: 0.35 },
    } },
  }
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify(layout))))
  const result = await loadLayout('demo', demoScript)
  expect(result.characters.master.torso.height).toBe(0.78)
  expect(vi.mocked(fetch).mock.calls[0][0]).toContain('/content/demo/layout.json?v=')
})

test('loadLayout HTTP 失敗丟明確錯誤', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response('', { status: 404 })))
  await expect(loadLayout('demo', demoScript)).rejects.toThrow(/layout/)
})
```

Run: `cd story && npx vitest run src/data/loadLayout.test.ts` → FAIL

- [ ] **Step 2: 實作 loadLayout.ts**

```ts
import { validateLayout, type Layout, type Script } from '../engine/schema'
import { contentUrl } from './loadScript'

export async function loadLayout(slug: string, script: Script): Promise<Layout> {
  const res = await fetch(contentUrl(slug, 'layout.json'))
  if (!res.ok) throw new Error(`layout 載入失敗：HTTP ${res.status}`)
  return validateLayout(await res.json(), script)
}
```

`loadScript.ts` 抽出共用（並 bump 版本）：

```ts
const CONTENT_VERSION = '4'
export function contentUrl(slug: string, file: string): string {
  return `/content/${slug}/${file}?v=${CONTENT_VERSION}`
}
// loadScript 改用 contentUrl(slug, 'script.json')；assetUrl 改用
// contentUrl(slug, `assets/${path}`)
```

Run: 同上 → PASS；另跑 `npx vitest run src/data` 確認 loadScript/preload 測試不破。

- [ ] **Step 3: PlayPage 串接**

PlayPage 載入流程改為：`loadScript(slug)` 成功後 `loadLayout(slug, script)`，
兩者都就緒才進入 intro/play 畫面；layout 存 state 傳給 `<SceneView layout={layout}>`。
錯誤處理沿用既有「載入失敗 + 重試」UI（layout 失敗同樣走 retry）。
同檔 PlayPage.test.tsx 的 fetch stub 需多回一份 layout.json（測試 fixture 加
`demoLayout` 到 `src/test/fixtures.ts` 並 export，供各測試共用）。

Run: `cd story && npm test` → 全綠
Run: `cd story && npm run build` → 綠（tsc 驗 SceneView/PlayPage 型別串接）

- [ ] **Step 4: 執行遷移**

```bash
cd scripts && uv run python story_assets_gen.py tighten --slug tower-of-london-anne
cd .. && pngquant --quality=70-92 --speed 1 --strip --ext .png --force \
  story/public/content/tower-of-london-anne/assets/characters/*/head.png \
  story/public/content/tower-of-london-anne/assets/characters/*/torso.png \
  story/public/content/tower-of-london-anne/assets/characters/*/left-arm.png \
  story/public/content/tower-of-london-anne/assets/characters/*/right-arm.png
cd scripts && uv run python story_assets_gen.py check --slug tower-of-london-anne
```

Expected: check exit 0；`layout.json` 出現且含 anne/kingston/thomas 三角色。

- [ ] **Step 5: 視覺驗收（headless Chrome）**

`cd story && npm run build && npx vite preview --port 4173 &`，用
headless Chrome 對 `/play/tower-of-london-anne` 需要人工推進，改用臨時
harness（複製本 repo 先前作法：dist 下放單頁引用 build CSS + 直接排
sprite markup——注意本 task 中 sprite 定位已改 inline style，harness 需
以 React 渲染不可行，故改為：`npx vite dev` 開 dev server，headless
Chrome 截 `/play/tower-of-london-anne`（intro 頁）確認 200 與無 console
error，sprite 視覺由下一步 Playwright 式互動略過，改以元件測試 +
Task 15 工作台舞台預覽人工確認）。截圖存 scratchpad 檢視背景正常即可。
驗收重點：`npm test` 全綠、check 過、dev server console 無 layout 驗證錯誤。

- [ ] **Step 6: Commit**

```bash
git add story/src story/public/content/tower-of-london-anne
git commit -m "feat(story): 骨骼定位資料化——layout.json 上線、部件回緊裁圖、CONTENT_VERSION=4"
```

---

## Phase B：catalog 遷移

### Task 5: content/index.json 與 HomePage 改 fetch

**Files:**
- Create: `story/public/content/index.json`
- Create: `story/src/data/catalog.ts` 改寫（原靜態陣列 → fetch）
- Modify: `story/src/pages/HomePage.tsx`
- Test: `story/src/data/catalog.test.ts`、`story/src/pages/HomePage.test.tsx`（既有，調整 stub）

**Interfaces:**
- Produces:
  ```ts
  export type CatalogEntry = { slug: string; title: string; place: string; blurb: string }
  export async function loadCatalog(): Promise<CatalogEntry[]>
  // fetch `/content/index.json?v=${CONTENT_VERSION}`，zod 驗證：
  export const catalogSchema: z.ZodType<{ stories: CatalogEntry[] }>  // 放 engine/schema.ts
  ```
  `index.json` 形狀：`{ "stories": [{ "slug", "title", "place", "blurb" }] }`。

- [ ] **Step 1: index.json 內容**

```json
{
  "stories": [
    {
      "slug": "tower-of-london-anne",
      "title": "千日之後",
      "place": "倫敦塔",
      "blurb": "你是安妮身邊最卑微的侍女，她只剩十七天——你，要留下嗎？"
    }
  ]
}
```

- [ ] **Step 2: catalogSchema + loadCatalog 失敗測試**

`schema.test.ts` 追加 catalogSchema 合法/非法各一案；`catalog.test.ts`：

```ts
import { loadCatalog } from './catalog'

test('loadCatalog 抓取並回傳 stories', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({
    stories: [{ slug: 's', title: 't', place: 'p', blurb: 'b' }],
  }))))
  const entries = await loadCatalog()
  expect(entries[0].slug).toBe('s')
})
```

Run → FAIL；實作：schema.ts 加

```ts
export const catalogEntrySchema = z.object({
  slug: z.string().min(1), title: z.string().min(1),
  place: z.string().min(1), blurb: z.string().min(1),
})
export const catalogSchema = z.object({ stories: z.array(catalogEntrySchema) })
export type CatalogEntry = z.infer<typeof catalogEntrySchema>
```

`catalog.ts` 改為：

```ts
import { catalogSchema, type CatalogEntry } from '../engine/schema'

export async function loadCatalog(): Promise<CatalogEntry[]> {
  const res = await fetch(`/content/index.json?v=${CONTENT_VERSION_EXPORTED}`)
  if (!res.ok) throw new Error(`目錄載入失敗：HTTP ${res.status}`)
  return catalogSchema.parse(await res.json()).stories
}
```

（`loadScript.ts` 將 `CONTENT_VERSION` export 供此處與 loadLayout 使用；
命名 `CONTENT_VERSION` 直接 export 即可。）

- [ ] **Step 3: HomePage 改 async 載入**

useEffect + useState 載 catalog，載入中顯示空狀態、失敗顯示錯誤字樣；
HomePage.test.tsx 對應 stub fetch。

Run: `cd story && npm test` → 全綠；`npm run build` → 綠

- [ ] **Step 4: Commit**

```bash
git add story/public/content/index.json story/src
git commit -m "feat(story): catalog 遷入 content/index.json，週更上新不改碼"
```

---

## Phase C：editor-api Vite plugin

### Task 6: plugin 骨架——JSON 讀寫 API + 驗證擋存

**Files:**
- Create: `story/plugins/editor-api/core.ts`（純函式，可測）
- Create: `story/plugins/editor-api/index.ts`（vite plugin 掛載）
- Modify: `story/vite.config.ts`
- Test: `story/plugins/editor-api/core.test.ts`

**Interfaces:**
- Produces:
  ```ts
  // core.ts
  export type ContentFile = 'script.json' | 'art.json' | 'layout.json'
  export function validateContentPayload(
    file: ContentFile | 'index.json', data: unknown,
    context?: { script?: unknown },
  ): { ok: true } | { ok: false; error: string }
  export function safeContentPath(
    root: string, slug: string, file: string,
  ): string | null  // 防路徑跳脫；不合法回 null
  // index.ts
  export function editorApiPlugin(): Plugin  // apply: 'serve'
  ```
  HTTP 介面（dev only）：
  - `GET /__editor/content/index.json` → index.json
  - `GET /__editor/content/<slug>/<file>` → 該 JSON
  - `PUT 同上`（body: JSON）→ 驗證過→寫檔回 204；不過→400 `{ error }`
  - script.json 的 PUT 用 `validateScript`；layout.json 用
    `validateLayout(data, 現行 script)`；art.json 只驗 JSON parse 得過；
    index.json 用 `catalogSchema`。

- [ ] **Step 1: core 純函式失敗測試**

```ts
// @vitest-environment node
import { safeContentPath, validateContentPayload } from './core'

test('safeContentPath 擋路徑跳脫', () => {
  expect(safeContentPath('/root', '../etc', 'script.json')).toBeNull()
  expect(safeContentPath('/root', 'demo', '../../secret')).toBeNull()
  expect(safeContentPath('/root', 'demo', 'script.json'))
    .toBe('/root/demo/script.json')
})

test('validateContentPayload 擋壞 script', () => {
  const bad = validateContentPayload('script.json', { slug: 's' })
  expect(bad.ok).toBe(false)
})

test('validateContentPayload 擋 layout 缺角色（帶 context script）', () => {
  const script = {
    slug: 's', title: 't', place: 'p', intro: 'i', startNode: 'n1',
    characters: [{ id: 'anne', name: 'a', parts: { head: 'h', torso: 't', leftArm: 'l', rightArm: 'r' } }],
    nodes: [{ id: 'n1', background: 'b', paragraphs: ['x'], ending: { title: 'e' } }],
  }
  const result = validateContentPayload('layout.json',
    { canvas: { width: 1024, height: 1536 }, characters: {} }, { script })
  expect(result.ok).toBe(false)
})
```

Run: `cd story && npx vitest run plugins/editor-api/core.test.ts` → FAIL

- [ ] **Step 2: 實作 core.ts**

```ts
import path from 'node:path'
import { catalogSchema, validateLayout, validateScript } from '../../src/engine/schema'

export type ContentFile = 'script.json' | 'art.json' | 'layout.json'

export function safeContentPath(root: string, slug: string, file: string): string | null {
  const resolved = path.resolve(root, slug, file)
  if (!resolved.startsWith(path.resolve(root) + path.sep)) return null
  if (slug.includes('..') || file.includes('..')) return null
  return resolved
}

export function validateContentPayload(
  file: ContentFile | 'index.json', data: unknown,
  context?: { script?: unknown },
): { ok: true } | { ok: false; error: string } {
  try {
    if (file === 'script.json') validateScript(data)
    else if (file === 'layout.json')
      validateLayout(data, context?.script ? validateScript(context.script) : undefined)
    else if (file === 'index.json') catalogSchema.parse(data)
    else if (file === 'art.json') JSON.parse(JSON.stringify(data))
    return { ok: true }
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : String(error) }
  }
}
```

Run → PASS

- [ ] **Step 3: index.ts plugin（middleware）**

```ts
import fs from 'node:fs'
import path from 'node:path'
import type { Plugin } from 'vite'
import { safeContentPath, validateContentPayload, type ContentFile } from './core'

export function editorApiPlugin(): Plugin {
  return {
    name: 'editor-api',
    apply: 'serve',
    configureServer(server) {
      const root = path.resolve(server.config.root, 'public/content')
      server.middlewares.use('/__editor', (req, res, next) => {
        const url = new URL(req.url ?? '/', 'http://local')
        const match = url.pathname.match(/^\/content\/(?:([\w-]+)\/)?([\w.-]+\.json)$/)
        if (!match) return next()
        const [, slug = '', file] = match
        const target = safeContentPath(root, slug, file)
        if (!target) { res.statusCode = 400; return res.end('{"error":"bad path"}') }
        if (req.method === 'GET') {
          if (!fs.existsSync(target)) { res.statusCode = 404; return res.end('{}') }
          res.setHeader('content-type', 'application/json')
          return res.end(fs.readFileSync(target, 'utf-8'))
        }
        if (req.method === 'PUT') {
          let body = ''
          req.on('data', (chunk) => { body += chunk })
          req.on('end', () => {
            try {
              const data = JSON.parse(body)
              const scriptPath = safeContentPath(root, slug, 'script.json')
              const context = file === 'layout.json' && scriptPath && fs.existsSync(scriptPath)
                ? { script: JSON.parse(fs.readFileSync(scriptPath, 'utf-8')) }
                : undefined
              const verdict = validateContentPayload(file as ContentFile | 'index.json', data, context)
              if (!verdict.ok) {
                res.statusCode = 400
                return res.end(JSON.stringify({ error: verdict.error }))
              }
              fs.writeFileSync(target, JSON.stringify(data, null, 2) + '\n')
              res.statusCode = 204
              res.end()
            } catch (error) {
              res.statusCode = 400
              res.end(JSON.stringify({ error: String(error) }))
            }
          })
          return
        }
        next()
      })
    },
  }
}
```

`vite.config.ts`：

```ts
import { editorApiPlugin } from './plugins/editor-api'
export default defineConfig({
  plugins: [react(), editorApiPlugin()],
  ...
})
```

- [ ] **Step 4: 手動驗證**

```bash
cd story && npx vite dev --port 5199 &
curl -s http://localhost:5199/__editor/content/tower-of-london-anne/script.json | head -c 120
curl -s -X PUT -d '{"bad":1}' http://localhost:5199/__editor/content/tower-of-london-anne/script.json -o - -w '%{http_code}\n'
```

Expected: GET 回 script 開頭；PUT 回 400 + error JSON；`git status` 確認
script.json 未被改動。收工 kill dev server。

- [ ] **Step 5: Commit**

```bash
git add story/plugins story/vite.config.ts
git commit -m "feat(story): editor-api plugin——內容讀寫 API + 驗證擋存"
```

---

### Task 7: SSE 事件流 + chokidar watch + 自寫入抑制

**Files:**
- Modify: `story/plugins/editor-api/index.ts`
- Create: `story/plugins/editor-api/watcher.ts`（純邏輯可測）
- Modify: `story/vite.config.ts`（`server.watch.ignored` 排除 content）
- Test: `story/plugins/editor-api/watcher.test.ts`

**Interfaces:**
- Produces:
  ```ts
  // watcher.ts
  export type ContentEvent = { type: 'change' | 'add' | 'unlink'; slug: string; file: string }
  export function classifyPath(root: string, absPath: string): ContentEvent | null
  // root 之下的路徑轉事件：public/content/<slug>/<file...>；index.json 的
  // slug 為 ''。root 之外回 null。
  export class SelfWriteGuard {
    markWrite(absPath: string): void
    isSelf(absPath: string): boolean  // markWrite 後 1500ms 內為 true
  }
  ```
  HTTP：`GET /__editor/events` → SSE，每筆 `data: <JSON ContentEvent>`。
  plugin 內 chokidar watch `public/content`，事件經 SelfWriteGuard 過濾後廣播；
  PUT/POST 寫檔前呼叫 `guard.markWrite(target)`。

- [ ] **Step 1: watcher 純函式失敗測試**

```ts
// @vitest-environment node
import { classifyPath, SelfWriteGuard } from './watcher'

test('classifyPath 解析 slug 與 file', () => {
  expect(classifyPath('/r/public/content', '/r/public/content/demo/script.json'))
    .toEqual({ type: 'change', slug: 'demo', file: 'script.json' })
  expect(classifyPath('/r/public/content', '/r/public/content/demo/assets/scenes/a.png'))
    .toEqual({ type: 'change', slug: 'demo', file: 'assets/scenes/a.png' })
  expect(classifyPath('/r/public/content', '/r/public/content/index.json'))
    .toEqual({ type: 'change', slug: '', file: 'index.json' })
  expect(classifyPath('/r/public/content', '/elsewhere/x.json')).toBeNull()
})

test('SelfWriteGuard 抑制自寫入', () => {
  vi.useFakeTimers()
  const guard = new SelfWriteGuard()
  guard.markWrite('/p/a.json')
  expect(guard.isSelf('/p/a.json')).toBe(true)
  vi.advanceTimersByTime(2000)
  expect(guard.isSelf('/p/a.json')).toBe(false)
  vi.useRealTimers()
})
```

Run → FAIL；實作 watcher.ts：

```ts
import path from 'node:path'

export type ContentEvent = { type: 'change' | 'add' | 'unlink'; slug: string; file: string }

export function classifyPath(root: string, absPath: string): ContentEvent | null {
  const rel = path.relative(root, absPath)
  if (rel.startsWith('..') || path.isAbsolute(rel)) return null
  const segments = rel.split(path.sep)
  if (segments.length === 1) return { type: 'change', slug: '', file: segments[0] }
  return { type: 'change', slug: segments[0], file: segments.slice(1).join('/') }
}

export class SelfWriteGuard {
  private writes = new Map<string, number>()
  markWrite(absPath: string): void { this.writes.set(absPath, Date.now()) }
  isSelf(absPath: string): boolean {
    const at = this.writes.get(absPath)
    return at !== undefined && Date.now() - at < 1500
  }
}
```

Run → PASS

- [ ] **Step 2: plugin 掛 SSE 與 chokidar**

index.ts 內：

```ts
import chokidar from 'chokidar'
// configureServer 中：
const clients = new Set<import('node:http').ServerResponse>()
const guard = new SelfWriteGuard()
server.middlewares.use('/__editor/events', (req, res) => {
  res.writeHead(200, {
    'content-type': 'text/event-stream',
    'cache-control': 'no-cache', connection: 'keep-alive',
  })
  res.write('\n')
  clients.add(res)
  req.on('close', () => clients.delete(res))
})
const watcher = chokidar.watch(root, { ignoreInitial: true })
for (const type of ['change', 'add', 'unlink'] as const)
  watcher.on(type, (absPath: string) => {
    if (guard.isSelf(absPath)) return
    const event = classifyPath(root, absPath)
    if (!event) return
    const payload = `data: ${JSON.stringify({ ...event, type })}\n\n`
    for (const client of clients) client.write(payload)
  })
server.httpServer?.on('close', () => { void watcher.close() })
```

PUT handler 寫檔前 `guard.markWrite(target)`。

`vite.config.ts` 加：

```ts
server: { watch: { ignored: ['**/public/content/**'] } },
```

並在該行加註解：content 變更由 editor-api 的 SSE 精準推播，避免 Vite
full-reload 洗掉編輯器狀態；副作用是 dev 模式 `/play` 改內容需手動
重整（spec 已知偏差）。

- [ ] **Step 3: 手動驗證**

```bash
cd story && npx vite dev --port 5199 &
curl -N http://localhost:5199/__editor/events &
sleep 1 && touch public/content/tower-of-london-anne/script.json
```

Expected: curl 印出 `data: {"type":"change","slug":"tower-of-london-anne","file":"script.json"}`。收工 kill。

- [ ] **Step 4: Commit**

```bash
git add story/plugins story/vite.config.ts
git commit -m "feat(story): editor-api SSE 事件流與自寫入抑制"
```

---

### Task 8: 素材端點——列表與上傳

**Files:**
- Modify: `story/plugins/editor-api/index.ts`、`core.ts`
- Test: `story/plugins/editor-api/core.test.ts`（追加）

**Interfaces:**
- Produces:
  ```ts
  // core.ts 追加
  export function safeAssetPath(root: string, slug: string, rel: string): string | null
  // rel 限 assets/ 之下、只許 [\w./-]、不許 ..；回絕對路徑或 null
  export async function compressPng(absPath: string): Promise<'compressed' | 'skipped'>
  // execFile pngquant --quality=70-92 --speed 1 --strip --ext .png --force <path>
  // ENOENT（未安裝）→ 'skipped'，不丟錯
  ```
  HTTP：
  - `GET /__editor/assets/<slug>` → `{ files: [{ path: 'scenes/a.png', mtime: 123 }] }`
    （遞迴列出 assets/ 下所有 .png）
  - `POST /__editor/assets/<slug>/<rel path>`（body: PNG bytes）→ 寫檔 →
    `compressPng` → 201 `{ path, compressed: boolean }`。
    尺寸規格化（背景 cover 900×1600）由前端 canvas 處理（Task 13），伺服端
    只收成品 bytes。

- [ ] **Step 1: 失敗測試（core 追加）**

```ts
test('safeAssetPath 只允許 assets 下安全路徑', () => {
  expect(safeAssetPath('/root', 'demo', 'assets/scenes/a.png')).toBe('/root/demo/assets/scenes/a.png')
  expect(safeAssetPath('/root', 'demo', 'assets/../../x.png')).toBeNull()
  expect(safeAssetPath('/root', 'demo', 'scenes/a.png')).toBeNull()
})

test('compressPng 未安裝 pngquant 時回 skipped', async () => {
  // 以 PATH 清空模擬：execFile 會 ENOENT
  const result = await compressPng('/nonexistent.png')
  expect(result).toBe('skipped')
})
```

Run → FAIL → 實作（`compressPng` 用 `node:child_process` 的
`execFile`，包 Promise，err?.code === 'ENOENT' 或任何錯誤都回 `'skipped'`
——壓縮失敗不阻擋上傳）→ PASS。

- [ ] **Step 2: middleware 掛 GET 列表與 POST 上傳**

GET：`fs.readdirSync(dir, { recursive: true })` 過濾 `.png`，回
`{ path, mtime: fs.statSync(x).mtimeMs }`。
POST：收 raw body（`req.on('data')` 累積 Buffer）→ `safeAssetPath` →
`guard.markWrite(target)` → `fs.mkdirSync(dirname, { recursive: true })` →
寫檔 → `compressPng` → 201。

- [ ] **Step 3: 手動驗證**

```bash
cd story && npx vite dev --port 5199 &
curl -s http://localhost:5199/__editor/assets/tower-of-london-anne | head -c 200
curl -s -X POST --data-binary @public/content/tower-of-london-anne/assets/scenes/tower-green-dawn.png \
  http://localhost:5199/__editor/assets/tower-of-london-anne/assets/scenes/_upload-test.png -w '%{http_code}\n'
rm public/content/tower-of-london-anne/assets/scenes/_upload-test.png
```

Expected: 列表含 scenes/…；POST 回 201。

- [ ] **Step 4: Commit**

```bash
git add story/plugins
git commit -m "feat(story): editor-api 素材列表與上傳端點"
```

---

## Phase D：/editor UI

### Task 9: /editor 路由骨架 + api client + useStory hook（載入/自動存/SSE）

**Files:**
- Modify: `story/src/App.tsx`
- Create: `story/src/editor/EditorPage.tsx`（先只渲染標題與故事選單）
- Create: `story/src/editor/api.ts`
- Create: `story/src/editor/useStory.ts`
- Create: `story/src/styles/editor.css`（基本三欄 grid 空殼）
- Test: `story/src/editor/useStory.test.ts`、`story/src/App.test.tsx`（追加 DEV 路由案）

**Interfaces:**
- Produces:
  ```ts
  // api.ts
  export async function getJson<T>(path: string): Promise<T>          // GET /__editor/...
  export async function putJson(path: string, data: unknown): Promise<void>  // 400 時丟 Error(error)
  export function subscribeEvents(onEvent: (e: ContentEvent) => void): () => void  // EventSource
  export type ContentEvent = { type: string; slug: string; file: string }
  // useStory.ts
  export function useStory(slug: string): {
    script: Script | null
    art: Record<string, unknown> | null
    layout: Layout | null
    error: string | null
    externalUpdate: string | null          // 最近一次外部更新的檔名（toast 用）
    updateScript(next: Script): void       // 樂觀更新 + debounce 500ms PUT
    updateLayout(next: Layout): void
  }
  ```
  useStory 行為規格：
  - mount 時並行 GET script/art/layout。
  - `updateScript/updateLayout`：立即 setState；500ms debounce 後 PUT；
    PUT 400 → `error` 設為伺服端訊息（畫面顯示、不覆蓋本地編輯）。
  - SSE 收到 `{slug, file}` 符合目前故事 → 重新 GET 該檔覆蓋 state，
    `externalUpdate` 設為檔名（元件顯示 toast 後清除）。debounce 待送的
    本地變更若與外部更新撞同檔：放棄本地未送出變更（last-write-wins）。

- [ ] **Step 1: useStory 失敗測試**

```ts
import { renderHook, act, waitFor } from '@testing-library/react'
import { useStory } from './useStory'
import { demoScript, demoLayout } from '../test/fixtures'

function stubFetchRoutes() {
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input)
    if (init?.method === 'PUT') return new Response(null, { status: 204 })
    if (url.includes('script.json')) return new Response(JSON.stringify(demoScript))
    if (url.includes('layout.json')) return new Response(JSON.stringify(demoLayout))
    return new Response('{}')
  }))
}

test('載入 script 與 layout', async () => {
  stubFetchRoutes()
  const { result } = renderHook(() => useStory('demo'))
  await waitFor(() => expect(result.current.script?.slug).toBe(demoScript.slug))
  expect(result.current.layout).not.toBeNull()
})

test('updateScript 樂觀更新並 debounce PUT', async () => {
  vi.useFakeTimers()
  stubFetchRoutes()
  const { result } = renderHook(() => useStory('demo'))
  await act(async () => { await vi.runOnlyPendingTimersAsync() })
  const next = { ...result.current.script!, title: '改了' }
  act(() => result.current.updateScript(next))
  expect(result.current.script?.title).toBe('改了')
  expect(vi.mocked(fetch).mock.calls.some(([, i]) => i?.method === 'PUT')).toBe(false)
  await act(async () => { await vi.advanceTimersByTimeAsync(600) })
  expect(vi.mocked(fetch).mock.calls.some(([, i]) => i?.method === 'PUT')).toBe(true)
  vi.useRealTimers()
})
```

（`subscribeEvents` 在測試中以 `vi.mock('./api')` 部分替換或注入 stub —
useStory 接受可選第二參數 `deps?: { subscribe?: typeof subscribeEvents }`
以利測 SSE 合併行為；SSE 案：呼叫注入的 handler 後 state 被外部值覆蓋、
`externalUpdate === 'script.json'`。）

Run → FAIL

- [ ] **Step 2: 實作 api.ts / useStory.ts**

api.ts 直白包 fetch/EventSource；useStory 依規格實作（debounce 用
`setTimeout` + `useRef` 存 pending timer；unmount 清除）。

Run → PASS

- [ ] **Step 3: App.tsx 掛 DEV 路由**

```tsx
import { lazy, Suspense } from 'react'
const EditorPage = lazy(() => import('./editor/EditorPage'))
// Routes 內：
{import.meta.env.DEV && (
  <Route path="/editor" element={<Suspense fallback={null}><EditorPage /></Suspense>} />
)}
```

EditorPage 首版：讀 index.json 列故事、選定 slug 後 useStory 載入並顯示
標題。App.test.tsx 追加：DEV 下 `/editor` 可渲染（vitest 的
import.meta.env.DEV 為 true）。

Run: `cd story && npm test` → 綠；`npm run build && ls dist/assets` →
確認無 editor chunk 載入於 index（`grep -L` index-*.js 不含 "EditorPage"
字樣；lazy chunk 檔案存在但主 bundle 不引用也不預載）。

- [ ] **Step 4: Commit**

```bash
git add story/src story/src/styles/editor.css
git commit -m "feat(story): /editor 路由骨架與 useStory 資料層"
```

---

### Task 10: 三欄框架 + 節點清單（選取/拖拉排序）

**Files:**
- Modify: `story/src/editor/EditorPage.tsx`
- Create: `story/src/editor/panels/NodeList.tsx`
- Modify: `story/src/styles/editor.css`
- Test: `story/src/editor/panels/NodeList.test.tsx`

**Interfaces:**
- Consumes: `useStory`。
- Produces:
  ```tsx
  export function NodeList(props: {
    script: Script
    selectedId: string | null
    onSelect(id: string): void
    onReorder(ids: string[]): void   // 新順序的完整 id 陣列
  }): JSX.Element
  ```
  EditorPage 持有 `selectedNodeId` state；`onReorder` 依 ids 重排
  `script.nodes` 後 `updateScript`。拖拉用 @dnd-kit/sortable
  （`npm i -D @dnd-kit/core @dnd-kit/sortable`——dev 依賴無妨，editor chunk
  才 import）。

- [ ] **Step 1: 失敗測試**

```tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { NodeList } from './NodeList'
import { demoScript } from '../../test/fixtures'

test('列出節點並可選取', () => {
  const onSelect = vi.fn()
  render(<NodeList script={demoScript} selectedId={null} onSelect={onSelect} onReorder={() => {}} />)
  fireEvent.click(screen.getByText(demoScript.nodes[0].id))
  expect(onSelect).toHaveBeenCalledWith(demoScript.nodes[0].id)
})

test('顯示節點首段摘要', () => {
  render(<NodeList script={demoScript} selectedId={null} onSelect={() => {}} onReorder={() => {}} />)
  expect(screen.getByText(demoScript.nodes[0].paragraphs[0].slice(0, 12), { exact: false })).toBeInTheDocument()
})
```

（拖拉互動 jsdom 難模擬，onReorder 邏輯以「上移/下移按鈕同時提供」測：
每列有「↑/↓」按鈕呼叫 onReorder；dnd-kit 拖拉為加強互動，兩者共用同一
onReorder。測按鈕路徑即可。）

- [ ] **Step 2: 實作 + 樣式**

NodeList：ul > li（id + 首段前 20 字），dnd-kit SortableContext + 每列
↑/↓ 按鈕。editor.css：`.editor { display: grid; grid-template-columns: 260px 1fr 340px; height: 100dvh; }` 左欄可捲動。

Run: `cd story && npx vitest run src/editor` → PASS

- [ ] **Step 3: Commit**

```bash
git add story/src story/package.json story/package-lock.json
git commit -m "feat(story): 工作台三欄框架與節點清單排序"
```

---

### Task 11: 舞台預覽（WYSIWYG）

**Files:**
- Create: `story/src/editor/stage/StagePreview.tsx`
- Modify: `story/src/editor/EditorPage.tsx`
- Test: `story/src/editor/stage/StagePreview.test.tsx`

**Interfaces:**
- Consumes: `SceneView` 既有元件、`Layout`。
- Produces:
  ```tsx
  export function StagePreview(props: {
    script: Script; layout: Layout; slug: string
    nodeId: string; paragraphIndex: number
    onParagraphChange(index: number): void
    children?: ReactNode        // BoneEditor 疊加層（Task 14）
  }): JSX.Element
  ```
  實作：以 `PlayState`（`{ nodeId, paragraphIndex, status: 'playing' }`）餵
  `SceneView`，包在固定 480×(視高) 的手機外框 div；段落切換器（‹ › 按鈕 +
  `第 n/總數 段`）。onAdvance/onChoose 傳空函式（預覽不推進劇情，
  選項節點顯示選項樣式）。

- [ ] **Step 1: 失敗測試**

```tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { StagePreview } from './StagePreview'
import { demoScript, demoLayout } from '../../test/fixtures'

test('渲染節點背景與段落文字', () => {
  render(<StagePreview script={demoScript} layout={demoLayout} slug="demo"
    nodeId={demoScript.startNode} paragraphIndex={0} onParagraphChange={() => {}} />)
  expect(screen.getByText(demoScript.nodes[0].paragraphs[0])).toBeInTheDocument()
})

test('段落切換器呼叫 onParagraphChange', () => {
  const onChange = vi.fn()
  render(<StagePreview script={demoScript} layout={demoLayout} slug="demo"
    nodeId={demoScript.startNode} paragraphIndex={0} onParagraphChange={onChange} />)
  fireEvent.click(screen.getByRole('button', { name: '下一段' }))
  expect(onChange).toHaveBeenCalledWith(1)
})
```

- [ ] **Step 2: 實作**（SceneView 直接重用；手機外框 `.stage-frame { width: 480px; aspect-ratio: 9/19.5; position: relative; overflow: hidden; }`，SceneView 的 `.scene` 高度在外框內以 `height: 100%` 生效——`.scene` 是 100dvh，需在 editor.css 以 `.stage-frame .scene { height: 100%; }` 覆寫。）

Run → PASS

- [ ] **Step 3: EditorPage 串接**（中欄放 StagePreview，選取節點時重置 paragraphIndex 0）

Run: `cd story && npm test` → 綠

- [ ] **Step 4: Commit**

```bash
git add story/src
git commit -m "feat(story): 工作台舞台 WYSIWYG 預覽"
```

---

### Task 12: 節點屬性面板（段落/選項/ending/cast）

**Files:**
- Create: `story/src/editor/panels/NodePanel.tsx`
- Modify: `story/src/editor/EditorPage.tsx`
- Test: `story/src/editor/panels/NodePanel.test.tsx`

**Interfaces:**
- Produces:
  ```tsx
  export function NodePanel(props: {
    script: Script
    node: ScriptNode
    onChange(next: ScriptNode): void   // EditorPage 以 next 換掉 nodes 中同 id 節點後 updateScript
  }): JSX.Element
  ```
  面板內容：
  - 段落：每段 textarea、刪除鈕、末端「新增段落」、每段 ↑/↓。
  - 終結型態顯示與編輯：next（下拉選節點）/ choices（每項 text input +
    to 下拉 + 刪除；「新增選項」上限 3）/ ending（title input）。
    型態切換由節點圖負責（Task 16），此面板僅編輯現值——但 to/next 下拉
    在此可改指向。
  - cast：每列（角色下拉[script.characters]、position 下拉、talking
    checkbox、刪除）、「新增角色」。
  - 背景：唯讀顯示目前檔名 + 「更換」鈕（Task 13 接 AssetPicker）。

- [ ] **Step 1: 失敗測試**

```tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { NodePanel } from './NodePanel'
import { demoScript } from '../../test/fixtures'

const node = demoScript.nodes[0]

test('編輯段落文字回傳新節點', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} onChange={onChange} />)
  const box = screen.getAllByRole('textbox')[0]
  fireEvent.change(box, { target: { value: '新文字' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: ['新文字', ...node.paragraphs.slice(1)],
  }))
})

test('新增與刪除段落', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} onChange={onChange} />)
  fireEvent.click(screen.getByRole('button', { name: '新增段落' }))
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [...node.paragraphs, ''],
  }))
})

test('cast 新增角色', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} onChange={onChange} />)
  fireEvent.click(screen.getByRole('button', { name: '新增角色' }))
  expect(onChange).toHaveBeenCalled()
})
```

（注意：`paragraphs` zod 要求每段 min(1)，空字串新段會被 PUT 擋下——
useStory 會把 400 錯誤顯示出來，這是預期行為：使用者填入文字後重送。）

- [ ] **Step 2: 實作 + EditorPage 串接**（右欄依 selectedNodeId 顯示 NodePanel；onChange → 替換 nodes → updateScript）

Run: `cd story && npm test` → 綠

- [ ] **Step 3: Commit**

```bash
git add story/src
git commit -m "feat(story): 節點屬性面板——段落/選項/ending/cast 編輯"
```

---

### Task 13: 背景選擇器與素材上傳

**Files:**
- Create: `story/src/editor/panels/AssetPicker.tsx`
- Create: `story/src/editor/imageTools.ts`（canvas cover 裁切，純函式可測）
- Modify: `story/src/editor/panels/NodePanel.tsx`（背景「更換」接入）
- Test: `story/src/editor/imageTools.test.ts`、`story/src/editor/panels/AssetPicker.test.tsx`

**Interfaces:**
- Produces:
  ```ts
  // imageTools.ts
  export function coverRect(
    srcW: number, srcH: number, dstW: number, dstH: number,
  ): { sx: number; sy: number; sw: number; sh: number }
  // 置中 cover 裁切來源矩形（給 drawImage 用）
  export async function coverToPngBlob(file: File, dstW: number, dstH: number): Promise<Blob>
  // createImageBitmap + canvas，jsdom 測不了，僅由 coverRect 純函式測涵蓋數學
  ```
  ```tsx
  export function AssetPicker(props: {
    slug: string
    category: 'scenes' | `characters/${string}`
    onPick(relPath: string): void       // 'scenes/a.png' 形式（assets/ 相對）
  }): JSX.Element
  ```
  行為：GET `/__editor/assets/<slug>` 過濾出該 category 檔案 → 縮圖格狀
  （img src=`/content/<slug>/assets/<path>?mtime=<mtime>`）；點選即
  onPick。「上傳」input[type=file]：scenes 類先 `coverToPngBlob(file, 900, 1600)`
  再 POST；characters 類直接 POST 原檔。成功後重新抓列表並 onPick 新檔。

- [ ] **Step 1: coverRect 失敗測試**

```ts
import { coverRect } from './imageTools'

test('過寬來源裁左右', () => {
  expect(coverRect(2000, 1600, 900, 1600)).toEqual({ sx: 550, sy: 0, sw: 900, sh: 1600 })
})
test('過高來源裁上下', () => {
  expect(coverRect(900, 3200, 900, 1600)).toEqual({ sx: 0, sy: 800, sw: 900, sh: 1600 })
})
test('等比縮放後置中', () => {
  expect(coverRect(1024, 1536, 900, 1600)).toEqual({ sx: 32, sy: 0, sw: 960, sh: 1536 })
})
```

Run → FAIL → 實作：

```ts
export function coverRect(srcW: number, srcH: number, dstW: number, dstH: number) {
  const scale = Math.max(dstW / srcW, dstH / srcH)
  const sw = Math.round(dstW / scale)
  const sh = Math.round(dstH / scale)
  return { sx: Math.round((srcW - sw) / 2), sy: Math.round((srcH - sh) / 2), sw, sh }
}
```

→ PASS

- [ ] **Step 2: AssetPicker 元件測試**（stub fetch 列表回兩張，斷言縮圖 render、點選呼叫 onPick('scenes/a.png')）→ 實作（上傳流程 jsdom 不測 canvas，僅測「選檔後呼叫 POST」的 fetch 斷言，`coverToPngBlob` 以 `vi.mock` 換成 identity）。

- [ ] **Step 3: NodePanel 接入**（「更換背景」展開 AssetPicker，onPick → `onChange({ ...node, background: relPath })`；上傳部件圖同一元件以 category=characters/<id> 由 Task 15 接）。

Run: `cd story && npm test` → 綠

- [ ] **Step 4: Commit**

```bash
git add story/src
git commit -m "feat(story): 背景選擇器與素材上傳（前端 cover 裁切）"
```

---

### Task 14: 骨骼編輯（舞台拖拉 + 數值面板）

**Files:**
- Create: `story/src/editor/stage/BoneEditor.tsx`
- Create: `story/src/editor/stage/boneMath.ts`（純函式）
- Modify: `story/src/editor/EditorPage.tsx`（「骨骼模式」切換 + 右欄數值）
- Test: `story/src/editor/stage/boneMath.test.ts`、`story/src/editor/stage/BoneEditor.test.tsx`

**Interfaces:**
- Produces:
  ```ts
  // boneMath.ts
  export function dragToDelta(
    dxPx: number, dyPx: number, stageWPx: number, stageHPx: number,
  ): { dcx: number; dtop: number }   // 舞台像素位移 → layout 比例位移
  export function scaleHeight(height: number, wheelDeltaY: number): number
  // 每格 5%：deltaY>0 → height*0.95，<0 → height*1.05，clamp [0.02, 1.2]，round 4 位
  export function applyPartDelta(
    layout: Layout, charId: string, part: 'head' | 'torso' | 'leftArm' | 'rightArm',
    delta: Partial<PartLayout>,
  ): Layout   // 不可變更新
  ```
  ```tsx
  export function BoneEditor(props: {
    layout: Layout; charId: string
    onChange(next: Layout): void
  }): JSX.Element
  // 疊在 StagePreview 的 sprite 上：每部件一個透明外框 div（同 layout 定位），
  // pointerdown/move/up 拖拉 → dragToDelta → applyPartDelta → onChange
  // wheel → scaleHeight → onChange；選中部件高亮 + 顯示名稱
  ```
  EditorPage：骨骼模式開關；開啟時 StagePreview children 放 BoneEditor，
  右欄顯示選中部件的 cx/top/height number input（step 0.005）直接改值。
  onChange → `updateLayout`（全場景生效，磁碟 layout.json）。

- [ ] **Step 1: boneMath 失敗測試**

```ts
import { applyPartDelta, dragToDelta, scaleHeight } from './boneMath'
import { demoLayout } from '../../test/fixtures'

test('dragToDelta 依舞台尺寸換算比例', () => {
  expect(dragToDelta(48, -30, 480, 720)).toEqual({ dcx: 0.1, dtop: -30 / 720 })
})
test('scaleHeight 每格 5% 並 clamp', () => {
  expect(scaleHeight(0.2, 100)).toBeCloseTo(0.19)
  expect(scaleHeight(0.2, -100)).toBeCloseTo(0.21)
  expect(scaleHeight(0.02, 100)).toBe(0.02)
})
test('applyPartDelta 不可變更新', () => {
  const next = applyPartDelta(demoLayout, 'master', 'head', { cx: 0.01 })
  expect(next.characters.master.head.cx).toBeCloseTo(demoLayout.characters.master.head.cx + 0.01)
  expect(demoLayout.characters.master.head.cx).not.toBe(next.characters.master.head.cx)
})
```

（注意：`dragToDelta` 的分母是 sprite 容器的像素尺寸——BoneEditor 以
`getBoundingClientRect()` 取 sprite 框，非整個舞台。）

Run → FAIL → 實作 → PASS

- [ ] **Step 2: BoneEditor 元件**（pointer events；元件測試：render 後對部件框 fireEvent.pointerDown/pointerMove/pointerUp，斷言 onChange 收到位移後的 layout；wheel 案斷言 height 改變）

- [ ] **Step 3: EditorPage 串接**（骨骼模式 toggle、右欄數值輸入 onChange 同步 updateLayout）

Run: `cd story && npm test` → 綠

- [ ] **Step 4: Commit**

```bash
git add story/src
git commit -m "feat(story): 骨骼編輯——舞台拖拉縮放與數值微調"
```

---

### Task 15: 故事屬性面板（標題/intro/blurb）+ 部件圖換檔

**Files:**
- Create: `story/src/editor/panels/StoryPanel.tsx`
- Modify: `story/src/editor/EditorPage.tsx`、`story/src/editor/useStory.ts`（index.json 讀寫）
- Test: `story/src/editor/panels/StoryPanel.test.tsx`

**Interfaces:**
- Produces:
  ```tsx
  export function StoryPanel(props: {
    script: Script
    catalogEntry: CatalogEntry | null
    characters: Character[]
    onScriptMeta(patch: Partial<Pick<Script, 'title' | 'intro' | 'place'>>): void
    onBlurb(blurb: string): void
    onPartFile(charId: string, part: keyof Character['parts']): void  // 開 AssetPicker 換部件檔
  }): JSX.Element
  ```
  useStory 追加：`catalogEntry: CatalogEntry | null` 與
  `updateBlurb(blurb: string): void`（GET/PUT `/__editor/content/index.json`，
  只改該 slug 的 blurb 欄）。左欄無選取節點（或按「故事設定」）時右欄顯示
  StoryPanel。部件換檔：AssetPicker category=`characters/<id>`，onPick →
  更新 `script.characters[].parts[part]` → updateScript。

- [ ] **Step 1: 失敗測試**（title 輸入呼叫 onScriptMeta({title})、blurb 輸入呼叫 onBlurb、部件列表列出 4 部件 × 角色數的換檔鈕）
- [ ] **Step 2: 實作 + useStory 擴充（PUT index.json 同樣 debounce）**
- [ ] **Step 3: `cd story && npm test` 綠 → Commit**

```bash
git add story/src
git commit -m "feat(story): 故事屬性面板與部件圖換檔"
```

---

### Task 16: React Flow 節點圖（結構編輯 + 驗證擋存）

**Files:**
- Create: `story/src/editor/graph/GraphView.tsx`
- Create: `story/src/editor/graph/graphMath.ts`（script ⇄ graph 轉換，純函式）
- Modify: `story/src/editor/EditorPage.tsx`（左欄「結構」分頁）
- Test: `story/src/editor/graph/graphMath.test.ts`

**Interfaces:**
- Consumes: `npm i -D @xyflow/react`。
- Produces:
  ```ts
  // graphMath.ts
  export type GraphModel = {
    nodes: { id: string; label: string; kind: 'next' | 'choices' | 'ending'; isStart: boolean }[]
    edges: { id: string; source: string; target: string; label: string }[]
    // next 邊 label ''；choice 邊 label = choice.text；ending 無出邊
  }
  export function scriptToGraph(script: Script): GraphModel
  export function retarget(
    script: Script, edgeId: string, newTarget: string,
  ): { ok: true; script: Script } | { ok: false; error: string }
  // edgeId 格式 `${nodeId}:next` 或 `${nodeId}:choice:${index}`；改完跑
  // validateScript，失敗回 error
  export function addNode(script: Script, afterId: string): { script: Script; newId: string }
  // 新節點插在 afterId 之後：afterId 原終結轉移到新節點、afterId.next=newId、
  // 新節點繼承 afterId 的 background、paragraphs=['（新段落）']
  export function removeNode(script: Script, id: string): { ok: true; script: Script } | { ok: false; error: string }
  // 有入邊或為 startNode → ok:false
  ```
  GraphView：@xyflow/react 呈現（dagre 自動排版不引入——以簡單縱向分層：
  BFS 深度 × 200px y、同層 index × 240px x）；`onConnect`/edge 重接呼叫
  retarget，失敗 toast 顯示 error 且不套用；節點右鍵選單（或節點上按鈕）
  「在後面插入節點」「刪除節點」。所有成功變更 → updateScript。

- [ ] **Step 1: graphMath 失敗測試**

```ts
import { addNode, removeNode, retarget, scriptToGraph } from './graphMath'
import { demoScript } from '../../test/fixtures'

test('scriptToGraph 產生 choice 邊', () => {
  const graph = scriptToGraph(demoScript)
  const choiceNode = demoScript.nodes.find((n) => n.choices)!
  const edges = graph.edges.filter((e) => e.source === choiceNode.id)
  expect(edges).toHaveLength(choiceNode.choices!.length)
  expect(edges[0].label).toBe(choiceNode.choices![0].text)
})

test('retarget 改 next 並驗證', () => {
  const nextNode = demoScript.nodes.find((n) => n.next)!
  const ending = demoScript.nodes.find((n) => n.ending)!
  const result = retarget(demoScript, `${nextNode.id}:next`, ending.id)
  expect(result.ok).toBe(true)
})

test('retarget 指向不存在節點回 error', () => {
  const nextNode = demoScript.nodes.find((n) => n.next)!
  const result = retarget(demoScript, `${nextNode.id}:next`, 'nope')
  expect(result.ok).toBe(false)
})

test('addNode 插入並轉移終結', () => {
  const first = demoScript.nodes[0]
  const { script, newId } = addNode(demoScript, first.id)
  const patched = script.nodes.find((n) => n.id === first.id)!
  expect(patched.next).toBe(newId)
  expect(script.nodes.find((n) => n.id === newId)).toBeTruthy()
})

test('removeNode 擋 startNode 與有入邊節點', () => {
  expect(removeNode(demoScript, demoScript.startNode).ok).toBe(false)
})
```

Run → FAIL → 實作 → PASS

- [ ] **Step 2: GraphView 元件**（@xyflow/react；元件測試只驗 scriptToGraph 餵入後節點數正確 render——xyflow 在 jsdom 需 `ResizeObserver` polyfill，`src/test/setup.ts` 加 stub：`globalThis.ResizeObserver ??= class { observe(){} unobserve(){} disconnect(){} }`）

- [ ] **Step 3: EditorPage 串接**（左欄分頁「節點/結構」切換 NodeList 與 GraphView）

Run: `cd story && npm test` → 綠

- [ ] **Step 4: Commit**

```bash
git add story/src story/package.json story/package-lock.json
git commit -m "feat(story): React Flow 節點圖結構編輯"
```

---

### Task 17: 整合驗收——bundle 檢查、端到端手動走測、文件

**Files:**
- Modify: `story/README.md`（若無則建立：工作台使用說明一節）
- Modify: `CLAUDE.md`（repo 地圖 story 一行帶到 /editor）

**Interfaces:** 無新介面；驗收既有承諾。

- [ ] **Step 1: production bundle 檢查**

```bash
cd story && npm run build
grep -l "xyflow\|EditorPage\|dnd-kit" dist/assets/index-*.js && echo "LEAK" || echo "CLEAN"
```

Expected: CLEAN（主 bundle 無 editor 相關碼；editor lazy chunk 只在 DEV，
production build 因 `import.meta.env.DEV` 為 false 且 route 被搖掉，
理想上連 chunk 都不產——若仍產出 chunk 但主 bundle 不引用，亦可接受，
記錄實際結果）。

- [ ] **Step 2: 全套測試與 lint**

```bash
cd story && npm test && npm run build
cd ../scripts && uv run pytest -q
```

Expected: 全綠。

- [ ] **Step 3: 手動端到端走測（開 dev server 逐項確認）**

```bash
cd story && npx vite dev
```

清單（人工過一遍，記錄結果）：
1. `/editor` 開啟、選《千日之後》。
2. 改一段文字 → 停 1 秒 → `git diff story/public/content` 看到寫入。
3. 另開終端直接編輯 script.json（模擬 Claude）→ 工作台 toast +
   內容更新。
4. 骨骼模式拖拉安妮的頭 → layout.json 變更 → `/play/tower-of-london-anne`
   新分頁重整後位置一致。
5. 節點圖拉線把某 choice 指向另一節點 → 存檔成功；指向刪除後不存在
   節點的操作被擋（toast）。
6. 背景更換：從清單挑另一張 → 舞台預覽即時換圖。
7. 上傳一張任意比例圖 → 變 900×1600 背景可選。
8. `/play` 正常遊玩到任一結局（骨骼資料化後全流程回歸）。

- [ ] **Step 4: 文件**

story/README.md 增「工作台」節：啟動方式（`npm run dev` → `/editor`）、
能編什麼、磁碟即真相與 SSE 行為、pngquant 選配、dev 模式 `/play` 需手動
重整的已知偏差。CLAUDE.md 的 story 相關行帶一句工作台入口。

- [ ] **Step 5: Commit**

```bash
git add story/README.md CLAUDE.md
git commit -m "docs(story): 工作台使用說明與驗收"
```

---

## Self-Review 紀錄

- Spec 覆蓋：文本（T12/T15）、順序（T10 段落與節點排序、T12 段落排序）、
  結構圖（T16）、骨骼（T1-T4、T14）、站位 talking（T12）、背景/部件素材
  （T13/T15）、上傳規格化（T13 前端 canvas）、catalog blurb（T5/T15）、
  即時雙向同步（T7/T9）、驗證擋存（T6/T16）、不進 prod bundle（T9/T17）、
  遷移與視覺回歸（T4/T17）。無遺漏。
- 型別一致性：`Layout/PartLayout`（T1）為 T3/T4/T9/T14 共用；
  `ContentEvent` 在 plugin（T7）與 api.ts（T9）各自宣告同形狀（跨
  node/browser 邊界，刻意重複宣告）；`contentUrl`（T4）供 T5 使用。
- 已知偏差（記錄於 T7/T17）：dev 模式 `/play` 對 content 變更不再自動
  full-reload，需手動重整。
