import { useCallback, useEffect, useRef, useState } from 'react'
import type { Layout, Script } from '../engine/schema'
import { getJson, putJson, subscribeEvents, type ContentEvent } from './api'

const DEBOUNCE_MS = 500

type UseStoryDeps = { subscribe?: typeof subscribeEvents }

export function useStory(slug: string, deps: UseStoryDeps = {}) {
  const subscribe = deps.subscribe ?? subscribeEvents

  const [script, setScript] = useState<Script | null>(null)
  const [art, setArt] = useState<Record<string, unknown> | null>(null)
  const [layout, setLayout] = useState<Layout | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [externalUpdate, setExternalUpdate] = useState<string | null>(null)

  const scriptTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const layoutTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const scriptPath = `/__editor/content/${slug}/script.json`
  const artPath = `/__editor/content/${slug}/art.json`
  const layoutPath = `/__editor/content/${slug}/layout.json`

  // mount（或換 slug）時並行載入三份內容
  useEffect(() => {
    let cancelled = false
    setScript(null)
    setArt(null)
    setLayout(null)
    setError(null)
    setExternalUpdate(null)
    const handleLoadError = (err: unknown) => {
      if (!cancelled) setError(err instanceof Error ? err.message : String(err))
    }
    getJson<Script>(scriptPath).then((s) => { if (!cancelled) setScript(s) }, handleLoadError)
    getJson<Record<string, unknown>>(artPath).then((a) => { if (!cancelled) setArt(a) }, handleLoadError)
    getJson<Layout>(layoutPath).then((l) => { if (!cancelled) setLayout(l) }, handleLoadError)
    return () => { cancelled = true }
  }, [slug, scriptPath, artPath, layoutPath])

  // SSE：外部更新命中目前故事的檔案時，捨棄尚未送出的本地變更並改用伺服端內容
  useEffect(() => {
    const refreshFromServer = <T,>(
      file: string,
      path: string,
      timer: { current: ReturnType<typeof setTimeout> | null } | null,
      apply: (value: T) => void,
    ) => {
      if (timer?.current) { clearTimeout(timer.current); timer.current = null }
      getJson<T>(path).then((value) => {
        apply(value)
        setExternalUpdate(file)
      }, (err) => setError(err instanceof Error ? err.message : String(err)))
    }

    const unsubscribe = subscribe((event: ContentEvent) => {
      if (event.slug !== slug) return
      if (event.file === 'script.json') refreshFromServer<Script>('script.json', scriptPath, scriptTimer, setScript)
      else if (event.file === 'layout.json') refreshFromServer<Layout>('layout.json', layoutPath, layoutTimer, setLayout)
      // art.json 目前沒有本地編輯／debounce（無 updateArt），單純覆蓋 state 並標記 externalUpdate
      else if (event.file === 'art.json') refreshFromServer<Record<string, unknown>>('art.json', artPath, null, setArt)
    })
    return unsubscribe
  }, [slug, subscribe, scriptPath, layoutPath, artPath])

  // unmount 時清掉尚未觸發的 debounce timer，避免對已卸載的故事發 PUT
  useEffect(() => () => {
    if (scriptTimer.current) clearTimeout(scriptTimer.current)
    if (layoutTimer.current) clearTimeout(layoutTimer.current)
  }, [])

  const updateScript = useCallback((next: Script) => {
    setScript(next)
    if (scriptTimer.current) clearTimeout(scriptTimer.current)
    scriptTimer.current = setTimeout(() => {
      scriptTimer.current = null
      putJson(scriptPath, next).catch((err) => setError(err instanceof Error ? err.message : String(err)))
    }, DEBOUNCE_MS)
  }, [scriptPath])

  const updateLayout = useCallback((next: Layout) => {
    setLayout(next)
    if (layoutTimer.current) clearTimeout(layoutTimer.current)
    layoutTimer.current = setTimeout(() => {
      layoutTimer.current = null
      putJson(layoutPath, next).catch((err) => setError(err instanceof Error ? err.message : String(err)))
    }, DEBOUNCE_MS)
  }, [layoutPath])

  return { script, art, layout, error, externalUpdate, updateScript, updateLayout }
}
