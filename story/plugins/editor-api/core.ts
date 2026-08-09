import { execFile } from 'node:child_process'
import path from 'node:path'
import { catalogSchema, validateLayout, validateScript } from '../../src/engine/schema'

export type ContentFile = 'script.json' | 'art.json' | 'layout.json'

export function safeContentPath(root: string, slug: string, file: string): string | null {
  const resolved = path.resolve(root, slug, file)
  if (!resolved.startsWith(path.resolve(root) + path.sep)) return null
  if (slug.includes('..') || file.includes('..')) return null
  return resolved
}

export function safeAssetPath(root: string, slug: string, rel: string): string | null {
  // rel 限定在 assets/ 之下、只許 [\w./-]、不許 .. 跳脫路徑
  if (!rel.startsWith('assets/')) return null
  if (!/^[\w./-]+$/.test(rel)) return null
  if (rel.includes('..') || slug.includes('..')) return null
  const resolved = path.resolve(root, slug, rel)
  if (!resolved.startsWith(path.resolve(root) + path.sep)) return null
  return resolved
}

export async function compressPng(absPath: string): Promise<'compressed' | 'skipped'> {
  // 壓縮失敗（含未安裝 pngquant 的 ENOENT）一律視為 skipped，不阻擋上傳
  return new Promise((resolve) => {
    execFile(
      'pngquant', ['--quality=70-92', '--speed', '1', '--strip', '--ext', '.png', '--force', absPath],
      (error) => resolve(error ? 'skipped' : 'compressed'),
    )
  })
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
