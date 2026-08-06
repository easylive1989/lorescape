import type { ReactNode } from 'react'
import { assetUrl } from '../data/loadScript'
import { currentNode, type PlayState } from '../engine/player'
import type { Script } from '../engine/schema'
import { TextCard } from './TextCard'
import { ChoiceList } from './ChoiceList'

export function SceneView({
  script,
  state,
  slug,
  onAdvance,
  onChoose,
  children,
}: {
  script: Script
  state: PlayState
  slug: string
  onAdvance: () => void
  onChoose: (index: number) => void
  children?: ReactNode
}) {
  const node = currentNode(script, state)
  return (
    <div className="scene" style={{ backgroundImage: `url(${assetUrl(slug, node.background)})` }}>
      {children}
      {state.status === 'choosing' && node.choices ? (
        <ChoiceList choices={node.choices} onChoose={onChoose} />
      ) : (
        <TextCard text={node.paragraphs[state.paragraphIndex]} onTap={onAdvance} />
      )}
    </div>
  )
}
