import type { PlayState, PlayStatus } from '../engine/player'

const PLAY_STATUSES: readonly PlayStatus[] = ['playing', 'choosing', 'ended']

function storageKey(slug: string): string {
  return `story-progress:${slug}`
}

function isPlayState(value: unknown): value is PlayState {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false
  const v = value as Record<string, unknown>
  return (
    typeof v.nodeId === 'string' &&
    v.nodeId.length > 0 &&
    typeof v.paragraphIndex === 'number' &&
    Number.isInteger(v.paragraphIndex) &&
    v.paragraphIndex >= 0 &&
    typeof v.status === 'string' &&
    (PLAY_STATUSES as readonly string[]).includes(v.status)
  )
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
    const parsed: unknown = JSON.parse(raw)
    return isPlayState(parsed) ? parsed : null
  } catch {
    return null
  }
}

export function clearProgress(slug: string): void {
  localStorage.removeItem(storageKey(slug))
}
