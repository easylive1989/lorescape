import { render, screen, fireEvent } from '@testing-library/react'
import { describe, expect, test, vi } from 'vitest'
import { StagePreview } from './StagePreview'
import { demoScript, flagScript } from '../../test/fixtures'

describe('StagePreview', () => {
  test('渲染節點背景與段落文字', () => {
    render(
      <StagePreview
        script={demoScript}
        slug="demo"
        nodeId={demoScript.startNode}
        paragraphIndex={0}
        onParagraphChange={() => {}}
        flags={[]}
        onFlagsChange={() => {}}
      />,
    )
    expect(screen.getByText(demoScript.nodes[0].paragraphs[0].text)).toBeInTheDocument()
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
        flags={[]}
        onFlagsChange={() => {}}
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
        flags={[]}
        onFlagsChange={() => {}}
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
        flags={[]}
        onFlagsChange={() => {}}
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
        flags={[]}
        onFlagsChange={() => {}}
      />,
    )
    expect(screen.getByText('往左')).toBeInTheDocument()
    expect(screen.getByText('往右')).toBeInTheDocument()
  })

  test('劇本有 flag 時列出開關', () => {
    const script = structuredClone(demoScript)
    script.nodes[0].choices![0].set = ['sealed']
    render(
      <StagePreview
        script={script} slug="demo" nodeId="n1" paragraphIndex={0}
        onParagraphChange={() => {}} flags={[]} onFlagsChange={() => {}}
      />,
    )
    expect(screen.getByLabelText('sealed')).not.toBeChecked()
  })

  test('切換開關把 flag 加進來', () => {
    const onFlagsChange = vi.fn()
    const script = structuredClone(demoScript)
    script.nodes[0].choices![0].set = ['sealed']
    render(
      <StagePreview
        script={script} slug="demo" nodeId="n1" paragraphIndex={0}
        onParagraphChange={() => {}} flags={[]} onFlagsChange={onFlagsChange}
      />,
    )
    fireEvent.click(screen.getByLabelText('sealed'))
    expect(onFlagsChange).toHaveBeenCalledWith(['sealed'])
  })

  test('預覽的段落總數只算可見段落', () => {
    render(
      <StagePreview
        script={flagScript} slug="flags" nodeId="mid" paragraphIndex={0}
        onParagraphChange={() => {}} flags={['sealed']} onFlagsChange={() => {}}
      />,
    )
    expect(screen.getByText('第 1/2 段')).toBeInTheDocument()
  })
})
