import type { ReactNode } from 'react'
import { assetUrl } from '../data/loadScript'
import { currentNode, type PlayState } from '../engine/player'
import type { Layout, Script } from '../engine/schema'
import { CharacterSprite } from './CharacterSprite'
import { TextCard } from './TextCard'
import { ChoiceList } from './ChoiceList'

export function SceneView({
  script,
  state,
  slug,
  layout,
  onAdvance,
  onChoose,
  children,
}: {
  script: Script
  state: PlayState
  slug: string
  layout: Layout
  onAdvance: () => void
  onChoose: (index: number) => void
  children?: ReactNode
}) {
  const node = currentNode(script, state)
  const characterById = new Map(script.characters.map((character) => [character.id, character]))
  return (
    <div className="scene" style={{ backgroundImage: `url(${assetUrl(slug, node.background)})` }}>
      {(node.cast ?? []).map((member) => {
        const character = characterById.get(member.character)
        return character ? (
          <CharacterSprite key={character.id} character={character} member={member} slug={slug} layout={layout} />
        ) : null
      })}
      {children}
      {state.status === 'choosing' && node.choices ? (
        <ChoiceList choices={node.choices} onChoose={onChoose} />
      ) : (
        <TextCard text={node.paragraphs[state.paragraphIndex]} onTap={onAdvance} />
      )}
    </div>
  )
}
