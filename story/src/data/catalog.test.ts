import { loadCatalog } from './catalog'
import { vi } from 'vitest'

test('loadCatalog 抓取並回傳 stories', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({
    stories: [{ slug: 's', title: 't', place: 'p', blurb: 'b' }],
  }))))
  const entries = await loadCatalog()
  expect(entries[0].slug).toBe('s')
})
