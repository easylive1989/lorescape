import { render, screen } from '@testing-library/react'
import { fireEvent } from '@testing-library/react'
import { GraphView, connectionEdgeId } from './GraphView'
import { demoScript } from '../../test/fixtures'

test('餵入 script 後，畫布節點數等於 script.nodes 數量', () => {
  const { container } = render(<GraphView script={demoScript} onScriptChange={() => {}} />)
  expect(container.querySelectorAll('.react-flow__node')).toHaveLength(demoScript.nodes.length)
})

test('點「在後面插入節點」呼叫 onScriptChange，節點數 +1', () => {
  const onScriptChange = vi.fn()
  render(<GraphView script={demoScript} onScriptChange={onScriptChange} />)
  fireEvent.click(screen.getByRole('button', { name: `在 ${demoScript.nodes[0].id} 後面插入節點` }))
  expect(onScriptChange).toHaveBeenCalledTimes(1)
  const next = onScriptChange.mock.calls[0][0]
  expect(next.nodes).toHaveLength(demoScript.nodes.length + 1)
})

test('刪除有入邊的節點：顯示錯誤且不呼叫 onScriptChange', () => {
  const onScriptChange = vi.fn()
  render(<GraphView script={demoScript} onScriptChange={onScriptChange} />)
  // end-a 被 n1 的選項指向，屬於有入邊節點
  fireEvent.click(screen.getByRole('button', { name: '刪除節點 end-a' }))
  expect(screen.getByRole('alert')).toBeInTheDocument()
  expect(onScriptChange).not.toHaveBeenCalled()
})

test('刪除無入邊、非 startNode 的節點：呼叫 onScriptChange 並移除該節點', () => {
  const onScriptChange = vi.fn()
  render(<GraphView script={demoScript} onScriptChange={onScriptChange} />)
  // n2 為孤立節點（無入邊、非 startNode）
  fireEvent.click(screen.getByRole('button', { name: '刪除節點 n2' }))
  expect(onScriptChange).toHaveBeenCalledTimes(1)
  const next = onScriptChange.mock.calls[0][0]
  expect(next.nodes.find((n: { id: string }) => n.id === 'n2')).toBeUndefined()
})

test('刪除 startNode：顯示錯誤且不呼叫 onScriptChange', () => {
  const onScriptChange = vi.fn()
  render(<GraphView script={demoScript} onScriptChange={onScriptChange} />)
  fireEvent.click(screen.getByRole('button', { name: `刪除節點 ${demoScript.startNode}` }))
  expect(screen.getByRole('alert')).toBeInTheDocument()
  expect(onScriptChange).not.toHaveBeenCalled()
})

describe('connectionEdgeId（純函式）', () => {
  test('next handle 對應 :next edgeId', () => {
    expect(connectionEdgeId('n1', 'next')).toBe('n1:next')
  })

  test('choice-N handle 對應 :choice:N edgeId', () => {
    expect(connectionEdgeId('n1', 'choice-0')).toBe('n1:choice:0')
    expect(connectionEdgeId('n1', 'choice-2')).toBe('n1:choice:2')
  })

  test('無 sourceHandle 或不明格式回傳 null', () => {
    expect(connectionEdgeId('n1', null)).toBeNull()
    expect(connectionEdgeId('n1', 'weird')).toBeNull()
  })
})
