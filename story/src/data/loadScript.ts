import { validateScript, type Script } from '../engine/schema'

/* /content/** is served with max-age=3600 (files keep the same path when art
   is regenerated), so bump this whenever deployed content changes shape in a
   way stale caches would break — the query string busts every client cache
   at the next JS deploy. */
const CONTENT_VERSION = '3'

export async function loadScript(slug: string): Promise<Script> {
  const res = await fetch(`/content/${slug}/script.json?v=${CONTENT_VERSION}`)
  if (!res.ok) throw new Error(`劇本載入失敗：HTTP ${res.status}`)
  return validateScript(await res.json())
}

export function assetUrl(slug: string, path: string): string {
  return `/content/${slug}/assets/${path}?v=${CONTENT_VERSION}`
}
