import type { PlayState } from '../engine/player'

function storageKey(slug: string): string {
  return `story-progress:${slug}`
}

export function saveProgress(slug: string, state: PlayState): void {
  try {
    localStorage.setItem(storageKey(slug), JSON.stringify(state))
  } catch {
    // localStorage 不可用時放棄保存
  }
}

export function loadProgress(slug: string): PlayState | null {
  const raw = localStorage.getItem(storageKey(slug))
  if (!raw) return null
  try {
    return JSON.parse(raw) as PlayState
  } catch {
    return null
  }
}

export function clearProgress(slug: string): void {
  localStorage.removeItem(storageKey(slug))
}
