import { render, screen, fireEvent } from '@testing-library/react'
import { afterEach, describe, expect, test, vi } from 'vitest'
import { BoneEditor } from './BoneEditor'
import { demoLayout } from '../../test/fixtures'

// BoneEditor 以自身外框（sprite 容器）的 getBoundingClientRect() 當拖拉分母，
// jsdom 預設回傳全 0，這裡固定 mock 成已知尺寸方便斷言換算結果。
function stubContainerRect(width: number, height: number) {
  vi.spyOn(Element.prototype, 'getBoundingClientRect').mockReturnValue({
    x: 0, y: 0, width, height, top: 0, left: 0, right: width, bottom: height,
    toJSON() { return {} },
  })
}

describe('BoneEditor', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  test('渲染四個部件框，各自標出座標', () => {
    render(<BoneEditor layout={demoLayout} charId="master" onChange={() => {}} />)
    expect(screen.getByTestId('bone-part-head')).toBeInTheDocument()
    expect(screen.getByTestId('bone-part-torso')).toBeInTheDocument()
    expect(screen.getByTestId('bone-part-leftArm')).toBeInTheDocument()
    expect(screen.getByTestId('bone-part-rightArm')).toBeInTheDocument()
  })

  test('拖拉部件框：pointerdown → pointermove → pointerup 觸發 onChange 帶位移後的 layout', () => {
    stubContainerRect(480, 720)
    const onChange = vi.fn()
    render(<BoneEditor layout={demoLayout} charId="master" onChange={onChange} />)
    const head = screen.getByTestId('bone-part-head')

    fireEvent.pointerDown(head, { clientX: 100, clientY: 100, pointerId: 1 })
    fireEvent.pointerMove(head, { clientX: 148, clientY: 70, pointerId: 1 })
    fireEvent.pointerUp(head, { clientX: 148, clientY: 70, pointerId: 1 })

    expect(onChange).toHaveBeenCalledTimes(1)
    const next = onChange.mock.calls[0][0]
    expect(next.characters.master.head.cx).toBeCloseTo(demoLayout.characters.master.head.cx + 48 / 480)
    expect(next.characters.master.head.top).toBeCloseTo(demoLayout.characters.master.head.top + (-30) / 720)
    // 未拖動的部件不受影響
    expect(next.characters.master.torso).toEqual(demoLayout.characters.master.torso)
  })

  test('拖拉中途多次 pointermove 會累積，且不影響其他部件', () => {
    stubContainerRect(480, 720)
    const onChange = vi.fn()
    let layout = demoLayout
    const handleChange = (next: typeof demoLayout) => { layout = next; onChange(next) }
    const { rerender } = render(<BoneEditor layout={layout} charId="master" onChange={handleChange} />)
    const torso = screen.getByTestId('bone-part-torso')

    fireEvent.pointerDown(torso, { clientX: 0, clientY: 0, pointerId: 1 })
    fireEvent.pointerMove(torso, { clientX: 24, clientY: 0, pointerId: 1 })
    rerender(<BoneEditor layout={layout} charId="master" onChange={handleChange} />)
    fireEvent.pointerMove(torso, { clientX: 48, clientY: 0, pointerId: 1 })
    fireEvent.pointerUp(torso, { clientX: 48, clientY: 0, pointerId: 1 })

    expect(onChange).toHaveBeenCalledTimes(2)
    // 兩次各 24px / 480 = 0.05，累積 0.1
    expect(layout.characters.master.torso.cx).toBeCloseTo(demoLayout.characters.master.torso.cx + 0.1)
  })

  test('選中部件會高亮並顯示名稱', () => {
    render(<BoneEditor layout={demoLayout} charId="master" onChange={() => {}} />)
    const torso = screen.getByTestId('bone-part-torso')
    fireEvent.pointerDown(torso, { clientX: 0, clientY: 0, pointerId: 1 })
    expect(torso.className).toContain('bone-editor__part--selected')
    expect(screen.getByText('身體')).toBeInTheDocument()
  })

  test('選中部件時透過 onSelectPart 通知外部（供右欄數值面板同步）', () => {
    const onSelectPart = vi.fn()
    render(
      <BoneEditor
        layout={demoLayout}
        charId="master"
        onChange={() => {}}
        onSelectPart={onSelectPart}
      />,
    )
    fireEvent.pointerDown(screen.getByTestId('bone-part-leftArm'), { clientX: 0, clientY: 0, pointerId: 1 })
    expect(onSelectPart).toHaveBeenCalledWith('leftArm')
  })

  test('wheel 事件依 scaleHeight 改變該部件 height', () => {
    const onChange = vi.fn()
    render(<BoneEditor layout={demoLayout} charId="master" onChange={onChange} />)
    const head = screen.getByTestId('bone-part-head')

    fireEvent.wheel(head, { deltaY: 100 })

    expect(onChange).toHaveBeenCalledTimes(1)
    const next = onChange.mock.calls[0][0]
    expect(next.characters.master.head.height).toBeCloseTo(demoLayout.characters.master.head.height * 0.95)
    // 其他欄位不受影響
    expect(next.characters.master.head.cx).toBe(demoLayout.characters.master.head.cx)
  })
})
