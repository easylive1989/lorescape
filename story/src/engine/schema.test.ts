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
