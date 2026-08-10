import type { CatalogEntry, Character, Script } from '../../engine/schema'

const PART_OPTIONS: { key: keyof Character['parts']; label: string }[] = [
  { key: 'head', label: '頭' },
  { key: 'torso', label: '身體' },
  { key: 'leftArm', label: '左臂' },
  { key: 'rightArm', label: '右臂' },
]

export function StoryPanel(props: {
  script: Script
  catalogEntry: CatalogEntry | null
  characters: Character[]
  onScriptMeta(patch: Partial<Pick<Script, 'title' | 'intro' | 'place'>>): void
  onBlurb(blurb: string): void
  onPartFile(charId: string, part: keyof Character['parts']): void
}) {
  const { script, catalogEntry, characters, onScriptMeta, onBlurb, onPartFile } = props

  return (
    <div className="node-panel">
      <section className="node-panel__section">
        <h3>故事設定</h3>
        <label className="node-panel__field">
          標題
          <input
            type="text"
            value={script.title}
            onChange={(e) => onScriptMeta({ title: e.target.value })}
          />
        </label>
        <label className="node-panel__field">
          地點
          <input
            type="text"
            value={script.place}
            onChange={(e) => onScriptMeta({ place: e.target.value })}
          />
        </label>
        <label className="node-panel__field">
          intro
          <textarea
            className="node-panel__textarea"
            value={script.intro}
            onChange={(e) => onScriptMeta({ intro: e.target.value })}
          />
        </label>
      </section>

      <section className="node-panel__section">
        <h3>簡介</h3>
        <label className="node-panel__field">
          簡介
          <textarea
            className="node-panel__textarea"
            value={catalogEntry?.blurb ?? ''}
            onChange={(e) => onBlurb(e.target.value)}
          />
        </label>
      </section>

      <section className="node-panel__section">
        <h3>角色部件</h3>
        {characters.map((character) => (
          <div className="node-panel__row" key={character.id}>
            <span className="node-panel__background-name">{character.name}</span>
            <div className="node-panel__row-buttons story-panel__parts">
              {PART_OPTIONS.map((opt) => (
                <button
                  key={opt.key}
                  type="button"
                  onClick={() => onPartFile(character.id, opt.key)}
                >
                  換檔／{character.name}／{opt.label}
                </button>
              ))}
            </div>
          </div>
        ))}
      </section>
    </div>
  )
}
