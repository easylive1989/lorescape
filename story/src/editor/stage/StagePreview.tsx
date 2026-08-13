import type { ReactNode } from 'react'
import { SceneView } from '../../components/SceneView'
import { visibleParagraphs, type PlayState } from '../../engine/player'
import { declaredFlags, type Script } from '../../engine/schema'

export function StagePreview(props: {
  script: Script
  slug: string
  nodeId: string
  paragraphIndex: number
  onParagraphChange(index: number): void
  flags: string[]
  onFlagsChange(next: string[]): void
  children?: ReactNode
}) {
  const { script, slug, nodeId, paragraphIndex, onParagraphChange, flags, onFlagsChange, children } = props
  const node = script.nodes.find((n) => n.id === nodeId) ?? script.nodes[0]
  // 段落總數要算可見的，否則切了 flag 之後「第 n/m 段」會對不上畫面。
  const total = visibleParagraphs(node, flags).length
  const isLast = paragraphIndex >= total - 1
  const showChoices = isLast && !!node.choices

  const state: PlayState = {
    nodeId: node.id,
    paragraphIndex,
    status: showChoices ? 'choosing' : 'playing',
    flags,
  }
  const allFlags = declaredFlags(script)

  const toggle = (flag: string) =>
    onFlagsChange(flags.includes(flag) ? flags.filter((f) => f !== flag) : [...flags, flag])

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
      {allFlags.length > 0 && (
        <div className="stage-frame__flags">
          {allFlags.map((flag) => (
            <label key={flag}>
              <input
                type="checkbox"
                aria-label={flag}
                checked={flags.includes(flag)}
                onChange={() => toggle(flag)}
              />
              {flag}
            </label>
          ))}
        </div>
      )}
    </div>
  )
}
