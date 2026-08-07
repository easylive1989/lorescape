import type { Script } from '../engine/schema'
import { assetUrl } from './loadScript'

const loadedUrls = new Set<string>()

function loadImage(url: string): void {
  if (loadedUrls.has(url)) return
  loadedUrls.add(url)
  const img = new Image()
  img.src = url
}

/** 對節點與其所有直接後繼節點（next / 每個 choice.to）的背景圖各觸發一次預載。
 * fire-and-forget；已載過的 URL 不重載。 */
export function preloadNode(script: Script, slug: string, nodeId: string): void {
  const node = script.nodes.find((n) => n.id === nodeId)
  if (!node) return

  loadImage(assetUrl(slug, node.background))

  const successorIds = [
    ...(node.next ? [node.next] : []),
    ...(node.choices?.map((c) => c.to) ?? []),
  ]
  for (const id of successorIds) {
    const successor = script.nodes.find((n) => n.id === id)
    if (successor) loadImage(assetUrl(slug, successor.background))
  }
}

/** 測試用：重置模組內的去重紀錄，避免測試間互相汙染。 */
export function __resetPreloadedForTest(): void {
  loadedUrls.clear()
}
