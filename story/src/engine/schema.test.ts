import { validateScript } from './schema'
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
