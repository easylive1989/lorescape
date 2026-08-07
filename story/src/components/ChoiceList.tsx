import type { Choice } from '../engine/schema'

export function ChoiceList({ choices, onChoose }: { choices: Choice[]; onChoose: (index: number) => void }) {
  return (
    <div className="choice-list">
      {choices.map((choice, index) => (
        <button key={`${choice.to}-${index}`} onClick={() => onChoose(index)}>
          {choice.text}
        </button>
      ))}
    </div>
  )
}
