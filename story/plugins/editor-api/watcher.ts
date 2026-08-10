import path from 'node:path'

export type ContentEvent = { type: 'change' | 'add' | 'unlink'; slug: string; file: string }

export function classifyPath(root: string, absPath: string): ContentEvent | null {
  const rel = path.relative(root, absPath)
  if (rel.startsWith('..') || path.isAbsolute(rel)) return null
  const segments = rel.split(path.sep)
  if (segments.length === 1) return { type: 'change', slug: '', file: segments[0] }
  return { type: 'change', slug: segments[0], file: segments.slice(1).join('/') }
}

export class SelfWriteGuard {
  private writes = new Map<string, number>()
  markWrite(absPath: string): void { this.writes.set(absPath, Date.now()) }
  isSelf(absPath: string): boolean {
    const at = this.writes.get(absPath)
    return at !== undefined && Date.now() - at < 1500
  }
}
