import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { vi, beforeEach } from 'vitest'
import { PlayPage } from './PlayPage'
import { demoScript } from '../test/fixtures'

// n1 節點掛了 bgm，PlayPage 開始體驗後會走到 audioManager.playBgm() -> new Audio().play()。
// jsdom 沒有實作 HTMLMediaElement.play()，不 stub 掉會印出 "Not implemented" 的 console 雜訊。
class FakeAudio {
  src: string; volume = 1; loop = false; paused = true
  play = vi.fn(async () => { this.paused = false })
  pause = vi.fn(() => { this.paused = true })
  constructor(src: string) { this.src = src }
}

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify(demoScript))))
  vi.stubGlobal('Audio', FakeAudio)
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
