import { assetUrl } from '../data/loadScript'
import type { CastMember, Character } from '../engine/schema'

export function CharacterSprite({ character, member, slug }: {
  character: Character; member: CastMember; slug: string
}) {
  const className = ['sprite', `sprite--${member.position}`, member.talking ? 'is-talking' : '']
    .filter(Boolean).join(' ')
  return (
    <div className={className} data-testid={`sprite-${character.id}`}>
      <img
        className="sprite__image"
        src={assetUrl(slug, character.image)}
        alt=""
      />
    </div>
  )
}
