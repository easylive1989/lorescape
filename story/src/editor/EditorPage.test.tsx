import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import EditorPage, { forceCenterCast } from './EditorPage'
import { demoScript, demoLayout } from '../test/fixtures'
import type { Layout, Script } from '../engine/schema'

// 修法（code review round 1）：骨骼模式下，同一節點若有多角色或非置中站位
// （n6 雙人、多個節點用 left/right），BoneEditor 固定的單人置中幾何（見
// BoneEditor.tsx 的 .bone-editor：sprite--center、72% 寬）跟真實 sprite 容器
// 對不上，部件框會視覺錯位。EditorPage.forceCenterCast 在骨骼模式時把預覽
// 節點的 cast 換成「僅編輯中角色、置中」（純展示派生，不落盤），讓兩者天然
// 對齊。

describe('forceCenterCast（純函式）', () => {
  test('把指定節點的 cast 換成單一角色、置中；其他節點不受影響', () => {
    const twoCast: Script = {
      ...demoScript,
      nodes: demoScript.nodes.map((n) =>
        n.id === 'n1'
          ? { ...n, cast: [{ character: 'master', position: 'left' as const }, { character: 'apprentice', position: 'right' as const }] }
          : n,
      ),
    }
    const next = forceCenterCast(twoCast, 'n1', 'master')
    const n1 = next.nodes.find((n) => n.id === 'n1')!
    expect(n1.cast).toEqual([{ character: 'master', position: 'center' }])
    // 其他節點原樣不變
    const otherNode = next.nodes.find((n) => n.id !== 'n1')!
    const originalOther = twoCast.nodes.find((n) => n.id === otherNode.id)!
    expect(otherNode).toEqual(originalOther)
    // 不可變：原 script 不受影響
    expect(twoCast.nodes.find((n) => n.id === 'n1')!.cast).toHaveLength(2)
  })
})

describe('EditorPage 骨骼模式：舞台強制單人置中', () => {
  function twoCharacterFixtures() {
    const script: Script = {
      ...demoScript,
      characters: [
        ...demoScript.characters,
        {
          id: 'apprentice', name: '徒弟',
          parts: {
            head: 'characters/apprentice/head.png', torso: 'characters/apprentice/torso.png',
            leftArm: 'characters/apprentice/left-arm.png', rightArm: 'characters/apprentice/right-arm.png',
          },
        },
      ],
      nodes: demoScript.nodes.map((n) =>
        n.id === demoScript.startNode
          ? {
              ...n,
              cast: [
                { character: 'master', position: 'left' as const },
                { character: 'apprentice', position: 'right' as const },
              ],
            }
          : n,
      ),
    }
    const layout: Layout = {
      ...demoLayout,
      characters: { ...demoLayout.characters, apprentice: demoLayout.characters.master },
    }
    return { script, layout }
  }

  function stubFetchRoutes(script: Script, layout: Layout) {
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      if (init?.method === 'PUT') return new Response(null, { status: 204 })
      if (url.includes('index.json')) {
        return new Response(JSON.stringify({
          stories: [{ slug: 'demo', title: script.title, place: script.place, blurb: '測試' }],
        }))
      }
      if (url.includes('script.json')) return new Response(JSON.stringify(script))
      if (url.includes('layout.json')) return new Response(JSON.stringify(layout))
      return new Response('{}')
    }))
  }

  test('雙人（left/right）節點開啟骨骼模式後，舞台只渲染編輯中角色且置中', async () => {
    const { script, layout } = twoCharacterFixtures()
    stubFetchRoutes(script, layout)
    const user = userEvent.setup()

    render(<EditorPage />)
    await screen.findByRole('option', { name: script.title })
    await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')

    const boneToggle = await screen.findByLabelText('骨骼模式')
    expect(boneToggle).not.toBeDisabled()

    // 開啟前：雙人都在舞台上，各自站位 left/right
    expect(screen.getByTestId('sprite-master').className).toContain('sprite--left')
    expect(screen.getByTestId('sprite-apprentice').className).toContain('sprite--right')

    await user.click(boneToggle)

    // 開啟後：只剩編輯中角色（cast 第一個＝master），且被強制置中
    await waitFor(() => {
      expect(screen.getByTestId('sprite-master').className).toContain('sprite--center')
    })
    expect(screen.queryByTestId('sprite-apprentice')).not.toBeInTheDocument()

    // BoneEditor 的部件框仍然疊在舞台上
    expect(screen.getByTestId('bone-editor')).toBeInTheDocument()

    const stage = screen.getByTestId('sprite-master').closest('.scene') as HTMLElement
    expect(within(stage).getAllByTestId(/^sprite-/)).toHaveLength(1)
  })
})

describe('EditorPage 故事屬性面板（Task 15）', () => {
  function stubFetchRoutes() {
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      if (init?.method === 'PUT') return new Response(null, { status: 204 })
      if (url.includes('/__editor/assets/')) {
        return new Response(JSON.stringify({ files: [{ path: 'characters/master/new-head.png', mtime: 1 }] }))
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
      if (url.includes('layout.json')) return new Response(JSON.stringify(demoLayout))
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

  test('點角色部件換檔鈕開 AssetPicker，選圖後把新檔路徑寫回該角色部件並送出 PUT', async () => {
    stubFetchRoutes()
    const user = userEvent.setup()
    render(<EditorPage />)
    await screen.findByRole('option', { name: demoScript.title })
    await user.selectOptions(screen.getByLabelText('選擇故事'), 'demo')
    await screen.findByRole('textbox', { name: '標題' })

    await user.click(screen.getByRole('button', { name: '換檔／師傅／頭' }))
    const thumb = await screen.findByRole('button', { name: '選擇 characters/master/new-head.png' })
    await user.click(thumb)

    // 選圖後 AssetPicker 應收合
    expect(screen.queryByRole('button', { name: /^選擇 /})).not.toBeInTheDocument()

    await waitFor(() => {
      const putCall = vi.mocked(fetch).mock.calls.find(([input, init]) =>
        String(input).includes('script.json') && init?.method === 'PUT')
      expect(putCall).toBeDefined()
      const body = JSON.parse(putCall![1]!.body as string)
      expect(body.characters[0].parts.head).toBe('characters/master/new-head.png')
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
