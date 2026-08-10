import {
  DndContext,
  type DragEndEvent,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  SortableContext,
  arrayMove,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import type { Script } from '../../engine/schema'

const SUMMARY_LENGTH = 20

function NodeListItem(props: {
  id: string
  summary: string
  selected: boolean
  isFirst: boolean
  isLast: boolean
  onSelect(id: string): void
  onMoveUp(id: string): void
  onMoveDown(id: string): void
}) {
  const { id, summary, selected, isFirst, isLast, onSelect, onMoveUp, onMoveDown } = props
  const { attributes, listeners, setNodeRef, transform, transition } = useSortable({ id })

  return (
    <li
      ref={setNodeRef}
      className={`node-list__item${selected ? ' node-list__item--selected' : ''}`}
      style={{ transform: CSS.Transform.toString(transform), transition }}
    >
      {/* 拖曳的 role/tabIndex 只掛在把手按鈕上，避免覆蓋 <li> 的 listitem role */}
      <button
        type="button"
        className="node-list__handle"
        aria-label="拖曳排序"
        {...attributes}
        {...listeners}
      >
        ⠿
      </button>
      <button type="button" className="node-list__label" onClick={() => onSelect(id)}>
        <span className="node-list__id">{id}</span>
        <span className="node-list__summary">{summary}</span>
      </button>
      <div className="node-list__order-buttons">
        <button type="button" aria-label="上移" disabled={isFirst} onClick={() => onMoveUp(id)}>
          ↑
        </button>
        <button type="button" aria-label="下移" disabled={isLast} onClick={() => onMoveDown(id)}>
          ↓
        </button>
      </div>
    </li>
  )
}

export function NodeList(props: {
  script: Script
  selectedId: string | null
  onSelect(id: string): void
  onReorder(ids: string[]): void
}) {
  const { script, selectedId, onSelect, onReorder } = props
  const ids = script.nodes.map((n) => n.id)
  const sensors = useSensors(useSensor(PointerSensor))

  const moveBy = (id: string, delta: number) => {
    const index = ids.indexOf(id)
    const target = index + delta
    if (target < 0 || target >= ids.length) return
    onReorder(arrayMove(ids, index, target))
  }

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const from = ids.indexOf(String(active.id))
    const to = ids.indexOf(String(over.id))
    if (from === -1 || to === -1) return
    onReorder(arrayMove(ids, from, to))
  }

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
      <SortableContext items={ids} strategy={verticalListSortingStrategy}>
        <ul className="node-list">
          {script.nodes.map((node, index) => (
            <NodeListItem
              key={node.id}
              id={node.id}
              summary={node.paragraphs[0]?.slice(0, SUMMARY_LENGTH) ?? ''}
              selected={node.id === selectedId}
              isFirst={index === 0}
              isLast={index === script.nodes.length - 1}
              onSelect={onSelect}
              onMoveUp={(id) => moveBy(id, -1)}
              onMoveDown={(id) => moveBy(id, 1)}
            />
          ))}
        </ul>
      </SortableContext>
    </DndContext>
  )
}
