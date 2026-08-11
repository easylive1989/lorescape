import type { CastMember } from '../engine/schema'

export function SpeechBubble({ name, text, position }: {
  name: string; text: string; position: CastMember['position']
}) {
  return (
    <div className={`bubble bubble--${position}`} data-testid="speech-bubble">
      <span className="bubble__name">{name}</span>
      <p className="bubble__text">{text}</p>
    </div>
  )
}
