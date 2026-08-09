import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { vi, beforeEach } from 'vitest'
import { PlayPage } from './PlayPage'
import { demoScript, demoLayout } from '../test/fixtures'

vi.mock('../data/analytics', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../data/analytics')>()
  return { ...actual, submitSurvey: vi.fn(async () => true) }
})

// n1 節點掛了 bgm，PlayPage 開始體驗後會走到 audioManager.playBgm() -> new Audio().play()。
// jsdom 沒有實作 HTMLMediaElement.play()，不 stub 掉會印出 "Not implemented" 的 console 雜訊。
class FakeAudio {
  src: string; volume = 1; loop = false; paused = true
  play = vi.fn(async () => { this.paused = false })
  pause = vi.fn(() => { this.paused = true })
  constructor(src: string) { this.src = src }
}

// script.json 與 layout.json 共用一顆 fetch mock，依 URL 路由回對應假資料。
function fetchStub(url: string | URL | Request) {
  const body = String(url).includes('layout.json') ? demoLayout : demoScript
  return Promise.resolve(new Response(JSON.stringify(body)))
}

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn(fetchStub))
  vi.stubGlobal('Audio', FakeAudio)
  localStorage.clear()
})

function renderPlay() {
  return render(
    <MemoryRouter initialEntries={['/play/demo']}>
      <Routes><Route path="/play/:slug" element={<PlayPage />} /></Routes>
    </MemoryRouter>,
  )
}

test('載入後顯示 intro 與開始按鈕', async () => {
  renderPlay()
  expect(await screen.findByText('你是一名學徒。')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: '開始體驗' })).toBeInTheDocument()
})

test('開始後顯示第一段，tap 推進到第二段', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  expect(screen.getByText('第一段')).toBeInTheDocument()
  await userEvent.click(screen.getByTestId('text-card'))
  expect(screen.getByText('第二段')).toBeInTheDocument()
})

test('段落結束顯示選項，選擇後跳結局節點', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByRole('button', { name: '往左' }))
  expect(screen.getByText('結局A')).toBeInTheDocument()
})

test('結局段落結束後顯示 ending 佔位', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByRole('button', { name: '往左' }))
  await userEvent.click(screen.getByTestId('text-card'))
  expect(screen.getByTestId('ending')).toBeInTheDocument()
})

test('有進度時 intro 顯示「繼續上次」且從存檔恢復', async () => {
  localStorage.setItem('story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 1, status: 'playing' }))
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '繼續上次' }))
  expect(screen.getByText('第二段')).toBeInTheDocument()
})

test('有進度時可選「從頭開始」清存檔並重新開始', async () => {
  localStorage.setItem('story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 1, status: 'playing' }))
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '從頭開始' }))
  expect(screen.getByText('第一段')).toBeInTheDocument()
  expect(localStorage.getItem('story-progress:demo')).toBe(
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 0, status: 'playing' }),
  )
})

test('存檔 nodeId 已不存在於劇本時，intro 視為無存檔並顯示「開始體驗」', async () => {
  localStorage.setItem('story-progress:demo',
    JSON.stringify({ nodeId: 'removed-node', paragraphIndex: 0, status: 'playing' }))
  renderPlay()
  expect(await screen.findByRole('button', { name: '開始體驗' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: '繼續上次' })).not.toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: '開始體驗' }))
  expect(screen.getByText('第一段')).toBeInTheDocument()
})

test('存檔缺欄位（壞資料）時，intro 視為無存檔並顯示「開始體驗」', async () => {
  localStorage.setItem('story-progress:demo', JSON.stringify({ nodeId: 'n1' }))
  renderPlay()
  expect(await screen.findByRole('button', { name: '開始體驗' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: '繼續上次' })).not.toBeInTheDocument()
})

test('ended 時清除進度', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByRole('button', { name: '往左' }))
  await userEvent.click(screen.getByTestId('text-card'))
  expect(screen.getByTestId('ending')).toBeInTheDocument()
  expect(localStorage.getItem('story-progress:demo')).toBeNull()
})

test('結局後點「留下你的感受」送出問卷，顯示感謝頁與 IG 連結', async () => {
  renderPlay()
  await userEvent.click(await screen.findByRole('button', { name: '開始體驗' }))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByTestId('text-card'))
  await userEvent.click(screen.getByRole('button', { name: '往左' }))
  await userEvent.click(screen.getByTestId('text-card'))
  expect(screen.getByTestId('ending')).toBeInTheDocument()

  await userEvent.click(screen.getByRole('button', { name: '留下你的感受' }))
  await userEvent.click(screen.getByRole('radio', { name: '5' }))
  await userEvent.click(screen.getByRole('radio', { name: '想玩' }))
  await userEvent.type(screen.getByRole('textbox', { name: /印象深刻/ }), '很棒')
  await userEvent.click(screen.getByRole('button', { name: '送出' }))

  expect(await screen.findByText('追蹤 IG，下週有新故事')).toBeInTheDocument()
  const igLink = screen.getByRole('link', { name: /Instagram/ })
  expect(igLink).toHaveAttribute('href', 'https://www.instagram.com/lorescape.app/')
  expect(igLink).toHaveAttribute('target', '_blank')
  expect(igLink).toHaveAttribute('rel', 'noopener')

  const replayLink = screen.getByRole('link', { name: '再玩一次' })
  expect(replayLink).toHaveAttribute('href', '/play/demo')
})

test('劇本載入失敗顯示錯誤與「重新載入」按鈕，點擊後重試成功顯示 intro', async () => {
  const fetchMock = vi.fn(async (_url: string | URL | Request) => new Response('', { status: 500 }))
  vi.stubGlobal('fetch', fetchMock)
  renderPlay()
  expect(await screen.findByRole('button', { name: '重新載入' })).toBeInTheDocument()

  fetchMock.mockImplementation(fetchStub)
  await userEvent.click(screen.getByRole('button', { name: '重新載入' }))
  expect(await screen.findByText('你是一名學徒。')).toBeInTheDocument()
})
