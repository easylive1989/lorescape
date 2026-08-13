import { validateScript, catalogSchema, declaredFlags } from './schema'
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

test('同一節點的 cast 出現重複角色時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.nodes[0].cast = [
    { character: 'master', position: 'left' },
    { character: 'master', position: 'right' },
  ]
  expect(() => validateScript(bad)).toThrow(/重複上台/)
})

test('同一節點的 cast 出現重複站位時 throw', () => {
  const bad = structuredClone(demoScript)
  bad.characters.push({ id: 'apprentice', name: '學徒', image: 'characters/apprentice/full.png' })
  bad.nodes[0].cast = [
    { character: 'master', position: 'center' },
    { character: 'apprentice', position: 'center' },
  ]
  expect(() => validateScript(bad)).toThrow(/站位重複/)
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
