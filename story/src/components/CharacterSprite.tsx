import { assetUrl } from '../data/loadScript'
import type { CastMember, Character } from '../engine/schema'

export function CharacterSprite({ character, member, slug, dimmed = false }: {
  character: Character; member: CastMember; slug: string; dimmed?: boolean
}) {
  const className = ['sprite', `sprite--${member.position}`, dimmed ? 'is-dimmed' : '']
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
