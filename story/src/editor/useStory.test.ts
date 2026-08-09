import { renderHook, act, waitFor } from '@testing-library/react'
import { useStory } from './useStory'
import { demoScript, demoLayout } from '../test/fixtures'
import type { ContentEvent } from './api'

function stubFetchRoutes() {
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input)
    if (init?.method === 'PUT') return new Response(null, { status: 204 })
    if (url.includes('script.json')) return new Response(JSON.stringify(demoScript))
    if (url.includes('layout.json')) return new Response(JSON.stringify(demoLayout))
    return new Response('{}')
  }))
}

test('載入 script 與 layout', async () => {
  stubFetchRoutes()
  const { result } = renderHook(() => useStory('demo'))
  await waitFor(() => expect(result.current.script?.slug).toBe(demoScript.slug))
  expect(result.current.layout).not.toBeNull()
})

test('updateScript 樂觀更新並 debounce PUT', async () => {
  vi.useFakeTimers()
  stubFetchRoutes()
  const { result } = renderHook(() => useStory('demo'))
  await act(async () => { await vi.runOnlyPendingTimersAsync() })
  const next = { ...result.current.script!, title: '改了' }
  act(() => result.current.updateScript(next))
  expect(result.current.script?.title).toBe('改了')
  expect(vi.mocked(fetch).mock.calls.some(([, i]) => i?.method === 'PUT')).toBe(false)
  await act(async () => { await vi.advanceTimersByTimeAsync(600) })
  expect(vi.mocked(fetch).mock.calls.some(([, i]) => i?.method === 'PUT')).toBe(true)
  vi.useRealTimers()
})

test('PUT 400 時把錯誤訊息放進 error，不覆蓋本地編輯', async () => {
  vi.useFakeTimers()
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input)
    if (init?.method === 'PUT') return new Response(JSON.stringify({ error: '節點缺少 next/choices/ending' }), { status: 400 })
    if (url.includes('script.json')) return new Response(JSON.stringify(demoScript))
    if (url.includes('layout.json')) return new Response(JSON.stringify(demoLayout))
    return new Response('{}')
  }))
  const { result } = renderHook(() => useStory('demo'))
  await act(async () => { await vi.runOnlyPendingTimersAsync() })
  const next = { ...result.current.script!, title: '改壞了' }
  act(() => result.current.updateScript(next))
  await act(async () => { await vi.advanceTimersByTimeAsync(600) })
  expect(result.current.error).toBe('節點缺少 next/choices/ending')
  expect(result.current.script?.title).toBe('改壞了')
  vi.useRealTimers()
})

test('SSE 收到符合目前故事的更新 → 重新 GET 覆蓋 state 並標記 externalUpdate', async () => {
  stubFetchRoutes()
  let handler: ((e: ContentEvent) => void) | undefined
  const subscribe = vi.fn((onEvent: (e: ContentEvent) => void) => {
    handler = onEvent
    return () => {}
  })
  const { result } = renderHook(() => useStory('demo', { subscribe }))
  await waitFor(() => expect(result.current.script?.slug).toBe(demoScript.slug))
  expect(subscribe).toHaveBeenCalled()

  const updated = { ...demoScript, title: '外部改的標題' }
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input)
    if (url.includes('script.json')) return new Response(JSON.stringify(updated))
    if (url.includes('layout.json')) return new Response(JSON.stringify(demoLayout))
    return new Response('{}')
  }))
  act(() => handler?.({ type: 'change', slug: 'demo', file: 'script.json' }))

  await waitFor(() => expect(result.current.script?.title).toBe('外部改的標題'))
  expect(result.current.externalUpdate).toBe('script.json')
})

test('SSE 收到 art.json 更新 → 重新 GET 覆蓋 art 並標記 externalUpdate', async () => {
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input)
    if (url.includes('script.json')) return new Response(JSON.stringify(demoScript))
    if (url.includes('layout.json')) return new Response(JSON.stringify(demoLayout))
    if (url.includes('art.json')) return new Response(JSON.stringify({ palette: 'v1' }))
    return new Response('{}')
  }))
  let handler: ((e: ContentEvent) => void) | undefined
  const subscribe = vi.fn((onEvent: (e: ContentEvent) => void) => {
    handler = onEvent
    return () => {}
  })
  const { result } = renderHook(() => useStory('demo', { subscribe }))
  await waitFor(() => expect(result.current.art).toEqual({ palette: 'v1' }))

  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
    const url = String(input)
    if (url.includes('script.json')) return new Response(JSON.stringify(demoScript))
    if (url.includes('layout.json')) return new Response(JSON.stringify(demoLayout))
    if (url.includes('art.json')) return new Response(JSON.stringify({ palette: 'v2-外部改的' }))
    return new Response('{}')
  }))
  act(() => handler?.({ type: 'change', slug: 'demo', file: 'art.json' }))

  await waitFor(() => expect(result.current.art).toEqual({ palette: 'v2-外部改的' }))
  expect(result.current.externalUpdate).toBe('art.json')
})

test('updateScript debounce 尚未送出時收到同檔 SSE → 放棄本地變更、改用外部值，且原本 pending 的 PUT 不會補發', async () => {
  vi.useFakeTimers()
  stubFetchRoutes()
  let handler: ((e: ContentEvent) => void) | undefined
  const subscribe = vi.fn((onEvent: (e: ContentEvent) => void) => {
    handler = onEvent
    return () => {}
  })
  const { result } = renderHook(() => useStory('demo', { subscribe }))
  await act(async () => { await vi.runOnlyPendingTimersAsync() })

  act(() => result.current.updateScript({ ...result.current.script!, title: '本地改的' }))
  expect(result.current.script?.title).toBe('本地改的')

  const external = { ...demoScript, title: '外部改的' }
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input)
    if (init?.method === 'PUT') return new Response(null, { status: 204 })
    if (url.includes('script.json')) return new Response(JSON.stringify(external))
    if (url.includes('layout.json')) return new Response(JSON.stringify(demoLayout))
    return new Response('{}')
  }))
  // 撞檔 SSE 在 500ms debounce 觸發之前到達：本地未送出的變更該被放棄
  act(() => handler?.({ type: 'change', slug: 'demo', file: 'script.json' }))
  await act(async () => { await vi.advanceTimersByTimeAsync(0) })

  expect(result.current.script?.title).toBe('外部改的')
  expect(result.current.externalUpdate).toBe('script.json')

  // 就算把時間推過原本的 500ms debounce 期限，也不該補發 PUT（pending timer 已被撞檔取消）
  await act(async () => { await vi.advanceTimersByTimeAsync(600) })
  expect(vi.mocked(fetch).mock.calls.some(([, i]) => i?.method === 'PUT')).toBe(false)
  vi.useRealTimers()
})

test('unmount 時清掉尚未觸發的 debounce timer，不會對已卸載的故事補發 PUT（對應 EditorPage 切換故事用 key remount 的修法所依賴的機制）', async () => {
  vi.useFakeTimers()
  stubFetchRoutes()
  const { result, unmount } = renderHook(() => useStory('demo'))
  await act(async () => { await vi.runOnlyPendingTimersAsync() })

  act(() => result.current.updateScript({ ...result.current.script!, title: '來不及送出' }))
  unmount()

  await act(async () => { await vi.advanceTimersByTimeAsync(600) })
  expect(vi.mocked(fetch).mock.calls.some(([, i]) => i?.method === 'PUT')).toBe(false)
  vi.useRealTimers()
})
