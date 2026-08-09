export type ContentEvent = { type: string; slug: string; file: string }

export async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(path)
  if (!res.ok) throw new Error(`載入失敗：HTTP ${res.status}`)
  return (await res.json()) as T
}

export async function putJson(path: string, data: unknown): Promise<void> {
  const res = await fetch(path, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(data),
  })
  if (res.status === 400) {
    const body = await res.json().catch(() => null)
    const message = body && typeof body.error === 'string' ? body.error : '儲存失敗'
    throw new Error(message)
  }
  if (!res.ok) throw new Error(`儲存失敗：HTTP ${res.status}`)
}

export function subscribeEvents(onEvent: (event: ContentEvent) => void): () => void {
  const source = new EventSource('/__editor/events')
  source.onmessage = (e) => {
    try {
      onEvent(JSON.parse(e.data) as ContentEvent)
    } catch {
      // 忽略格式不正確的事件
    }
  }
  return () => source.close()
}
