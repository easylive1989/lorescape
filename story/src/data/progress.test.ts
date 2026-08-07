import { beforeEach, expect, test } from 'vitest'
import { saveProgress, loadProgress, clearProgress } from './progress'
import type { PlayState } from '../engine/player'

const state: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'playing' }

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

test('clear 後回 null', () => {
  saveProgress('demo', state)
  clearProgress('demo')
  expect(loadProgress('demo')).toBeNull()
})
