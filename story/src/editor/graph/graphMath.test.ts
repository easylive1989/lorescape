import { addNode, removeNode, retarget, scriptToGraph } from './graphMath'
import { demoScript } from '../../test/fixtures'

test('scriptToGraph 產生 choice 邊', () => {
  const graph = scriptToGraph(demoScript)
  const choiceNode = demoScript.nodes.find((n) => n.choices)!
  const edges = graph.edges.filter((e) => e.source === choiceNode.id)
  expect(edges).toHaveLength(choiceNode.choices!.length)
  expect(edges[0].label).toBe(choiceNode.choices![0].text)
})

test('scriptToGraph 產生 next 邊，label 為空字串', () => {
  const graph = scriptToGraph(demoScript)
  const nextNode = demoScript.nodes.find((n) => n.next)!
  const edge = graph.edges.find((e) => e.source === nextNode.id)!
  expect(edge.target).toBe(nextNode.next)
  expect(edge.label).toBe('')
})

test('scriptToGraph ending 節點無出邊，且 isStart 只標記 startNode', () => {
  const graph = scriptToGraph(demoScript)
  const endingNode = demoScript.nodes.find((n) => n.ending)!
  expect(graph.edges.some((e) => e.source === endingNode.id)).toBe(false)
  const startEntries = graph.nodes.filter((n) => n.isStart)
  expect(startEntries).toHaveLength(1)
  expect(startEntries[0].id).toBe(demoScript.startNode)
})

test('retarget 改 next 並驗證', () => {
  const nextNode = demoScript.nodes.find((n) => n.next)!
  const ending = demoScript.nodes.find((n) => n.ending)!
  const result = retarget(demoScript, `${nextNode.id}:next`, ending.id)
  expect(result.ok).toBe(true)
  if (result.ok) {
    const patched = result.script.nodes.find((n) => n.id === nextNode.id)!
    expect(patched.next).toBe(ending.id)
  }
})

test('retarget 改 choice 並驗證', () => {
  const choiceNode = demoScript.nodes.find((n) => n.choices)!
  const otherEnding = demoScript.nodes.find((n) => n.ending && n.id !== choiceNode.choices![0].to)!
  const result = retarget(demoScript, `${choiceNode.id}:choice:0`, otherEnding.id)
  expect(result.ok).toBe(true)
  if (result.ok) {
    const patched = result.script.nodes.find((n) => n.id === choiceNode.id)!
    expect(patched.choices![0].to).toBe(otherEnding.id)
  }
})

test('retarget 指向不存在節點回 error', () => {
  const nextNode = demoScript.nodes.find((n) => n.next)!
  const result = retarget(demoScript, `${nextNode.id}:next`, 'nope')
  expect(result.ok).toBe(false)
  if (!result.ok) expect(result.error).toMatch(/nope/)
})

test('retarget 不明的 edgeId 格式回 error', () => {
  const result = retarget(demoScript, 'not-a-real-edge-id', 'n1')
  expect(result.ok).toBe(false)
})

test('addNode 插入並轉移終結（choices 型態節點）', () => {
  const first = demoScript.nodes[0]
  const { script, newId } = addNode(demoScript, first.id)
  const patched = script.nodes.find((n) => n.id === first.id)!
  expect(patched.next).toBe(newId)
  expect(patched.choices).toBeUndefined()
  const inserted = script.nodes.find((n) => n.id === newId)!
  expect(inserted).toBeTruthy()
  expect(inserted.choices).toEqual(first.choices)
  expect(inserted.paragraphs).toEqual(['（新段落）'])
  expect(inserted.background).toBe(first.background)
})

test('addNode 產生的新 id 不與現有節點碰撞', () => {
  const { script, newId } = addNode(demoScript, demoScript.nodes[0].id)
  const idCounts = script.nodes.filter((n) => n.id === newId).length
  expect(idCounts).toBe(1)
})

test('addNode 插入後的 script 仍通過驗證', () => {
  const { script } = addNode(demoScript, demoScript.nodes[0].id)
  expect(() => scriptToGraph(script)).not.toThrow()
})

test('removeNode 擋 startNode', () => {
  const result = removeNode(demoScript, demoScript.startNode)
  expect(result.ok).toBe(false)
})

test('removeNode 擋有入邊的節點', () => {
  const result = removeNode(demoScript, 'end-a')
  expect(result.ok).toBe(false)
})

test('removeNode 刪除無入邊、非 startNode 的節點', () => {
  const result = removeNode(demoScript, 'n2')
  expect(result.ok).toBe(true)
  if (result.ok) {
    expect(result.script.nodes.find((n) => n.id === 'n2')).toBeUndefined()
  }
})
