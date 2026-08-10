import { validateScript, type Script } from '../engine/schema'

/* /content/** is served with max-age=3600 (files keep the same path when art
   is regenerated), so bump this whenever deployed content changes shape in a
   way stale caches would break — the query string busts every client cache
   at the next JS deploy. */
export const CONTENT_VERSION = '4'

export function contentUrl(slug: string, file: string): string {
  return `/content/${slug}/${file}?v=${CONTENT_VERSION}`
}

export async function loadScript(slug: string): Promise<Script> {
  const res = await fetch(contentUrl(slug, 'script.json'))
  if (!res.ok) throw new Error(`劇本載入失敗：HTTP ${res.status}`)
  return validateScript(await res.json())
}

export function assetUrl(slug: string, path: string): string {
  return contentUrl(slug, `assets/${path}`)
}
