import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import EditorPage from './EditorPage'
import { demoScript } from '../test/fixtures'

describe('EditorPage 故事屬性面板（Task 15）', () => {
  function stubFetchRoutes() {
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      if (init?.method === 'PUT') return new Response(null, { status: 204 })
      if (url.includes('/__editor/assets/')) {
        return new Response(JSON.stringify({ files: [{ path: 'characters/master/new-full.png', mtime: 1 }] }))
      }
      if (url.includes('index.json')) {
        return new Response(JSON.stringify({
          stories: [
            { slug: 'demo', title: demoScript.title, place: demoScript.place, blurb: '測試簡介' },
            { slug: 'other', title: '別的故事', place: '別的地點', blurb: '別的簡介' },
          ],
        }))
      }
      if (url.includes('script.json')) return new Response(JSON.stringify(demoScript))
      return new Response('{}')
    }))
  }

  test('未選取節點時右欄顯示 StoryPanel；選取節點後切成 NodePanel；點「故事設定」清除選取切回', async () => {
    stubFetchRoutes()
    const user = userEvent.setup()
    render(<EditorPage />)
    await screen.findByRole('option', { name: demoScript.title })
    await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')

    expect(await screen.findByRole('textbox', { name: '標題' })).toBeInTheDocument()

    await user.click(screen.getByText(demoScript.nodes[0].id))
    expect(screen.queryByRole('textbox', { name: '標題' })).not.toBeInTheDocument()
    expect(screen.getByText('段落')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: '故事設定' }))
    expect(await screen.findByRole('textbox', { name: '標題' })).toBeInTheDocument()
  })

  test('點角色圖換檔鈕開 AssetPicker，選圖後把新檔路徑寫回該角色的 image 並送出 PUT', async () => {
    stubFetchRoutes()
    const user = userEvent.setup()
    render(<EditorPage />)
    await screen.findByRole('option', { name: demoScript.title })
    await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')
    await screen.findByRole('textbox', { name: '標題' })

    await user.click(screen.getByRole('button', { name: '更換角色圖／師傅' }))
    const thumb = await screen.findByRole('button', { name: '選擇 characters/master/new-full.png' })
    await user.click(thumb)

    // 選圖後 AssetPicker 應收合
    expect(screen.queryByRole('button', { name: /^選擇 /})).not.toBeInTheDocument()

    await waitFor(() => {
      const putCall = vi.mocked(fetch).mock.calls.find(([input, init]) =>
        String(input).includes('script.json') && init?.method === 'PUT')
      expect(putCall).toBeDefined()
      const body = JSON.parse(putCall![1]!.body as string)
      expect(body.characters[0].image).toBe('characters/master/new-full.png')
    }, { timeout: 2000 })
  })

  // Fix round 1（code review Important）：StoryPanel 改 title/place 只寫 script.json，
  // index.json 的同名欄位沒同步，HomePage 卡片（讀 index.json）會顯示過時標題/地點。
  test('改標題後，script.json 與 index.json 都送出 PUT；index.json 只改該 slug 的 title，其他故事條目不動', async () => {
    stubFetchRoutes()
    const user = userEvent.setup()
    render(<EditorPage />)
    await screen.findByRole('option', { name: demoScript.title })
    await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')

    const titleInput = await screen.findByRole('textbox', { name: '標題' })
    await user.clear(titleInput)
    await user.type(titleInput, '新標題')

    await waitFor(() => {
      const scriptPut = vi.mocked(fetch).mock.calls.find(([input, init]) =>
        String(input).includes('script.json') && init?.method === 'PUT')
      expect(scriptPut).toBeDefined()
      expect(JSON.parse(scriptPut![1]!.body as string).title).toBe('新標題')

      const catalogPut = vi.mocked(fetch).mock.calls.find(([input, init]) =>
        String(input).includes('index.json') && init?.method === 'PUT')
      expect(catalogPut).toBeDefined()
      const catalogBody = JSON.parse(catalogPut![1]!.body as string)
      expect(catalogBody.stories).toEqual([
        { slug: 'demo', title: '新標題', place: demoScript.place, blurb: '測試簡介' },
        { slug: 'other', title: '別的故事', place: '別的地點', blurb: '別的簡介' },
      ])
    }, { timeout: 2000 })
  })
})

describe('EditorPage 左欄節點／結構分頁（Task 16）', () => {
  function stubFetchRoutes() {
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      if (init?.method === 'PUT') return new Response(null, { status: 204 })
      if (url.includes('index.json')) {
        return new Response(JSON.stringify({
          stories: [{ slug: 'demo', title: demoScript.title, place: demoScript.place, blurb: '測試簡介' }],
        }))
      }
      if (url.includes('script.json')) return new Response(JSON.stringify(demoScript))
      return new Response('{}')
    }))
  }

  test('預設顯示節點清單；切到「結構」分頁顯示節點圖', async () => {
    stubFetchRoutes()
    const user = userEvent.setup()
    render(<EditorPage />)
    await screen.findByRole('option', { name: demoScript.title })
    await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')

    // 預設節點分頁：NodeList 的拖曳把手存在
    expect(await screen.findAllByLabelText('拖曳排序')).toHaveLength(demoScript.nodes.length)

    await user.click(screen.getByRole('tab', { name: '結構' }))

    // 結構分頁：NodeList 消失，改顯示 GraphView 的節點卡片
    expect(screen.queryByLabelText('拖曳排序')).not.toBeInTheDocument()
    expect(await screen.findByRole('button', { name: `在 ${demoScript.nodes[0].id} 後面插入節點` })).toBeInTheDocument()
  })

  test('在結構分頁插入節點，成功變更會送出 PUT script.json（走既有樂觀+debounce 路徑）', async () => {
    stubFetchRoutes()
    const user = userEvent.setup()
    render(<EditorPage />)
    await screen.findByRole('option', { name: demoScript.title })
    await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')
    await user.click(screen.getByRole('tab', { name: '結構' }))

    // 節點卡片的按鈕在 React Flow pane 內：改用 fireEvent.click 直接送 click，
    // 避開 userEvent 完整指標事件序列觸發 d3-zoom/d3-drag 對 pane 的 mousedown
    // handler 在 jsdom 下丟例外的相容性問題（GraphView.test.tsx 同一慣例）。
    const first = demoScript.nodes[0]
    fireEvent.click(await screen.findByRole('button', { name: `在 ${first.id} 後面插入節點` }))

    await waitFor(() => {
      const scriptPut = vi.mocked(fetch).mock.calls.find(([input, init]) =>
        String(input).includes('script.json') && init?.method === 'PUT')
      expect(scriptPut).toBeDefined()
      const body = JSON.parse(scriptPut![1]!.body as string)
      expect(body.nodes).toHaveLength(demoScript.nodes.length + 1)
    }, { timeout: 2000 })
  })

  test('在結構分頁刪除有入邊的節點：顯示錯誤且不送出 PUT', async () => {
    stubFetchRoutes()
    const user = userEvent.setup()
    render(<EditorPage />)
    await screen.findByRole('option', { name: demoScript.title })
    await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')
    await user.click(screen.getByRole('tab', { name: '結構' }))

    fireEvent.click(await screen.findByRole('button', { name: '刪除節點 end-a' }))
    expect(await screen.findByRole('alert')).toBeInTheDocument()

    const scriptPut = vi.mocked(fetch).mock.calls.find(([input, init]) =>
      String(input).includes('script.json') && init?.method === 'PUT')
    expect(scriptPut).toBeUndefined()
  })
})

describe('EditorPage 外部更新 toast（Task 17 fix：消費 useStory 的 externalUpdate）', () => {
  function stubFetchRoutes() {
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      if (init?.method === 'PUT') return new Response(null, { status: 204 })
      if (url.includes('index.json')) {
        return new Response(JSON.stringify({
          stories: [{ slug: 'demo', title: demoScript.title, place: demoScript.place, blurb: '測試簡介' }],
        }))
      }
      if (url.includes('script.json')) return new Response(JSON.stringify(demoScript))
      return new Response('{}')
    }))
  }

  // EditorWorkspace 沒有把 useStory 的 subscribe deps 開放注入（只有 hook 層測試
  // 才這樣做），所以在這個整合測試層級要驗證 SSE，得攔截 api.subscribeEvents
  // 實際會 new 的全域 EventSource 建構子，取得實例後手動呼叫 onmessage 模擬伺服端
  // 推播——跟 test/setup.ts 的 MockEventSource 是同一種「最小假物件」手法，只是
  // 這裡額外把建立出來的實例存起來以便測試主動觸發。
  function stubEventSourceAndCapture() {
    let captured: { onmessage: ((e: MessageEvent) => void) | null } | null = null
    class CapturingEventSource {
      onmessage: ((e: MessageEvent) => void) | null = null
      constructor(_url: string) { captured = this }
      close() {}
    }
    const original = globalThis.EventSource
    // @ts-expect-error 測試用最小 EventSource 替身，只需 onmessage/close
    globalThis.EventSource = CapturingEventSource
    return {
      getCaptured: () => captured,
      restore: () => { globalThis.EventSource = original },
    }
  }

  test('SSE 收到目前故事的外部更新時顯示顯著 toast，內容帶檔名，約 4 秒後自動消失', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    stubFetchRoutes()
    const user = userEvent.setup()
    const { getCaptured, restore } = stubEventSourceAndCapture()

    try {
      render(<EditorPage />)
      await screen.findByRole('option', { name: demoScript.title })
      await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')
      await screen.findByRole('textbox', { name: '標題' })

      const source = getCaptured()
      expect(source).not.toBeNull()

      // 尚未有外部更新：不該有 toast
      // （注意：不能用 getByRole('status') 判斷有無——NodeList 的 dnd-kit
      // sortable context 本身就常駐一個 role="status" 的無障礙 live region
      // 用來播報拖曳狀態，跟本測試新增的 toast 會撞 role，改用文字內容比對）
      expect(screen.queryByText(/內容已被外部更新/)).not.toBeInTheDocument()

      act(() => {
        source!.onmessage?.({
          data: JSON.stringify({ type: 'change', slug: 'demo', file: 'script.json' }),
        } as MessageEvent)
      })

      const toast = await screen.findByText('內容已被外部更新：script.json')
      expect(toast).toHaveAttribute('role', 'status')

      // 4 秒後自動消失
      await act(async () => { await vi.advanceTimersByTimeAsync(4100) })
      expect(screen.queryByText(/內容已被外部更新/)).not.toBeInTheDocument()
    } finally {
      restore()
      vi.useRealTimers()
    }
  })

  test('4 秒內連續收到同一檔案的外部更新，計時重置（不會提早消失）', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    stubFetchRoutes()
    const user = userEvent.setup()
    const { getCaptured, restore } = stubEventSourceAndCapture()

    try {
      render(<EditorPage />)
      await screen.findByRole('option', { name: demoScript.title })
      await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')
      await screen.findByRole('textbox', { name: '標題' })

      const source = getCaptured()!
      const emit = () => act(() => {
        source.onmessage?.({
          data: JSON.stringify({ type: 'change', slug: 'demo', file: 'script.json' }),
        } as MessageEvent)
      })

      emit()
      await screen.findByText('內容已被外部更新：script.json')

      // 第一次事件後 3 秒（尚未到 4 秒），再來一次同檔案更新——計時應重置
      await act(async () => { await vi.advanceTimersByTimeAsync(3000) })
      emit()
      // 讓第二次事件觸發的非同步狀態更新（getJson resolve → setExternalUpdate／
      // setExternalUpdateSeq → effect 重新排程 setTimeout）先跑完，確保新的 4 秒
      // 計時器起點就是「現在」，後面推進的時間量才有確定的參考點
      await act(async () => { await vi.advanceTimersByTimeAsync(0) })

      // 從第二次事件起再過 3 秒：尚未到新的 4 秒，toast 應仍在
      await act(async () => { await vi.advanceTimersByTimeAsync(3000) })
      expect(screen.getByText('內容已被外部更新：script.json')).toBeInTheDocument()

      // 再過 1.2 秒：超過新計時器的 4 秒，toast 應消失
      await act(async () => { await vi.advanceTimersByTimeAsync(1200) })
      expect(screen.queryByText(/內容已被外部更新/)).not.toBeInTheDocument()
    } finally {
      restore()
      vi.useRealTimers()
    }
  })
})
