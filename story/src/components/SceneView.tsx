import type { CSSProperties, ReactNode } from 'react'
import { assetUrl } from '../data/loadScript'
import { currentNode, type PlayState } from '../engine/player'
import type { Script } from '../engine/schema'
import { CharacterSprite } from './CharacterSprite'
import { SpeechBubble } from './SpeechBubble'
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
  const characterById = new Map(script.characters.map((character) => [character.id, character]))
  const cast = node.cast ?? []
  const paragraph = node.paragraphs[state.paragraphIndex]
  // validateScript 保證 speaker 一定在 cast 內，這裡仍取 member 才拿得到站位；
  // 兩者都在才視為對白段，否則退回旁白框。
  const speakerMember = paragraph.speaker
    ? cast.find((member) => member.character === paragraph.speaker)
    : undefined
  const speaker = speakerMember ? characterById.get(speakerMember.character) : undefined

  return (
    <div
      className="scene"
      data-testid="scene"
      style={{
        backgroundImage: `url(${assetUrl(slug, node.background)})`,
        // sprite 高 = 寬 × 1.5，寬是 .scene 寬的 72%（單人）／58%（兩人以上），
        // 對齊 character.css 的 .sprite 寬度規則。
        '--sprite-h': cast.length >= 2 ? '87cqw' : '108cqw',
        // sprite 中心 = left(-10%) + 寬度/2，供泡泡的尖角對準說話者。
        '--tail-x': cast.length >= 2 ? '19cqw' : '26cqw',
      } as CSSProperties}
      // 對白段沒有下方框可點，推進的點擊區改由整個場景承接。choosing 時不吃
      // 點擊，否則點選項會連帶推進。
      onClick={() => { if (state.status === 'playing') onAdvance() }}
    >
      {cast.map((member) => {
        const character = characterById.get(member.character)
        return character ? (
          <CharacterSprite
            key={character.id}
            character={character}
            member={member}
            slug={slug}
            // 旁白段沒有說話者，誰都不壓暗。
            dimmed={speakerMember !== undefined && member.character !== speakerMember.character}
          />
        ) : null
      })}
      {children}
      {state.status === 'choosing' && node.choices ? (
        <ChoiceList choices={node.choices} onChoose={onChoose} />
      ) : speaker && speakerMember ? (
        <SpeechBubble name={speaker.name} text={paragraph.text} position={speakerMember.position} />
      ) : (
        <TextCard text={paragraph.text} />
      )}
    </div>
  )
}
