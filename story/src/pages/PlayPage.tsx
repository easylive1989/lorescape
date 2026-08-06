import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { loadScript, assetUrl } from '../data/loadScript'
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

  if (error) return <div data-testid="play-page">{error}</div>
  if (!script) return <div data-testid="play-page">載入中…</div>
  if (!started)
    return (
      <div data-testid="play-page" className="intro">
        <h1>{script.title}</h1>
        <p>{script.intro}</p>
        <button
          onClick={() => {
            audioManager.unlock()
            setState(initState(script))
            setStarted(true)
          }}
        >
          開始體驗
        </button>
      </div>
    )
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
