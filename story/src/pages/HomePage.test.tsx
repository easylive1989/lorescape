import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { vi } from 'vitest'
import { HomePage } from './HomePage'

vi.mock('../data/catalog', () => ({
  catalog: [
    { slug: 'test-story', title: '測試劇本', place: '測試地', blurb: '一句不爆雷的 hook' },
  ],
}))

test('顯示站名與站台說明', () => {
  render(<MemoryRouter><HomePage /></MemoryRouter>)
  expect(screen.getByText('Lorescape 故事體驗')).toBeInTheDocument()
  expect(screen.getByText('用第二人稱走進歷史現場')).toBeInTheDocument()
})

test('catalog 有資料時渲染劇本卡與正確連結', () => {
  render(<MemoryRouter><HomePage /></MemoryRouter>)
  expect(screen.getByText('測試劇本')).toBeInTheDocument()
  expect(screen.getByText('測試地')).toBeInTheDocument()
  expect(screen.getByText('一句不爆雷的 hook')).toBeInTheDocument()
  const link = screen.getByRole('link', { name: /測試劇本/ })
  expect(link).toHaveAttribute('href', '/play/test-story')
})
