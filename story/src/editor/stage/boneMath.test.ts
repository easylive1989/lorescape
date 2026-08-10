import { describe, expect, test } from 'vitest'
import { applyPartDelta, dragToDelta, scaleHeight } from './boneMath'
import { demoLayout } from '../../test/fixtures'

describe('boneMath', () => {
  test('dragToDelta 依 sprite 容器尺寸換算比例位移', () => {
    expect(dragToDelta(48, -30, 480, 720)).toEqual({ dcx: 0.1, dtop: -30 / 720 })
  })

  test('scaleHeight 每格 5% 並 clamp', () => {
    expect(scaleHeight(0.2, 100)).toBeCloseTo(0.19)
    expect(scaleHeight(0.2, -100)).toBeCloseTo(0.21)
    expect(scaleHeight(0.02, 100)).toBe(0.02)
  })

  test('scaleHeight 上限 clamp 1.2', () => {
    expect(scaleHeight(1.19, -100)).toBe(1.2)
  })

  test('scaleHeight 結果 round 到小數 4 位', () => {
    expect(scaleHeight(1 / 3, 100)).toBe(0.3167)
  })

  test('applyPartDelta 不可變更新，delta 為增量', () => {
    const next = applyPartDelta(demoLayout, 'master', 'head', { cx: 0.01 })
    expect(next.characters.master.head.cx).toBeCloseTo(demoLayout.characters.master.head.cx + 0.01)
    expect(demoLayout.characters.master.head.cx).not.toBe(next.characters.master.head.cx)
    // 未觸及的部件與屬性維持不變
    expect(next.characters.master.head.top).toBe(demoLayout.characters.master.head.top)
    expect(next.characters.master.torso).toBe(demoLayout.characters.master.torso)
  })

  test('applyPartDelta 支援多欄位同時增量', () => {
    const next = applyPartDelta(demoLayout, 'master', 'torso', { top: -0.02, height: 0.03 })
    expect(next.characters.master.torso.top).toBeCloseTo(demoLayout.characters.master.torso.top - 0.02)
    expect(next.characters.master.torso.height).toBeCloseTo(demoLayout.characters.master.torso.height + 0.03)
  })
})
