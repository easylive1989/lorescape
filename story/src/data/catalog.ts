import { catalogSchema, type CatalogEntry } from '../engine/schema'
import { CONTENT_VERSION } from './loadScript'

export async function loadCatalog(): Promise<CatalogEntry[]> {
  const res = await fetch(`/content/index.json?v=${CONTENT_VERSION}`)
  if (!res.ok) throw new Error(`目錄載入失敗：HTTP ${res.status}`)
  return catalogSchema.parse(await res.json()).stories
}
