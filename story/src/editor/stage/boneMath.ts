import type { Layout, PartLayout } from '../../engine/schema'

export type PartKey = 'head' | 'torso' | 'leftArm' | 'rightArm'

const WHEEL_STEP = 0.05
const MIN_HEIGHT = 0.02
const MAX_HEIGHT = 1.2
const ROUND_PRECISION = 10000

// 拖拉像素位移 → layout 比例位移。分母是 sprite 容器（呼叫端以
// getBoundingClientRect() 取自身框），不是整個舞台。
export function dragToDelta(
  dxPx: number, dyPx: number, stageWPx: number, stageHPx: number,
): { dcx: number; dtop: number } {
  return { dcx: dxPx / stageWPx, dtop: dyPx / stageHPx }
}

// 滾輪縮放：每格 5%，deltaY>0（往下滾）縮小、<0 放大，clamp 後取小數 4 位。
export function scaleHeight(height: number, wheelDeltaY: number): number {
  const factor = wheelDeltaY > 0 ? 1 - WHEEL_STEP : 1 + WHEEL_STEP
  const clamped = Math.min(MAX_HEIGHT, Math.max(MIN_HEIGHT, height * factor))
  return Math.round(clamped * ROUND_PRECISION) / ROUND_PRECISION
}

// 對單一部件套用增量（不可變更新）；delta 各欄位為相對現值的增量。
export function applyPartDelta(
  layout: Layout,
  charId: string,
  part: PartKey,
  delta: Partial<PartLayout>,
): Layout {
  const charLayout = layout.characters[charId]
  const current = charLayout[part]
  const next: PartLayout = {
    cx: current.cx + (delta.cx ?? 0),
    top: current.top + (delta.top ?? 0),
    height: current.height + (delta.height ?? 0),
  }
  return {
    ...layout,
    characters: {
      ...layout.characters,
      [charId]: { ...charLayout, [part]: next },
    },
  }
}
