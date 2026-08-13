import type { ReactNode } from 'react'
import { assetUrl } from '../data/loadScript'
import { currentNode, visibleChoices, visibleParagraphs, type PlayState } from '../engine/player'
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
  // 越界的 paragraphIndex（編輯器刪段落後未同步、存檔進度指向已縮短的節點、或
  // flag 讓可見段落變少）沒有 error boundary 可接，必須退回最後一段。可見段落
  // 為 0 時（工作台預覽尚未經 validateScript 的劇本，作者把某節點全部段落都
  // 設上顯示條件）連「最後一段」都不存在，這時退回該節點的原始第一段——
  // validateScript 保證每個節點至少有一段沒有 when，退回原始第一段延續的正是
  // 這條規則的用意，但只有「經過驗證」的劇本才享有這個保證。
  const paragraphs = visibleParagraphs(node, state.flags)
  const paragraph = paragraphs[Math.min(state.paragraphIndex, paragraphs.length - 1)] ?? node.paragraphs[0]
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
      style={{ backgroundImage: `url(${assetUrl(slug, node.background)})` }}
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
        <ChoiceList choices={visibleChoices(node, state.flags)} onChoose={onChoose} />
      ) : speaker && speakerMember ? (
        <SpeechBubble name={speaker.name} text={paragraph.text} position={speakerMember.position} />
      ) : (
        <TextCard text={paragraph.text} />
      )}
    </div>
  )
}
