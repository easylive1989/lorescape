import { useCallback, useMemo, useState } from 'react'
import {
  Background,
  Controls,
  Handle,
  Position,
  ReactFlow,
  type Connection,
  type Edge,
  type Node,
  type NodeProps,
  type NodeTypes,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'
import type { Script } from '../../engine/schema'
import { addNode, removeNode, retarget, scriptToGraph, type GraphModel } from './graphMath'

const LAYER_Y = 200
const COLUMN_X = 240

type GraphNodeData = {
  label: string
  kind: 'next' | 'choices' | 'ending'
  isStart: boolean
  choiceCount: number
  onInsertAfter(id: string): void
  onDelete(id: string): void
}

// BFS 深度 × 200px y、同層 index × 240px x（不引入 dagre）；無法從 startNode
// 走到的節點（孤立節點）排在最深一層之後，避免跟主線重疊。
function computeLayout(graph: GraphModel): Record<string, { x: number; y: number }> {
  const adjacency = new Map<string, string[]>()
  for (const edge of graph.edges) {
    const list = adjacency.get(edge.source) ?? []
    list.push(edge.target)
    adjacency.set(edge.source, list)
  }

  const startId = graph.nodes.find((n) => n.isStart)?.id ?? graph.nodes[0]?.id
  const depth = new Map<string, number>()
  if (startId) {
    depth.set(startId, 0)
    const queue = [startId]
    while (queue.length > 0) {
      const current = queue.shift()!
      const currentDepth = depth.get(current)!
      for (const target of adjacency.get(current) ?? []) {
        if (!depth.has(target)) {
          depth.set(target, currentDepth + 1)
          queue.push(target)
        }
      }
    }
  }

  let maxDepth = -1
  for (const d of depth.values()) maxDepth = Math.max(maxDepth, d)
  const orphanDepth = maxDepth + 1

  const layerCounts = new Map<number, number>()
  const positions: Record<string, { x: number; y: number }> = {}
  for (const node of graph.nodes) {
    const d = depth.get(node.id) ?? orphanDepth
    const index = layerCounts.get(d) ?? 0
    layerCounts.set(d, index + 1)
    positions[node.id] = { x: index * COLUMN_X, y: d * LAYER_Y }
  }
  return positions
}

// edgeId 對照表：choice 型節點每個選項各自一個 source handle（choice-0、
// choice-1…），next 型節點固定一個 handle（next）。從 sourceHandle 反推
// retarget 需要的 edgeId，抽成純函式方便單獨測試。
export function connectionEdgeId(source: string, sourceHandle: string | null): string | null {
  if (!sourceHandle) return null
  if (sourceHandle === 'next') return `${source}:next`
  const choiceMatch = sourceHandle.match(/^choice-(\d+)$/)
  if (choiceMatch) return `${source}:choice:${choiceMatch[1]}`
  return null
}

function ScriptNodeCard({ id, data }: NodeProps<Node<GraphNodeData>>) {
  const { label, kind, isStart, choiceCount, onInsertAfter, onDelete } = data
  return (
    <div className={`graph-node graph-node--${kind}${isStart ? ' graph-node--start' : ''}`}>
      <Handle type="target" position={Position.Top} />
      <div className="graph-node__label">
        {isStart && <span className="graph-node__start-badge">起始</span>}
        {label}
      </div>
      <div className="graph-node__actions">
        <button type="button" aria-label={`在 ${id} 後面插入節點`} onClick={() => onInsertAfter(id)}>
          在後面插入節點
        </button>
        <button type="button" aria-label={`刪除節點 ${id}`} onClick={() => onDelete(id)}>
          刪除節點
        </button>
      </div>
      {kind === 'next' && <Handle type="source" position={Position.Bottom} id="next" />}
      {kind === 'choices' &&
        Array.from({ length: choiceCount }, (_, index) => (
          <Handle
            key={index}
            type="source"
            position={Position.Bottom}
            id={`choice-${index}`}
            style={{ left: `${((index + 1) / (choiceCount + 1)) * 100}%` }}
          />
        ))}
    </div>
  )
}

const nodeTypes: NodeTypes = { scriptNode: ScriptNodeCard }

export function GraphView(props: { script: Script; onScriptChange(next: Script): void }) {
  const { script, onScriptChange } = props
  const [toastError, setToastError] = useState<string | null>(null)

  const graph = useMemo(() => scriptToGraph(script), [script])
  const positions = useMemo(() => computeLayout(graph), [graph])

  const applyRetarget = useCallback(
    (edgeId: string, newTarget: string) => {
      const result = retarget(script, edgeId, newTarget)
      if (!result.ok) {
        setToastError(result.error)
        return
      }
      onScriptChange(result.script)
    },
    [script, onScriptChange],
  )

  const handleInsertAfter = useCallback(
    (afterId: string) => {
      const { script: next } = addNode(script, afterId)
      onScriptChange(next)
    },
    [script, onScriptChange],
  )

  const handleDelete = useCallback(
    (id: string) => {
      const result = removeNode(script, id)
      if (!result.ok) {
        setToastError(result.error)
        return
      }
      onScriptChange(result.script)
    },
    [script, onScriptChange],
  )

  const nodes: Node<GraphNodeData>[] = useMemo(
    () =>
      graph.nodes.map((node) => {
        const scriptNode = script.nodes.find((n) => n.id === node.id)
        return {
          id: node.id,
          type: 'scriptNode',
          position: positions[node.id] ?? { x: 0, y: 0 },
          // 量測完成前（含 jsdom 測試環境，ResizeObserver 從不觸發真正量測）
          // xyflow 預設把節點畫成 visibility:hidden；給定初始尺寸讓節點在
          // 量測完成前就先以此尺寸可見，真正瀏覽器量測完成後會自動覆蓋。
          initialWidth: 200,
          initialHeight: 110,
          data: {
            label: node.label,
            kind: node.kind,
            isStart: node.isStart,
            choiceCount: scriptNode?.choices?.length ?? 0,
            onInsertAfter: handleInsertAfter,
            onDelete: handleDelete,
          },
        }
      }),
    [graph, positions, script, handleInsertAfter, handleDelete],
  )

  const edges: Edge[] = useMemo(
    () =>
      graph.edges.map((edge) => {
        const choiceMatch = edge.id.match(/:choice:(\d+)$/)
        return {
          id: edge.id,
          source: edge.source,
          target: edge.target,
          sourceHandle: choiceMatch ? `choice-${choiceMatch[1]}` : 'next',
          label: edge.label || undefined,
          reconnectable: true,
        }
      }),
    [graph],
  )

  const onConnect = useCallback(
    (connection: Connection) => {
      const edgeId = connectionEdgeId(connection.source, connection.sourceHandle)
      if (!edgeId || !connection.target) return
      applyRetarget(edgeId, connection.target)
    },
    [applyRetarget],
  )

  const onReconnect = useCallback(
    (oldEdge: Edge, newConnection: Connection) => {
      if (!newConnection.target) return
      applyRetarget(oldEdge.id, newConnection.target)
    },
    [applyRetarget],
  )

  return (
    <div className="graph-view">
      {toastError && (
        <div className="graph-view__toast" role="alert">
          <span>{toastError}</span>
          <button type="button" onClick={() => setToastError(null)}>關閉</button>
        </div>
      )}
      <div className="graph-view__canvas">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          nodeTypes={nodeTypes}
          onConnect={onConnect}
          onReconnect={onReconnect}
          // 佈局固定為 BFS 分層（不引入 dagre，見 computeLayout），節點不開放
          // 手動拖曳；順帶避開 react-flow 節點拖曳綁定的 d3-drag mousedown
          // handler 在 jsdom 下對 userEvent 合成事件拋例外的相容性問題。
          nodesDraggable={false}
          fitView
        >
          <Background />
          <Controls />
        </ReactFlow>
      </div>
    </div>
  )
}
