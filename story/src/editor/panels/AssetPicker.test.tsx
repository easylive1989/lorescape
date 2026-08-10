import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { AssetPicker } from './AssetPicker'

// coverToPngBlob 用 createImageBitmap + canvas，jsdom 測不了，換成 identity（原樣回傳 file）
vi.mock('../imageTools', () => ({
  coverToPngBlob: vi.fn(async (file: File) => file),
}))

afterEach(() => vi.clearAllMocks())

function stubFetchList(files: { path: string; mtime: number }[]) {
  return vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input)
    if (init?.method === 'POST') return new Response(JSON.stringify({ path: 'assets/uploaded.png', compressed: true }), { status: 201 })
    if (url.includes('/__editor/assets/demo')) return new Response(JSON.stringify({ files }))
    return new Response('{}')
  })
}

test('列出 category 過濾後的縮圖，點選呼叫 onPick', async () => {
  const files = [
    { path: 'scenes/a.png', mtime: 111 },
    { path: 'scenes/b.png', mtime: 222 },
    { path: 'characters/master/head.png', mtime: 333 },
  ]
  vi.stubGlobal('fetch', stubFetchList(files))
  const onPick = vi.fn()
  render(<AssetPicker slug="demo" category="scenes" onPick={onPick} />)

  await waitFor(() => expect(screen.getAllByRole('img')).toHaveLength(2))
  const imgs = screen.getAllByRole('img')
  expect(imgs[0]).toHaveAttribute('src', '/content/demo/assets/scenes/a.png?mtime=111')

  fireEvent.click(screen.getByRole('button', { name: '選擇 scenes/a.png' }))
  expect(onPick).toHaveBeenCalledWith('scenes/a.png')
})

test('scenes 類上傳：先 coverToPngBlob 裁切再 POST，成功後重新整理列表並 onPick', async () => {
  vi.stubGlobal('fetch', stubFetchList([]))
  const onPick = vi.fn()
  render(<AssetPicker slug="demo" category="scenes" onPick={onPick} />)
  await waitFor(() => expect(vi.mocked(fetch)).toHaveBeenCalled())

  const file = new File(['x'], 'photo.jpg', { type: 'image/jpeg' })
  const input = screen.getByLabelText('上傳素材')
  fireEvent.change(input, { target: { files: [file] } })

  await waitFor(() => expect(onPick).toHaveBeenCalledWith('scenes/photo.png'))
  const postCall = vi.mocked(fetch).mock.calls.find(([, init]) => init?.method === 'POST')
  expect(postCall?.[0]).toBe('/__editor/assets/demo/assets/scenes/photo.png')
})

test('characters 類上傳：原檔直傳，不呼叫 coverToPngBlob', async () => {
  const { coverToPngBlob } = await import('../imageTools')
  vi.stubGlobal('fetch', stubFetchList([]))
  const onPick = vi.fn()
  render(<AssetPicker slug="demo" category="characters/master" onPick={onPick} />)
  await waitFor(() => expect(vi.mocked(fetch)).toHaveBeenCalled())

  const file = new File(['x'], 'head.png', { type: 'image/png' })
  const input = screen.getByLabelText('上傳素材')
  fireEvent.change(input, { target: { files: [file] } })

  await waitFor(() => expect(onPick).toHaveBeenCalledWith('characters/master/head.png'))
  expect(coverToPngBlob).not.toHaveBeenCalled()
  const postCall = vi.mocked(fetch).mock.calls.find(([, init]) => init?.method === 'POST')
  expect(postCall?.[0]).toBe('/__editor/assets/demo/assets/characters/master/head.png')
})
