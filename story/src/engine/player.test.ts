import {
  initState, advance, choose, currentNode,
  matches, visibleParagraphs, visibleChoices, type PlayState,
} from './player'
import { demoScript, flagScript } from '../test/fixtures'

test('initState 從 startNode 第 0 段開始', () => {
  expect(initState(demoScript)).toEqual({ nodeId: 'n1', paragraphIndex: 0, status: 'playing', flags: [] })
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
  let s: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing', flags: [] }
  s = choose(demoScript, s, 0)
  expect(s).toEqual({ nodeId: 'end-a', paragraphIndex: 0, status: 'playing', flags: [] })
})

test('ending 節點段落用盡後 status ended', () => {
  let s: PlayState = { nodeId: 'end-a', paragraphIndex: 0, status: 'playing', flags: [] }
  s = advance(demoScript, s)
  expect(s.status).toBe('ended')
})

test('choosing 狀態下 advance 不動', () => {
  const s = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing' as const, flags: [] }
  expect(advance(demoScript, s)).toEqual(s)
})

test('currentNode 取得節點', () => {
  expect(currentNode(demoScript, initState(demoScript)).id).toBe('n1')
})

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

test('advance 經過 next 跳轉時 flags 原封不動', () => {
  // harbor 是 next 型節點：段落用盡後直接跳到 next 指的節點，中間不經過選擇。
  // flags 要在這個跳轉裡完整留存，故事才能在跳轉之後的結局節點讀到先前設下的 flag。
  const s: PlayState = { nodeId: 'harbor', paragraphIndex: 0, status: 'playing', flags: ['sealed', 'warned'] }
  expect(advance(flagScript, s).flags).toEqual(['sealed', 'warned'])
})
