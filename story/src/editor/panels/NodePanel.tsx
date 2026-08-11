import { useState } from 'react'
import type { CastMember, Choice, Paragraph, Script, ScriptNode } from '../../engine/schema'
import { AssetPicker } from './AssetPicker'

const MAX_CHOICES = 3

// 站位同時是「有哪些位置」與「新增時按什麼順序挑」的來源。
const POSITIONS: { value: CastMember['position']; label: string }[] = [
  { value: 'left', label: '左' },
  { value: 'center', label: '中' },
  { value: 'right', label: '右' },
]

function moveItem<T>(list: T[], index: number, delta: number): T[] {
  const target = index + delta
  if (target < 0 || target >= list.length) return list
  const next = [...list]
  const [item] = next.splice(index, 1)
  next.splice(target, 0, item)
  return next
}

export function NodePanel(props: {
  script: Script
  node: ScriptNode
  slug: string
  onChange(next: ScriptNode): void
}) {
  const { script, node, slug, onChange } = props
  const [showBackgroundPicker, setShowBackgroundPicker] = useState(false)

  // 段落
  const updateParagraph = (index: number, patch: Partial<Paragraph>) =>
    onChange({
      ...node,
      paragraphs: node.paragraphs.map((p, i) => (i === index ? { ...p, ...patch } : p)),
    })
  const addParagraph = () => onChange({ ...node, paragraphs: [...node.paragraphs, { text: '' }] })
  const removeParagraph = (index: number) =>
    onChange({ ...node, paragraphs: node.paragraphs.filter((_, i) => i !== index) })
  const moveParagraph = (index: number, delta: number) =>
    onChange({ ...node, paragraphs: moveItem(node.paragraphs, index, delta) })
  const setSpeaker = (index: number, characterId: string) =>
    onChange({
      ...node,
      paragraphs: node.paragraphs.map((p, i) =>
        i !== index ? p : characterId ? { ...p, speaker: characterId } : { text: p.text }),
    })

  // next
  const updateNext = (value: string) => onChange({ ...node, next: value })

  // choices
  const updateChoice = (index: number, patch: Partial<Choice>) =>
    onChange({
      ...node,
      choices: (node.choices ?? []).map((c, i) => (i === index ? { ...c, ...patch } : c)),
    })
  const addChoice = () =>
    onChange({ ...node, choices: [...(node.choices ?? []), { text: '', to: script.startNode }] })
  const removeChoice = (index: number) =>
    onChange({ ...node, choices: (node.choices ?? []).filter((_, i) => i !== index) })

  // ending
  const updateEndingTitle = (title: string) => onChange({ ...node, ending: { title } })

  // cast
  const updateCast = (index: number, patch: Partial<CastMember>) => {
    const previous = (node.cast ?? [])[index]?.character
    const nextCharacter = patch.character
    onChange({
      ...node,
      cast: (node.cast ?? []).map((m, i) => (i === index ? { ...m, ...patch } : m)),
      paragraphs:
        nextCharacter && previous && nextCharacter !== previous
          ? node.paragraphs.map((p) =>
              p.speaker === previous ? { ...p, speaker: nextCharacter } : p)
          : node.paragraphs,
    })
  }
  // cast 的角色與站位都必須唯一（validateScript 會擋），所以面板只提供還沒被
  // 佔用的選項——否則使用者做得出重複狀態，卻要到存檔失敗才知道。
  const takenCharacters = new Set((node.cast ?? []).map((m) => m.character))
  const takenPositions = new Set((node.cast ?? []).map((m) => m.position))
  const freeCharacter = script.characters.find((c) => !takenCharacters.has(c.id))
  const freePosition = POSITIONS.find((p) => !takenPositions.has(p.value))
  const addCast = () => {
    if (!freeCharacter || !freePosition) return
    onChange({
      ...node,
      cast: [...(node.cast ?? []), { character: freeCharacter.id, position: freePosition.value }],
    })
  }
  const removeCast = (index: number) => {
    const removed = (node.cast ?? [])[index]?.character
    onChange({
      ...node,
      cast: (node.cast ?? []).filter((_, i) => i !== index),
      paragraphs: node.paragraphs.map((p) => (p.speaker === removed ? { text: p.text } : p)),
    })
  }

  return (
    <div className="node-panel">
      <section className="node-panel__section">
        <h3>段落</h3>
        {node.paragraphs.map((paragraph, index) => (
          <div className="node-panel__row" key={index}>
            <select
              className="node-panel__speaker"
              aria-label="說話者"
              value={paragraph.speaker ?? ''}
              onChange={(e) => setSpeaker(index, e.target.value)}
            >
              <option value="">旁白</option>
              {(node.cast ?? []).map((member) => (
                <option key={member.character} value={member.character}>
                  {script.characters.find((c) => c.id === member.character)?.name ?? member.character}
                </option>
              ))}
            </select>
            <textarea
              className="node-panel__textarea"
              value={paragraph.text}
              onChange={(e) => updateParagraph(index, { text: e.target.value })}
            />
            <div className="node-panel__row-buttons">
              <button
                type="button"
                aria-label="上移段落"
                disabled={index === 0}
                onClick={() => moveParagraph(index, -1)}
              >
                ↑
              </button>
              <button
                type="button"
                aria-label="下移段落"
                disabled={index === node.paragraphs.length - 1}
                onClick={() => moveParagraph(index, 1)}
              >
                ↓
              </button>
              <button type="button" onClick={() => removeParagraph(index)}>刪除段落</button>
            </div>
          </div>
        ))}
        <button type="button" onClick={addParagraph}>新增段落</button>
      </section>

      <section className="node-panel__section">
        <h3>結局</h3>
        {node.next !== undefined && (
          <label className="node-panel__field">
            下一節點
            <select value={node.next} onChange={(e) => updateNext(e.target.value)}>
              {script.nodes.map((n) => (
                <option key={n.id} value={n.id}>{n.id}</option>
              ))}
            </select>
          </label>
        )}
        {node.choices !== undefined && (
          <div className="node-panel__choices">
            {node.choices.map((choice, index) => (
              <div className="node-panel__row" key={index}>
                <input
                  type="text"
                  value={choice.text}
                  onChange={(e) => updateChoice(index, { text: e.target.value })}
                />
                <select
                  aria-label="選項指向"
                  value={choice.to}
                  onChange={(e) => updateChoice(index, { to: e.target.value })}
                >
                  {script.nodes.map((n) => (
                    <option key={n.id} value={n.id}>{n.id}</option>
                  ))}
                </select>
                <button type="button" onClick={() => removeChoice(index)}>刪除選項</button>
              </div>
            ))}
            <button type="button" disabled={node.choices.length >= MAX_CHOICES} onClick={addChoice}>
              新增選項
            </button>
          </div>
        )}
        {node.ending !== undefined && (
          <label className="node-panel__field">
            結局標題
            <input
              type="text"
              value={node.ending.title}
              onChange={(e) => updateEndingTitle(e.target.value)}
            />
          </label>
        )}
      </section>

      <section className="node-panel__section">
        <h3>角色</h3>
        {(node.cast ?? []).map((member, index) => (
          <div className="node-panel__row" key={index}>
            <select
              aria-label="角色"
              value={member.character}
              onChange={(e) => updateCast(index, { character: e.target.value })}
            >
              {script.characters
                .filter((c) => c.id === member.character || !takenCharacters.has(c.id))
                .map((c) => (
                  <option key={c.id} value={c.id}>{c.name}</option>
                ))}
            </select>
            <select
              aria-label="位置"
              value={member.position}
              onChange={(e) => updateCast(index, { position: e.target.value as CastMember['position'] })}
            >
              {POSITIONS
                .filter((p) => p.value === member.position || !takenPositions.has(p.value))
                .map((p) => (
                  <option key={p.value} value={p.value}>{p.label}</option>
                ))}
            </select>
            <button type="button" onClick={() => removeCast(index)}>刪除角色</button>
          </div>
        ))}
        <button type="button" disabled={!freeCharacter || !freePosition} onClick={addCast}>
          新增角色
        </button>
      </section>

      <section className="node-panel__section">
        <h3>背景</h3>
        <div className="node-panel__row">
          <span className="node-panel__background-name">{node.background}</span>
          <button type="button" onClick={() => setShowBackgroundPicker((v) => !v)}>
            {showBackgroundPicker ? '取消' : '更換'}
          </button>
        </div>
        {showBackgroundPicker && (
          <AssetPicker
            slug={slug}
            category="scenes"
            onPick={(relPath) => {
              onChange({ ...node, background: relPath })
              setShowBackgroundPicker(false)
            }}
          />
        )}
      </section>
    </div>
  )
}
