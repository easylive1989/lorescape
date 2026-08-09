import { validateScript, validateLayout } from './schema'
import { demoScript } from '../test/fixtures'

test('合法劇本通過並回傳型別化物件', () => {
  expect(validateScript(demoScript).startNode).toBe('n1')
})

test('startNode 不存在時 throw', () => {
  expect(() => validateScript({ ...demoScript, startNode: 'nope' })).toThrow(/startNode/)
})

test('choices 指向不存在節點時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].choices![0].to = 'ghost'
  expect(() => validateScript(bad)).toThrow(/ghost/)
})

test('節點 next/choices/ending 必須恰好一個', () => {
  const bad = structuredClone(demoScript)
  delete (bad.nodes[2] as Record<string, unknown>).ending
  expect(() => validateScript(bad)).toThrow(/恰好一個/)
})

test('cast 引用未定義角色時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].cast![0].character = 'ghost'
  expect(() => validateScript(bad)).toThrow(/ghost/)
})

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
