import { render, screen, fireEvent } from '@testing-library/react'
import { NodeList } from './NodeList'
import { demoScript } from '../../test/fixtures'

test('列出節點並可選取', () => {
  const onSelect = vi.fn()
  render(<NodeList script={demoScript} selectedId={null} onSelect={onSelect} onReorder={() => {}} />)
  fireEvent.click(screen.getByText(demoScript.nodes[0].id))
  expect(onSelect).toHaveBeenCalledWith(demoScript.nodes[0].id)
})

test('顯示節點首段摘要', () => {
  render(<NodeList script={demoScript} selectedId={null} onSelect={() => {}} onReorder={() => {}} />)
  expect(screen.getByText(demoScript.nodes[0].paragraphs[0].slice(0, 12), { exact: false })).toBeInTheDocument()
})

test('點選中的節點列會標示選取狀態', () => {
  render(
    <NodeList
      script={demoScript}
      selectedId={demoScript.nodes[1].id}
      onSelect={() => {}}
      onReorder={() => {}}
    />,
  )
  const items = screen.getAllByRole('listitem')
  expect(items[1].className).toMatch(/selected/)
  expect(items[0].className).not.toMatch(/selected/)
})

test('按下↓將該節點與下一個節點交換順序', () => {
  const onReorder = vi.fn()
  render(<NodeList script={demoScript} selectedId={null} onSelect={() => {}} onReorder={onReorder} />)
  const downButtons = screen.getAllByRole('button', { name: '下移' })
  fireEvent.click(downButtons[0])
  expect(onReorder).toHaveBeenCalledWith(['end-a', 'n1', 'end-b', 'n2'])
})

test('按下↑將該節點與上一個節點交換順序', () => {
  const onReorder = vi.fn()
  render(<NodeList script={demoScript} selectedId={null} onSelect={() => {}} onReorder={onReorder} />)
  const upButtons = screen.getAllByRole('button', { name: '上移' })
  fireEvent.click(upButtons[1])
  expect(onReorder).toHaveBeenCalledWith(['end-a', 'n1', 'end-b', 'n2'])
})

test('第一列的上移按鈕與最後一列的下移按鈕停用', () => {
  render(<NodeList script={demoScript} selectedId={null} onSelect={() => {}} onReorder={() => {}} />)
  const upButtons = screen.getAllByRole('button', { name: '上移' })
  const downButtons = screen.getAllByRole('button', { name: '下移' })
  expect(upButtons[0]).toBeDisabled()
  expect(downButtons[downButtons.length - 1]).toBeDisabled()
})
