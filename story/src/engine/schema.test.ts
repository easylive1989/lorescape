import { validateScript, catalogSchema } from './schema'
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

test('catalogSchema 接受合法目錄', () => {
  const valid = { stories: [{ slug: 's', title: 't', place: 'p', blurb: 'b' }] }
  expect(catalogSchema.parse(valid).stories[0].slug).toBe('s')
})

test('catalogSchema 拒絕缺欄位', () => {
  const invalid = { stories: [{ slug: 's', title: 't', place: 'p' }] }
  expect(() => catalogSchema.parse(invalid)).toThrow()
})
