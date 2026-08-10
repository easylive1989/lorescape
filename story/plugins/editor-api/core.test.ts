// @vitest-environment node
import { compressPng, safeAssetPath, safeContentPath, validateContentPayload, type ContentFile } from './core'

test('safeContentPath 擋路徑跳脫', () => {
  expect(safeContentPath('/root', '../etc', 'script.json')).toBeNull()
  expect(safeContentPath('/root', 'demo', '../../secret')).toBeNull()
  expect(safeContentPath('/root', 'demo', 'script.json'))
    .toBe('/root/demo/script.json')
})

test('validateContentPayload 擋壞 script', () => {
  const bad = validateContentPayload('script.json', { slug: 's' })
  expect(bad.ok).toBe(false)
})

test('validateContentPayload 擋 layout 缺角色（帶 context script）', () => {
  const script = {
    slug: 's', title: 't', place: 'p', intro: 'i', startNode: 'n1',
    characters: [{ id: 'anne', name: 'a', parts: { head: 'h', torso: 't', leftArm: 'l', rightArm: 'r' } }],
    nodes: [{ id: 'n1', background: 'b', paragraphs: ['x'], ending: { title: 'e' } }],
  }
  const result = validateContentPayload('layout.json',
    { canvas: { width: 1024, height: 1536 }, characters: {} }, { script })
  expect(result.ok).toBe(false)
})

test('validateContentPayload 對未知檔名 default-deny', () => {
  const result = validateContentPayload('notes.json' as ContentFile, { anything: 1 })
  expect(result.ok).toBe(false)
  if (!result.ok) expect(result.error).toBe('unknown content file')
})

test('safeAssetPath 只允許 assets 下安全路徑', () => {
  expect(safeAssetPath('/root', 'demo', 'assets/scenes/a.png')).toBe('/root/demo/assets/scenes/a.png')
  expect(safeAssetPath('/root', 'demo', 'assets/../../x.png')).toBeNull()
  expect(safeAssetPath('/root', 'demo', 'scenes/a.png')).toBeNull()
})

test('compressPng 未安裝 pngquant 時回 skipped', async () => {
  // 以不存在的路徑模擬：execFile 會因目標檔不存在而失敗（含 ENOENT 情境）
  const result = await compressPng('/nonexistent.png')
  expect(result).toBe('skipped')
})
