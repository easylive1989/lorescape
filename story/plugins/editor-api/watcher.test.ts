// @vitest-environment node
import { classifyPath, SelfWriteGuard } from './watcher'

test('classifyPath 解析 slug 與 file', () => {
  expect(classifyPath('/r/public/content', '/r/public/content/demo/script.json'))
    .toEqual({ type: 'change', slug: 'demo', file: 'script.json' })
  expect(classifyPath('/r/public/content', '/r/public/content/demo/assets/scenes/a.png'))
    .toEqual({ type: 'change', slug: 'demo', file: 'assets/scenes/a.png' })
  expect(classifyPath('/r/public/content', '/r/public/content/index.json'))
    .toEqual({ type: 'change', slug: '', file: 'index.json' })
  expect(classifyPath('/r/public/content', '/elsewhere/x.json')).toBeNull()
})

test('SelfWriteGuard 抑制自寫入', () => {
  vi.useFakeTimers()
  const guard = new SelfWriteGuard()
  guard.markWrite('/p/a.json')
  expect(guard.isSelf('/p/a.json')).toBe(true)
  vi.advanceTimersByTime(2000)
  expect(guard.isSelf('/p/a.json')).toBe(false)
  vi.useRealTimers()
})
