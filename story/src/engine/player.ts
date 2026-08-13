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
