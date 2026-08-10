import { loadLayout } from './loadLayout'
import { demoScript } from '../test/fixtures'

test('loadLayout 抓取並驗證 layout.json', async () => {
  const layout = {
    canvas: { width: 1024, height: 1536 },
    characters: { master: {
      head: { cx: 0.5, top: 0.03, height: 0.22 },
      torso: { cx: 0.5, top: 0.2, height: 0.78 },
      leftArm: { cx: 0.33, top: 0.23, height: 0.35 },
      rightArm: { cx: 0.64, top: 0.22, height: 0.35 },
    } },
  }
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify(layout))))
  const result = await loadLayout('demo', demoScript)
  expect(result.characters.master.torso.height).toBe(0.78)
  expect(vi.mocked(fetch).mock.calls[0][0]).toContain('/content/demo/layout.json?v=')
})

test('loadLayout HTTP 失敗丟明確錯誤', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response('', { status: 404 })))
  await expect(loadLayout('demo', demoScript)).rejects.toThrow(/layout/)
})
