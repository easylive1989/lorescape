import { initState, advance, choose, currentNode, type PlayState } from './player'
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
  let s: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing' }
  s = choose(demoScript, s, 0)
  expect(s).toEqual({ nodeId: 'end-a', paragraphIndex: 0, status: 'playing' })
})

test('ending 節點段落用盡後 status ended', () => {
  let s: PlayState = { nodeId: 'end-a', paragraphIndex: 0, status: 'playing' }
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
