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
