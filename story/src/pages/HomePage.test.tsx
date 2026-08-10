import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { vi } from 'vitest'
import { HomePage } from './HomePage'
import * as catalogModule from '../data/catalog'

vi.mock('../data/catalog', () => ({
  loadCatalog: vi.fn(),
}))

const mockLoadCatalog = vi.mocked(catalogModule.loadCatalog)

beforeEach(() => {
  mockLoadCatalog.mockResolvedValue([
    { slug: 'test-story', title: '測試劇本', place: '測試地', blurb: '一句不爆雷的 hook' },
  ])
})

test('顯示站名與站台說明', () => {
  render(<MemoryRouter><HomePage /></MemoryRouter>)
  expect(screen.getByText('Lorescape 故事體驗')).toBeInTheDocument()
  expect(screen.getByText('用第二人稱走進歷史現場')).toBeInTheDocument()
})

test('catalog 有資料時渲染劇本卡與正確連結', async () => {
  render(<MemoryRouter><HomePage /></MemoryRouter>)
  await waitFor(() => {
    expect(screen.getByText('測試劇本')).toBeInTheDocument()
  })
  expect(screen.getByText('測試地')).toBeInTheDocument()
  expect(screen.getByText('一句不爆雷的 hook')).toBeInTheDocument()
  const link = screen.getByRole('link', { name: /測試劇本/ })
  expect(link).toHaveAttribute('href', '/play/test-story')
})

test('loadCatalog 失敗時顯示錯誤字樣', async () => {
  mockLoadCatalog.mockRejectedValue(new Error('目錄載入失敗：HTTP 500'))
  render(<MemoryRouter><HomePage /></MemoryRouter>)
  await waitFor(() => {
    expect(screen.getByText(/錯誤：/)).toBeInTheDocument()
  })
})
