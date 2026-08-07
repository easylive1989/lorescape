import { validateScript, type Script } from '../engine/schema'

export async function loadScript(slug: string): Promise<Script> {
  const res = await fetch(`/content/${slug}/script.json`)
  if (!res.ok) throw new Error(`劇本載入失敗：HTTP ${res.status}`)
  return validateScript(await res.json())
}

export function assetUrl(slug: string, path: string): string {
  return `/content/${slug}/assets/${path}`
}
