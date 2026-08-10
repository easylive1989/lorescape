import { useEffect, useState } from 'react'
import type { CatalogEntry, Layout, ScriptNode } from '../engine/schema'
import '../styles/editor.css'
import { getJson } from './api'
import { NodeList } from './panels/NodeList'
import { NodePanel } from './panels/NodePanel'
import { BoneEditor } from './stage/BoneEditor'
import { applyPartDelta, type PartKey } from './stage/boneMath'
import { StagePreview } from './stage/StagePreview'
import { useStory } from './useStory'

const BONE_PART_OPTIONS: { key: PartKey; label: string }[] = [
  { key: 'head', label: '頭' },
  { key: 'torso', label: '身體' },
  { key: 'leftArm', label: '左臂' },
  { key: 'rightArm', label: '右臂' },
]

// 骨骼模式的右欄數值面板：選中部件的 cx/top/height，number input 直接改絕對值
// （內部仍透過 applyPartDelta 換算成增量套用，維持 boneMath 的不可變更新）。
function BoneValuePanel(props: {
  layout: Layout
  charId: string
  part: PartKey
  onPartChange(part: PartKey): void
  onChange(next: Layout): void
}) {
  const { layout, charId, part, onPartChange, onChange } = props
  const current = layout.characters[charId][part]

  const updateField = (field: 'cx' | 'top' | 'height', value: number) => {
    if (Number.isNaN(value)) return
    onChange(applyPartDelta(layout, charId, part, { [field]: value - current[field] }))
  }

  return (
    <div className="bone-panel">
      <h3>骨骼數值</h3>
      <label className="node-panel__field">
        部件
        <select
          aria-label="骨骼部件"
          value={part}
          onChange={(e) => onPartChange(e.target.value as PartKey)}
        >
          {BONE_PART_OPTIONS.map((opt) => (
            <option key={opt.key} value={opt.key}>{opt.label}</option>
          ))}
        </select>
      </label>
      <label className="node-panel__field">
        cx
        <input
          type="number"
          step={0.005}
          value={current.cx}
          onChange={(e) => updateField('cx', e.target.valueAsNumber)}
        />
      </label>
      <label className="node-panel__field">
        top
        <input
          type="number"
          step={0.005}
          value={current.top}
          onChange={(e) => updateField('top', e.target.valueAsNumber)}
        />
      </label>
      <label className="node-panel__field">
        height
        <input
          type="number"
          step={0.005}
          value={current.height}
          onChange={(e) => updateField('height', e.target.valueAsNumber)}
        />
      </label>
    </div>
  )
}

function EditorWorkspace({ slug }: { slug: string }) {
  const { script, layout, error, updateScript, updateLayout } = useStory(slug)
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null)
  const [paragraphIndex, setParagraphIndex] = useState(0)
  const [boneMode, setBoneMode] = useState(false)
  const [boneCharIdOverride, setBoneCharIdOverride] = useState<string | null>(null)
  const [bonePart, setBonePart] = useState<PartKey>('torso')

  const handleReorder = (ids: string[]) => {
    if (!script) return
    const byId = new Map(script.nodes.map((node) => [node.id, node]))
    updateScript({ ...script, nodes: ids.map((id) => byId.get(id)!) })
  }

  const handleSelectNode = (id: string) => {
    setSelectedNodeId(id)
    setParagraphIndex(0)
  }

  const handleNodeChange = (next: ScriptNode) => {
    if (!script) return
    updateScript({ ...script, nodes: script.nodes.map((n) => (n.id === next.id ? next : n)) })
  }

  const previewNodeId = selectedNodeId ?? script?.startNode ?? null
  const selectedNode = script?.nodes.find((n) => n.id === selectedNodeId) ?? null
  const previewNode = script?.nodes.find((n) => n.id === previewNodeId) ?? null

  // 骨骼模式只針對目前預覽節點的 cast；無 cast 時停用。多角色時預設第一個，
  // 使用者可透過下方選單改選（override 對不到目前 cast 就退回預設）。
  const cast = previewNode?.cast ?? []
  const boneModeAvailable = cast.length > 0
  const effectiveBoneMode = boneMode && boneModeAvailable
  const boneCharId = boneCharIdOverride && cast.some((m) => m.character === boneCharIdOverride)
    ? boneCharIdOverride
    : (cast[0]?.character ?? null)

  return (
    <div className="editor__workspace">
      {error && <p className="editor__error">錯誤：{error}</p>}
      {script ? (
        <>
          <aside className="editor__panel editor__panel--nodes">
            <NodeList
              script={script}
              selectedId={selectedNodeId}
              onSelect={handleSelectNode}
              onReorder={handleReorder}
            />
          </aside>
          <main className="editor__panel editor__panel--stage">
            <div className="editor__bone-toolbar">
              <label className="editor__bone-toggle">
                <input
                  type="checkbox"
                  checked={effectiveBoneMode}
                  disabled={!boneModeAvailable}
                  onChange={(e) => setBoneMode(e.target.checked)}
                />
                骨骼模式
              </label>
              {effectiveBoneMode && cast.length > 1 && (
                <select
                  aria-label="骨骼編輯角色"
                  value={boneCharId ?? ''}
                  onChange={(e) => setBoneCharIdOverride(e.target.value)}
                >
                  {cast.map((member) => {
                    const character = script.characters.find((c) => c.id === member.character)
                    return (
                      <option key={member.character} value={member.character}>
                        {character?.name ?? member.character}
                      </option>
                    )
                  })}
                </select>
              )}
            </div>
            {previewNodeId && layout ? (
              <StagePreview
                script={script}
                layout={layout}
                slug={slug}
                nodeId={previewNodeId}
                paragraphIndex={paragraphIndex}
                onParagraphChange={setParagraphIndex}
              >
                {effectiveBoneMode && boneCharId && (
                  <BoneEditor
                    layout={layout}
                    charId={boneCharId}
                    onChange={updateLayout}
                    onSelectPart={setBonePart}
                  />
                )}
              </StagePreview>
            ) : (
              <h2>{script.title}</h2>
            )}
          </main>
          <aside className="editor__panel editor__panel--inspector">
            {effectiveBoneMode && layout && boneCharId ? (
              <BoneValuePanel
                layout={layout}
                charId={boneCharId}
                part={bonePart}
                onPartChange={setBonePart}
                onChange={updateLayout}
              />
            ) : selectedNode ? (
              <NodePanel script={script} node={selectedNode} slug={slug} onChange={handleNodeChange} />
            ) : (
              <p className="editor__hint">選擇節點以編輯</p>
            )}
          </aside>
        </>
      ) : (
        <p>載入中…</p>
      )}
    </div>
  )
}

export default function EditorPage() {
  const [stories, setStories] = useState<CatalogEntry[]>([])
  const [error, setError] = useState<string | null>(null)
  const [slug, setSlug] = useState<string | null>(null)

  useEffect(() => {
    getJson<{ stories: CatalogEntry[] }>('/__editor/content/index.json')
      .then((data) => setStories(data.stories))
      .catch((err) => setError(err instanceof Error ? err.message : String(err)))
  }, [])

  return (
    <div className="editor">
      <header className="editor__header">
        <h1>故事工作台</h1>
        <select
          aria-label="選擇故事"
          value={slug ?? ''}
          onChange={(e) => setSlug(e.target.value || null)}
        >
          <option value="">選擇故事…</option>
          {stories.map((story) => (
            <option key={story.slug} value={story.slug}>{story.title}</option>
          ))}
        </select>
      </header>
      {error && <p className="editor__error">錯誤：{error}</p>}
      {/* key={slug}：切換故事時強制整個工作區重掛，避免舊故事尚未送出的
          debounce PUT 沿用到新故事的路徑上 */}
      {slug && <EditorWorkspace key={slug} slug={slug} />}
    </div>
  )
}
