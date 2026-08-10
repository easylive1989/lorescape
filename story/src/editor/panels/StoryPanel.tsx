import type { CatalogEntry, Character, Script } from '../../engine/schema'

export function StoryPanel(props: {
  script: Script
  catalogEntry: CatalogEntry | null
  characters: Character[]
  onScriptMeta(patch: Partial<Pick<Script, 'title' | 'intro' | 'place'>>): void
  onBlurb(blurb: string): void
  onCharacterImage(charId: string): void
}) {
  const { script, catalogEntry, characters, onScriptMeta, onBlurb, onCharacterImage } = props

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
        <h3>角色圖</h3>
        {characters.map((character) => (
          <div className="node-panel__row" key={character.id}>
            <span className="node-panel__background-name">{character.name}</span>
            <button type="button" onClick={() => onCharacterImage(character.id)}>
              更換角色圖／{character.name}
            </button>
          </div>
        ))}
      </section>
    </div>
  )
}
