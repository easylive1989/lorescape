import { useCallback, useEffect, useRef, useState } from 'react'
import type { CatalogEntry, Layout, Script } from '../engine/schema'
import { getJson, putJson, subscribeEvents, type ContentEvent } from './api'

const DEBOUNCE_MS = 500
const CATALOG_PATH = '/__editor/content/index.json'

type Catalog = { stories: CatalogEntry[] }

type UseStoryDeps = { subscribe?: typeof subscribeEvents }

export function useStory(slug: string, deps: UseStoryDeps = {}) {
  const subscribe = deps.subscribe ?? subscribeEvents

  const [script, setScript] = useState<Script | null>(null)
  const [art, setArt] = useState<Record<string, unknown> | null>(null)
  const [layout, setLayout] = useState<Layout | null>(null)
  const [catalog, setCatalog] = useState<Catalog | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [externalUpdate, setExternalUpdate] = useState<string | null>(null)
  // 每次 SSE 觸發的外部更新都遞增，即使同一檔案連續被外部改動、externalUpdate
  // 字串值不變（React 對相同值的 state 不會視為變更），EditorPage 的 toast 仍能
  // 靠這個 seq 判斷「又來了一次新的外部更新」並重置顯示計時。
  const [externalUpdateSeq, setExternalUpdateSeq] = useState(0)

  const scriptTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const layoutTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const catalogTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const scriptPath = `/__editor/content/${slug}/script.json`
  const artPath = `/__editor/content/${slug}/art.json`
  const layoutPath = `/__editor/content/${slug}/layout.json`

  // mount（或換 slug）時並行載入內容：script／art／layout／index.json（取 catalogEntry 用）
  useEffect(() => {
    let cancelled = false
    setScript(null)
    setArt(null)
    setLayout(null)
    setCatalog(null)
    setError(null)
    setExternalUpdate(null)
    setExternalUpdateSeq(0)
    const handleLoadError = (err: unknown) => {
      if (!cancelled) setError(err instanceof Error ? err.message : String(err))
    }
    getJson<Script>(scriptPath).then((s) => { if (!cancelled) setScript(s) }, handleLoadError)
    getJson<Record<string, unknown>>(artPath).then((a) => { if (!cancelled) setArt(a) }, handleLoadError)
    getJson<Layout>(layoutPath).then((l) => { if (!cancelled) setLayout(l) }, handleLoadError)
    getJson<Catalog>(CATALOG_PATH).then((c) => { if (!cancelled) setCatalog(c) }, handleLoadError)
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
        setExternalUpdateSeq((n) => n + 1)
      }, (err) => setError(err instanceof Error ? err.message : String(err)))
    }

    const unsubscribe = subscribe((event: ContentEvent) => {
      // index.json 是跨故事共用檔，事件的 slug 固定是空字串，不受目前 slug 篩選
      if (event.file === 'index.json') {
        if (event.slug !== '') return
        refreshFromServer<Catalog>('index.json', CATALOG_PATH, catalogTimer, setCatalog)
        return
      }
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
    if (catalogTimer.current) clearTimeout(catalogTimer.current)
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

  // 讀-改-寫：index.json 是所有故事共用一份，只改目前 slug 那筆的欄位（title/place/blurb
  // 任意子集），其他故事條目原樣寫回。title/place 也存在 script.json 裡（EditorPage 的
  // handleScriptMeta 負責兩邊同步），這裡只管 index.json 這一份。
  const updateCatalogEntry = useCallback((patch: Partial<Pick<CatalogEntry, 'title' | 'place' | 'blurb'>>) => {
    if (!catalog) return
    const next: Catalog = {
      stories: catalog.stories.map((s) => (s.slug === slug ? { ...s, ...patch } : s)),
    }
    setCatalog(next)
    if (catalogTimer.current) clearTimeout(catalogTimer.current)
    catalogTimer.current = setTimeout(() => {
      catalogTimer.current = null
      putJson(CATALOG_PATH, next).catch((err) => setError(err instanceof Error ? err.message : String(err)))
    }, DEBOUNCE_MS)
  }, [catalog, slug])

  const updateBlurb = useCallback((blurb: string) => updateCatalogEntry({ blurb }), [updateCatalogEntry])

  const catalogEntry = catalog?.stories.find((s) => s.slug === slug) ?? null

  return {
    script, art, layout, catalogEntry, error, externalUpdate, externalUpdateSeq,
    updateScript, updateLayout, updateBlurb, updateCatalogEntry,
  }
}
