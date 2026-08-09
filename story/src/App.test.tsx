import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { AppRoutes } from './App'

test('首頁顯示站名', () => {
  render(<MemoryRouter initialEntries={['/']}><AppRoutes /></MemoryRouter>)
  expect(screen.getByText('Lorescape 故事體驗')).toBeInTheDocument()
})

test('/play/:slug 進入播放頁', () => {
  render(<MemoryRouter initialEntries={['/play/demo']}><AppRoutes /></MemoryRouter>)
  expect(screen.getByTestId('play-page')).toBeInTheDocument()
})

test('DEV 模式下 /editor 可渲染工作台骨架', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ stories: [] }))))
  render(<MemoryRouter initialEntries={['/editor']}><AppRoutes /></MemoryRouter>)
  await waitFor(() => expect(screen.getByText('故事工作台')).toBeInTheDocument())
})
