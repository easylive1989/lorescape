import { vi, beforeEach, test, expect } from 'vitest'
import { AudioManager } from './audioManager'

class FakeAudio {
  static instances: FakeAudio[] = []
  src: string; volume = 1; loop = false; paused = true
  play = vi.fn(async () => { this.paused = false })
  pause = vi.fn(() => { this.paused = true })
  constructor(src: string) { this.src = src; FakeAudio.instances.push(this) }
}

beforeEach(() => {
  FakeAudio.instances = []
  vi.stubGlobal('Audio', FakeAudio)
  vi.useFakeTimers()
})

test('未 unlock 前 playBgm 不播放', () => {
  const am = new AudioManager()
  am.playBgm('/a.mp3')
  expect(FakeAudio.instances).toHaveLength(0)
})

test('unlock 後 playBgm 播放且 loop', () => {
  const am = new AudioManager()
  am.unlock(); am.playBgm('/a.mp3')
  expect(FakeAudio.instances[0].loop).toBe(true)
  expect(FakeAudio.instances[0].play).toHaveBeenCalled()
})

test('同曲重複呼叫不重播', () => {
  const am = new AudioManager()
  am.unlock(); am.playBgm('/a.mp3'); am.playBgm('/a.mp3')
  expect(FakeAudio.instances).toHaveLength(1)
})

test('換曲 crossfade 後舊曲 pause', () => {
  const am = new AudioManager()
  am.unlock(); am.playBgm('/a.mp3'); am.playBgm('/b.mp3')
  vi.advanceTimersByTime(1100)
  expect(FakeAudio.instances[0].pause).toHaveBeenCalled()
  expect(FakeAudio.instances[1].play).toHaveBeenCalled()
})
