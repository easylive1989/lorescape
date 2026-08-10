import type { ReactNode } from 'react'
import { SceneView } from '../../components/SceneView'
import type { PlayState } from '../../engine/player'
import type { Script } from '../../engine/schema'

export function StagePreview(props: {
  script: Script
  slug: string
  nodeId: string
  paragraphIndex: number
  onParagraphChange(index: number): void
  children?: ReactNode
}) {
  const { script, slug, nodeId, paragraphIndex, onParagraphChange, children } = props
  const node = script.nodes.find((n) => n.id === nodeId) ?? script.nodes[0]
  const total = node.paragraphs.length
  const isLast = paragraphIndex >= total - 1
  const showChoices = isLast && !!node.choices

  const state: PlayState = {
    nodeId: node.id,
    paragraphIndex,
    status: showChoices ? 'choosing' : 'playing',
  }

  return (
    <div className="stage-frame">
      <SceneView
        script={script}
        state={state}
        slug={slug}
        onAdvance={() => {}}
        onChoose={() => {}}
      >
        {children}
      </SceneView>
      <div className="stage-frame__paragraph-nav">
        <button
          type="button"
          aria-label="上一段"
          disabled={paragraphIndex <= 0}
          onClick={() => onParagraphChange(paragraphIndex - 1)}
        >
          ‹
        </button>
        <span className="stage-frame__paragraph-count">
          第 {paragraphIndex + 1}/{total} 段
        </span>
        <button
          type="button"
          aria-label="下一段"
          disabled={isLast}
          onClick={() => onParagraphChange(paragraphIndex + 1)}
        >
          ›
        </button>
      </div>
    </div>
  )
}
