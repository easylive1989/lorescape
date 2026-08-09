import { beforeEach, expect, test, vi } from 'vitest'
import { assetUrl } from './loadScript'
import { preloadNode, __resetPreloadedForTest } from './preload'
import type { Script } from '../engine/schema'

// 三個節點各用不同背景圖，確保能驗證「載入所有 choice 目標的背景」而不會被
// URL 去重蓋掉判斷。
const script: Script = {
  slug: 'demo', title: '測試故事', place: '測試地', intro: '你是一名學徒。',
  startNode: 'n1',
  characters: [],
  nodes: [
    { id: 'n1', background: 'scenes/n1.png', paragraphs: ['第一段'], choices: [
      { text: '往左', to: 'end-a' }, { text: '往右', to: 'end-b' }] },
    { id: 'end-a', background: 'scenes/end-a.png', paragraphs: ['結局A'], ending: { title: '結局A' } },
    { id: 'end-b', background: 'scenes/end-b.png', paragraphs: ['結局B'], ending: { title: '結局B' } },
  ],
}

// stub Image，收集所有 instance 的 src（仿 PlayPage.test 的 FakeAudio 模式）。
let instances: FakeImage[]

class FakeImage {
  src = ''
  constructor() { instances.push(this) }
}

beforeEach(() => {
  instances = []
  vi.stubGlobal('Image', FakeImage)
  __resetPreloadedForTest()
})

test('對選擇節點呼叫會載入該節點與所有 choice 目標的背景', () => {
  preloadNode(script, 'demo', 'n1')
  const srcs = instances.map((i) => i.src)
  expect(srcs).toContain(assetUrl('demo', 'scenes/n1.png'))
  expect(srcs).toContain(assetUrl('demo', 'scenes/end-a.png'))
  expect(srcs).toContain(assetUrl('demo', 'scenes/end-b.png'))
  expect(srcs.length).toBe(3)
})

test('重複呼叫不重載', () => {
  preloadNode(script, 'demo', 'n1')
  const countAfterFirst = instances.length
  preloadNode(script, 'demo', 'n1')
  expect(instances.length).toBe(countAfterFirst)
})
