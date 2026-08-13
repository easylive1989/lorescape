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

// 正規化 flags：若為有效的字串陣列則保留，否則補成空陣列
function normalizeFlags(value: unknown): string[] {
  return Array.isArray(value) && value.every((v) => typeof v === 'string') ? value : []
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
    if (!isPlayState(parsed)) return null
    // 正規化在這裡做，呼叫端永遠拿得到合法的 flags。舊存檔因此會走 !flag 那
    // 一支——那份存檔本來就不含這個資訊，無法還原。
    return { ...parsed, flags: normalizeFlags((parsed as Record<string, unknown>).flags) }
  } catch {
    return null
  }
}

export function clearProgress(slug: string): void {
  localStorage.removeItem(storageKey(slug))
}
