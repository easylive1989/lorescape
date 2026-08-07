import { render, screen } from '@testing-library/react'
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
