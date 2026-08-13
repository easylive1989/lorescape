import { useEffect, useRef, useState } from 'react'
import { useParams } from 'react-router-dom'
import { loadScript, assetUrl } from '../data/loadScript'
import { preloadNode } from '../data/preload'
import { saveProgress, loadProgress, clearProgress } from '../data/progress'
import { trackEvent } from '../data/analytics'
import { initState, advance, choose as choosePlayer, currentNode, visibleChoices, type PlayState } from '../engine/player'
import type { Script } from '../engine/schema'
import { SceneView } from '../components/SceneView'
import { EndingView } from '../components/EndingView'
import { audioManager } from '../audio/audioManager'

export function PlayPage() {
  const { slug = '' } = useParams()
  const [script, setScript] = useState<Script | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [started, setStarted] = useState(false)
  const [state, setState] = useState<PlayState | null>(null)
  const [retryCount, setRetryCount] = useState(0)
  const endingTracked = useRef(false)

  useEffect(() => {
    setError(null)
    loadScript(slug)
      .then((loadedScript) => setScript(loadedScript))
      .catch((e: Error) => setError(e.message))
  }, [slug, retryCount])

  useEffect(() => {
    if (!script || !state) return
    const bgm = currentNode(script, state).bgm
    if (bgm) audioManager.playBgm(assetUrl(slug, bgm))
  }, [script, state, slug])

  useEffect(() => {
    const nodeId = state?.nodeId
    if (!script || !nodeId) return
    preloadNode(script, slug, nodeId)
    trackEvent(slug, 'node_enter', { node: nodeId })
  }, [script, state?.nodeId, slug])

  useEffect(() => {
    if (!state) return
    if (state.status === 'ended') clearProgress(slug)
    else saveProgress(slug, state)
  }, [state, slug])

  useEffect(() => {
    if (!script || !state || state.status !== 'ended' || endingTracked.current) return
    endingTracked.current = true
    trackEvent(slug, 'ending_reached', { node: currentNode(script, state).id })
  }, [script, state, slug])

  if (error) return (
    <div data-testid="play-page">
      {error}
      <button onClick={() => setRetryCount((c) => c + 1)}>重新載入</button>
    </div>
  )
  if (!script) return <div data-testid="play-page">載入中…</div>
  if (!started) {
    const loaded = loadProgress(slug)
    // 存檔可能指向已被劇本改版移除的節點（過期存檔）；此時視同無存檔，避免
    // currentNode() 在後續 useEffect 找不到節點而丟出未捕捉例外。
    const saved = loaded && script.nodes.some((n) => n.id === loaded.nodeId) ? loaded : null
    return (
      <div data-testid="play-page" className="intro">
        <h1>{script.title}</h1>
        <p>{script.intro}</p>
        <button
          onClick={() => {
            audioManager.unlock()
            trackEvent(slug, 'start')
            setState(saved ?? initState(script))
            setStarted(true)
          }}
        >
          {saved ? '繼續上次' : '開始體驗'}
        </button>
        {saved && (
          <button
            onClick={() => {
              audioManager.unlock()
              trackEvent(slug, 'start')
              clearProgress(slug)
              setState(initState(script))
              setStarted(true)
            }}
          >
            從頭開始
          </button>
        )}
      </div>
    )
  }
  if (!state) return null
  return (
    <div data-testid="play-page">
      {state.status === 'ended' ? (
        <EndingView endingTitle={currentNode(script, state).ending?.title} slug={slug} />
      ) : (
        <SceneView
          script={script}
          state={state}
          slug={slug}
          onAdvance={() => setState(advance(script, state))}
          onChoose={(i) => {
            const node = currentNode(script, state)
            // 追蹤送的是玩家實際點了第幾個（可見索引），與 JSON 裡的位置可能不同。
            const text = visibleChoices(node, state.flags)[i]?.text
            trackEvent(slug, 'choice_made', { node: node.id, index: i, text })
            setState(choosePlayer(script, state, i))
          }}
        />
      )}
    </div>
  )
}
