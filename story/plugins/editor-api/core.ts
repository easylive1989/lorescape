import path from 'node:path'
import { catalogSchema, validateLayout, validateScript } from '../../src/engine/schema'

export type ContentFile = 'script.json' | 'art.json' | 'layout.json'

export function safeContentPath(root: string, slug: string, file: string): string | null {
  const resolved = path.resolve(root, slug, file)
  if (!resolved.startsWith(path.resolve(root) + path.sep)) return null
  if (slug.includes('..') || file.includes('..')) return null
  return resolved
}

export function validateContentPayload(
  file: ContentFile | 'index.json', data: unknown,
  context?: { script?: unknown },
): { ok: true } | { ok: false; error: string } {
  try {
    if (file === 'script.json') validateScript(data)
    else if (file === 'layout.json')
      validateLayout(data, context?.script ? validateScript(context.script) : undefined)
    else if (file === 'index.json') catalogSchema.parse(data)
    else if (file === 'art.json') JSON.parse(JSON.stringify(data))
    // default-deny：不在已知四種內容檔名之列一律擋下，避免未知檔名跳過驗證直接落盤
    else return { ok: false, error: 'unknown content file' }
    return { ok: true }
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : String(error) }
  }
}
