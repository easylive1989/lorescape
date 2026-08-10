import { validateScript, type Script, type ScriptNode } from '../../engine/schema'

export type GraphModel = {
  nodes: { id: string; label: string; kind: 'next' | 'choices' | 'ending'; isStart: boolean }[]
  edges: { id: string; source: string; target: string; label: string }[]
  // next 邊 label ''；choice 邊 label = choice.text；ending 無出邊
}

function nodeKind(node: ScriptNode): 'next' | 'choices' | 'ending' {
  if (node.next !== undefined) return 'next'
  if (node.choices !== undefined) return 'choices'
  return 'ending'
}

// 拿掉 next/choices/ending 三個終結欄位，只留其餘欄位（供 addNode 轉移終結時
// 先清空舊終結，避免 JSON 殘留多個終結欄位讓 validateScript 判「非恰好一個」失敗）。
function withoutTerminal(node: ScriptNode): Omit<ScriptNode, 'next' | 'choices' | 'ending'> {
  const { next: _next, choices: _choices, ending: _ending, ...rest } = node
  return rest
}

export function scriptToGraph(script: Script): GraphModel {
  const nodes = script.nodes.map((node) => ({
    id: node.id,
    label: node.id,
    kind: nodeKind(node),
    isStart: node.id === script.startNode,
  }))

  const edges: GraphModel['edges'] = []
  for (const node of script.nodes) {
    if (node.next !== undefined) {
      edges.push({ id: `${node.id}:next`, source: node.id, target: node.next, label: '' })
    } else if (node.choices !== undefined) {
      node.choices.forEach((choice, index) => {
        edges.push({ id: `${node.id}:choice:${index}`, source: node.id, target: choice.to, label: choice.text })
      })
    }
  }

  return { nodes, edges }
}

type RetargetResult = { ok: true; script: Script } | { ok: false; error: string }

// edgeId 格式 `${nodeId}:next` 或 `${nodeId}:choice:${index}`；改完跑
// validateScript，失敗回 error
export function retarget(script: Script, edgeId: string, newTarget: string): RetargetResult {
  const choiceMatch = edgeId.match(/^(.*):choice:(\d+)$/)
  const nextMatch = edgeId.match(/^(.*):next$/)

  let nodes: ScriptNode[]
  if (choiceMatch) {
    const [, nodeId, indexStr] = choiceMatch
    const index = Number(indexStr)
    nodes = script.nodes.map((node) =>
      node.id === nodeId && node.choices
        ? { ...node, choices: node.choices.map((choice, i) => (i === index ? { ...choice, to: newTarget } : choice)) }
        : node,
    )
  } else if (nextMatch) {
    const [, nodeId] = nextMatch
    nodes = script.nodes.map((node) => (node.id === nodeId ? { ...node, next: newTarget } : node))
  } else {
    return { ok: false, error: `不明的邊格式：${edgeId}` }
  }

  const next = { ...script, nodes }
  try {
    validateScript(next)
    return { ok: true, script: next }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

function generateNodeId(script: Script): string {
  const existing = new Set(script.nodes.map((n) => n.id))
  let counter = script.nodes.length + 1
  let id = `n-${counter}`
  while (existing.has(id)) {
    counter += 1
    id = `n-${counter}`
  }
  return id
}

// 新節點插在 afterId 之後：afterId 原終結轉移到新節點、afterId.next=newId、
// 新節點繼承 afterId 的 background、paragraphs=['（新段落）']
export function addNode(script: Script, afterId: string): { script: Script; newId: string } {
  const afterNode = script.nodes.find((n) => n.id === afterId)
  if (!afterNode) throw new Error(`節點不存在：${afterId}`)

  const newId = generateNodeId(script)
  const terminal: Partial<Pick<ScriptNode, 'next' | 'choices' | 'ending'>> =
    afterNode.next !== undefined
      ? { next: afterNode.next }
      : afterNode.choices !== undefined
        ? { choices: afterNode.choices }
        : afterNode.ending !== undefined
          ? { ending: afterNode.ending }
          : {}

  const newNode: ScriptNode = {
    id: newId,
    background: afterNode.background,
    paragraphs: ['（新段落）'],
    ...terminal,
  }

  const patchedAfter: ScriptNode = { ...withoutTerminal(afterNode), next: newId }

  const afterIndex = script.nodes.findIndex((n) => n.id === afterId)
  const nodes = [...script.nodes]
  nodes[afterIndex] = patchedAfter
  nodes.splice(afterIndex + 1, 0, newNode)

  return { script: { ...script, nodes }, newId }
}

type RemoveNodeResult = { ok: true; script: Script } | { ok: false; error: string }

// 有入邊或為 startNode → ok:false
export function removeNode(script: Script, id: string): RemoveNodeResult {
  if (id === script.startNode) return { ok: false, error: `不可刪除起始節點：${id}` }

  const hasIncoming = script.nodes.some(
    (node) => node.next === id || (node.choices?.some((choice) => choice.to === id) ?? false),
  )
  if (hasIncoming) return { ok: false, error: `節點 ${id} 有其他節點指向它，無法刪除` }

  const next = { ...script, nodes: script.nodes.filter((n) => n.id !== id) }
  try {
    validateScript(next)
    return { ok: true, script: next }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}
