import { assetUrl } from '../data/loadScript'
import type { CastMember, Character, Layout, PartLayout } from '../engine/schema'

const PART_CLASS: Record<keyof Character['parts'], string> = {
  leftArm: 'sprite__arm-left',
  rightArm: 'sprite__arm-right',
  torso: 'sprite__torso',
  head: 'sprite__head',
}

// 依 layout.json 的百分比座標定位緊裁部件圖；width 不設，交由瀏覽器依圖片
// 長寬比自算。
// 匯出供 BoneEditor（Task 14）沿用同一組百分比定位公式，避免兩處算式分岔。
export function partStyle(part: PartLayout) {
  return {
    left: `${part.cx * 100}%`,
    top: `${part.top * 100}%`,
    height: `${part.height * 100}%`,
    translate: '-50% 0',
  }
}

export function CharacterSprite({
  character,
  member,
  slug,
  layout,
}: {
  character: Character
  member: CastMember
  slug: string
  layout: Layout
}) {
  const charLayout = layout.characters[character.id]
  const className = [
    'sprite',
    `sprite--${member.position}`,
    member.talking ? 'is-talking' : '',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <div className={className} data-testid={`sprite-${character.id}`}>
      {(Object.keys(PART_CLASS) as (keyof Character['parts'])[]).map((key) => (
        <img
          key={key}
          className={`sprite__part ${PART_CLASS[key]}`}
          style={partStyle(charLayout[key])}
          src={assetUrl(slug, character.parts[key])}
          alt=""
        />
      ))}
    </div>
  )
}
