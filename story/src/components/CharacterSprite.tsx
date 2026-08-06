import { assetUrl } from '../data/loadScript'
import type { CastMember, Character } from '../engine/schema'

export function CharacterSprite({
  character,
  member,
  slug,
}: {
  character: Character
  member: CastMember
  slug: string
}) {
  const className = [
    'sprite',
    `sprite--${member.position}`,
    member.talking ? 'is-talking' : '',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <div className={className} data-testid={`sprite-${character.id}`}>
      <img className="sprite__part sprite__arm-left" src={assetUrl(slug, character.parts.leftArm)} alt="" />
      <img className="sprite__part sprite__arm-right" src={assetUrl(slug, character.parts.rightArm)} alt="" />
      <img className="sprite__part sprite__torso" src={assetUrl(slug, character.parts.torso)} alt="" />
      <img className="sprite__part sprite__head" src={assetUrl(slug, character.parts.head)} alt="" />
    </div>
  )
}
