import { validateLayout, type Layout, type Script } from '../engine/schema'
import { contentUrl } from './loadScript'

export async function loadLayout(slug: string, script: Script): Promise<Layout> {
  const res = await fetch(contentUrl(slug, 'layout.json'))
  if (!res.ok) throw new Error(`layout 載入失敗：HTTP ${res.status}`)
  return validateLayout(await res.json(), script)
}
