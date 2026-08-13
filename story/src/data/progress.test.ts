import { beforeEach, expect, test } from 'vitest'
import { saveProgress, loadProgress, clearProgress } from './progress'
import type { PlayState } from '../engine/player'

const state: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'playing', flags: ['sealed'] }

beforeEach(() => {
  localStorage.clear()
})

test('save 後 load 相等', () => {
  saveProgress('demo', state)
  expect(loadProgress('demo')).toEqual(state)
})

test('load 不存在回 null', () => {
  expect(loadProgress('demo')).toBeNull()
})

test('localStorage 存壞 JSON 回 null', () => {
  localStorage.setItem('story-progress:demo', '{not valid json')
  expect(loadProgress('demo')).toBeNull()
})

test('缺欄位（可解析但非 PlayState 形狀）回 null', () => {
  localStorage.setItem('story-progress:demo', JSON.stringify({ nodeId: 'n1' }))
  expect(loadProgress('demo')).toBeNull()
})

test('欄位型別錯誤回 null', () => {
  localStorage.setItem(
    'story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 'not-a-number', status: 'playing' }),
  )
  expect(loadProgress('demo')).toBeNull()
})

test('status 為未知值回 null', () => {
  localStorage.setItem(
    'story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 0, status: 'not-a-status' }),
  )
  expect(loadProgress('demo')).toBeNull()
})

test('非物件（陣列 / 字串 / 數字）回 null', () => {
  localStorage.setItem('story-progress:demo', JSON.stringify(['n1', 0, 'playing']))
  expect(loadProgress('demo')).toBeNull()
})

test('clear 後回 null', () => {
  saveProgress('demo', state)
  clearProgress('demo')
  expect(loadProgress('demo')).toBeNull()
})

test('舊存檔沒有 flags 時補成空陣列', () => {
  localStorage.setItem(
    'story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 1, status: 'playing' }),
  )
  expect(loadProgress('demo')).toEqual({
    nodeId: 'n1', paragraphIndex: 1, status: 'playing', flags: [],
  })
})

test('flags 型別不對時補成空陣列', () => {
  localStorage.setItem(
    'story-progress:demo',
    JSON.stringify({ nodeId: 'n1', paragraphIndex: 1, status: 'playing', flags: 'sealed' }),
  )
  expect(loadProgress('demo')?.flags).toEqual([])
})

test('合法 flags 原樣載入', () => {
  saveProgress('demo', state)
  expect(loadProgress('demo')?.flags).toEqual(['sealed'])
})
