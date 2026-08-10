import { useRef, useState, type PointerEvent, type WheelEvent } from 'react'
import { partStyle } from '../../components/CharacterSprite'
import type { Layout } from '../../engine/schema'
import { applyPartDelta, dragToDelta, scaleHeight, type PartKey } from './boneMath'

const PARTS: PartKey[] = ['head', 'torso', 'leftArm', 'rightArm']
const PART_LABEL: Record<PartKey, string> = {
  head: '頭', torso: '身體', leftArm: '左臂', rightArm: '右臂',
}

type DragState = { part: PartKey; lastX: number; lastY: number }

// 疊在 StagePreview 的 sprite 上：外框幾何與 CharacterSprite 的 .sprite 一致
// （見 editor.css .bone-editor），部件框沿用同一組 partStyle 百分比公式，
// 拖拉分母是這個外框自身的像素尺寸，非整個舞台。
export function BoneEditor(props: {
  layout: Layout
  charId: string
  onChange(next: Layout): void
  // 選中部件變化時通知（EditorPage 右欄數值面板同步顯示同一部件）；
  // 不影響 BoneEditor 自身高亮，純粹是額外通知，未提供時照常運作。
  onSelectPart?(part: PartKey): void
}) {
  const { layout, charId, onChange, onSelectPart } = props
  const containerRef = useRef<HTMLDivElement>(null)
  const dragRef = useRef<DragState | null>(null)
  const [selectedPart, setSelectedPart] = useState<PartKey | null>(null)

  const charLayout = layout.characters[charId]

  const selectPart = (part: PartKey) => {
    setSelectedPart(part)
    onSelectPart?.(part)
  }

  const handlePointerDown = (part: PartKey) => (e: PointerEvent<HTMLDivElement>) => {
    selectPart(part)
    dragRef.current = { part, lastX: e.clientX, lastY: e.clientY }
    e.currentTarget.setPointerCapture?.(e.pointerId)
  }

  const handlePointerMove = (e: PointerEvent<HTMLDivElement>) => {
    const drag = dragRef.current
    const rect = containerRef.current?.getBoundingClientRect()
    if (!drag || !rect || !rect.width || !rect.height) return
    const dxPx = e.clientX - drag.lastX
    const dyPx = e.clientY - drag.lastY
    dragRef.current = { ...drag, lastX: e.clientX, lastY: e.clientY }
    if (dxPx === 0 && dyPx === 0) return
    const { dcx, dtop } = dragToDelta(dxPx, dyPx, rect.width, rect.height)
    onChange(applyPartDelta(layout, charId, drag.part, { cx: dcx, top: dtop }))
  }

  const handlePointerUp = (e: PointerEvent<HTMLDivElement>) => {
    dragRef.current = null
    e.currentTarget.releasePointerCapture?.(e.pointerId)
  }

  const handleWheel = (part: PartKey) => (e: WheelEvent<HTMLDivElement>) => {
    e.preventDefault()
    selectPart(part)
    const current = charLayout[part].height
    const next = scaleHeight(current, e.deltaY)
    onChange(applyPartDelta(layout, charId, part, { height: next - current }))
  }

  return (
    <div className="bone-editor" ref={containerRef} data-testid="bone-editor">
      {PARTS.map((part) => (
        <div
          key={part}
          data-testid={`bone-part-${part}`}
          className={[
            'bone-editor__part',
            selectedPart === part ? 'bone-editor__part--selected' : '',
          ].filter(Boolean).join(' ')}
          style={partStyle(charLayout[part])}
          onPointerDown={handlePointerDown(part)}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onWheel={handleWheel(part)}
        >
          {selectedPart === part && <span className="bone-editor__label">{PART_LABEL[part]}</span>}
        </div>
      ))}
    </div>
  )
}
