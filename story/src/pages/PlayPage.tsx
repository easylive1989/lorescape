import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { loadScript, assetUrl } from '../data/loadScript'
import { saveProgress, loadProgress, clearProgress } from '../data/progress'
import { initState, advance, choose, currentNode, type PlayState } from '../engine/player'
import type { Script } from '../engine/schema'
import { SceneView } from '../components/SceneView'
import { audioManager } from '../audio/audioManager'

export function PlayPage() {
  const { slug = '' } = useParams()
  const [script, setScript] = useState<Script | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [started, setStarted] = useState(false)
  const [state, setState] = useState<PlayState | null>(null)

  useEffect(() => {
    loadScript(slug).then(setScript).catch((e: Error) => setError(e.message))
  }, [slug])

  useEffect(() => {
    if (!script || !state) return
    const bgm = currentNode(script, state).bgm
    if (bgm) audioManager.playBgm(assetUrl(slug, bgm))
  }, [script, state, slug])

  useEffect(() => {
    if (!state) return
    if (state.status === 'ended') clearProgress(slug)
    else saveProgress(slug, state)
  }, [state, slug])

  if (error) return <div data-testid="play-page">{error}</div>
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
        <div data-testid="ending">{currentNode(script, state).ending?.title}</div>
      ) : (
        <SceneView
          script={script}
          state={state}
          slug={slug}
          onAdvance={() => setState(advance(script, state))}
          onChoose={(i) => setState(choose(script, state, i))}
        />
      )}
    </div>
  )
}
