import { render, screen, fireEvent } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import { StagePreview } from './StagePreview'
import { demoScript } from '../../test/fixtures'

describe('StagePreview', () => {
  test('渲染節點背景與段落文字', () => {
    render(
      <StagePreview
        script={demoScript}
        slug="demo"
        nodeId={demoScript.startNode}
        paragraphIndex={0}
        onParagraphChange={() => {}}
      />,
    )
    expect(screen.getByText(demoScript.nodes[0].paragraphs[0])).toBeInTheDocument()
  })

  test('段落切換器呼叫 onParagraphChange', () => {
    const onChange = vi.fn()
    render(
      <StagePreview
        script={demoScript}
        slug="demo"
        nodeId={demoScript.startNode}
        paragraphIndex={0}
        onParagraphChange={onChange}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: '下一段' }))
    expect(onChange).toHaveBeenCalledWith(1)
  })

  test('第一段時「上一段」按鈕停用，最後一段時「下一段」按鈕停用', () => {
    const { rerender } = render(
      <StagePreview
        script={demoScript}
        slug="demo"
        nodeId={demoScript.startNode}
        paragraphIndex={0}
        onParagraphChange={() => {}}
      />,
    )
    expect(screen.getByRole('button', { name: '上一段' })).toBeDisabled()

    rerender(
      <StagePreview
        script={demoScript}
        slug="demo"
        nodeId={demoScript.startNode}
        paragraphIndex={1}
        onParagraphChange={() => {}}
      />,
    )
    expect(screen.getByRole('button', { name: '下一段' })).toBeDisabled()
    expect(screen.getByText('第 2/2 段')).toBeInTheDocument()
  })

  test('顯示選項節點時渲染選項樣式', () => {
    render(
      <StagePreview
        script={demoScript}
        slug="demo"
        nodeId={demoScript.startNode}
        paragraphIndex={1}
        onParagraphChange={() => {}}
      />,
    )
    expect(screen.getByText('往左')).toBeInTheDocument()
    expect(screen.getByText('往右')).toBeInTheDocument()
  })
})
