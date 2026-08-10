import { useEffect, useState } from 'react'
import type { CatalogEntry, Layout, Script, ScriptNode } from '../engine/schema'
import '../styles/editor.css'
import { getJson } from './api'
import { GraphView } from './graph/GraphView'
import { AssetPicker } from './panels/AssetPicker'
import { NodeList } from './panels/NodeList'
import { NodePanel } from './panels/NodePanel'
import { StoryPanel } from './panels/StoryPanel'
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

// 骨骼是每個角色的全域資料（layout.json 不分節點），跟編輯當下該角色在
// 哪個節點、站位左中右、是否同台有誰完全無關；只是 CharacterSprite 的定位
// 公式是相對「自己的 sprite 容器」算的，容器的螢幕位置與寬度會隨 cast 站位
// （sprite--left/right）與同台人數（雙人時寬度縮成 58%）變化，而 BoneEditor
// 目前固定用單人置中（sprite--center、72% 寬）的幾何疊圖。兩者容器對不上時
// 拖拉換算比例仍正確，但視覺上部件框會偏離真正的角色圖。
// 修法：骨骼模式時，只把「預覽節點的 cast」這份純展示用資料替換成
// 「僅編輯中角色、置中」，不落盤、不影響其他節點或其他角色的站位/同台設定，
// 讓真實 sprite 與 BoneEditor 的固定幾何天然對齊。
export function forceCenterCast(script: Script, nodeId: string, charId: string): Script {
  return {
    ...script,
    nodes: script.nodes.map((n) =>
      n.id === nodeId ? { ...n, cast: [{ character: charId, position: 'center' }] } : n,
    ),
  }
}

function EditorWorkspace({ slug }: { slug: string }) {
  const { script, layout, catalogEntry, error, updateScript, updateLayout, updateBlurb, updateCatalogEntry } = useStory(slug)
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null)
  // Task 16：左欄「節點／結構」分頁——結構分頁顯示 GraphView（React Flow 節點圖）
  const [leftTab, setLeftTab] = useState<'nodes' | 'graph'>('nodes')
  const [paragraphIndex, setParagraphIndex] = useState(0)
  const [boneMode, setBoneMode] = useState(false)
  const [boneCharIdOverride, setBoneCharIdOverride] = useState<string | null>(null)
  const [bonePart, setBonePart] = useState<PartKey>('torso')
  // Task 15：故事屬性面板的部件換檔——StoryPanel 只負責通知「要換哪個角色的哪個部件」，
  // 實際開哪個 AssetPicker、選完怎麼落盤都由 EditorPage 這層統籌（多角色×多部件共用一個 picker）
  const [partPickerTarget, setPartPickerTarget] = useState<{ charId: string; part: PartKey } | null>(null)

  const handleReorder = (ids: string[]) => {
    if (!script) return
    const byId = new Map(script.nodes.map((node) => [node.id, node]))
    updateScript({ ...script, nodes: ids.map((id) => byId.get(id)!) })
  }

  const handleSelectNode = (id: string) => {
    setSelectedNodeId(id)
    setParagraphIndex(0)
  }

  const handleShowStorySettings = () => {
    setSelectedNodeId(null)
    setPartPickerTarget(null)
  }

  const handleNodeChange = (next: ScriptNode) => {
    if (!script) return
    updateScript({ ...script, nodes: script.nodes.map((n) => (n.id === next.id ? next : n)) })
  }

  const handleScriptMeta = (patch: Partial<Pick<Script, 'title' | 'intro' | 'place'>>) => {
    if (!script) return
    updateScript({ ...script, ...patch })
    // index.json（首頁卡片讀的清單）也有同名的 title/place 欄位，兩邊都要改才不會顯示過時內容；
    // intro 只存在 script.json，不用同步
    const catalogPatch: Partial<Pick<CatalogEntry, 'title' | 'place'>> = {}
    if (patch.title !== undefined) catalogPatch.title = patch.title
    if (patch.place !== undefined) catalogPatch.place = patch.place
    if (Object.keys(catalogPatch).length > 0) updateCatalogEntry(catalogPatch)
  }

  const handlePartFile = (relPath: string) => {
    if (!script || !partPickerTarget) return
    const { charId, part } = partPickerTarget
    updateScript({
      ...script,
      characters: script.characters.map((c) =>
        c.id === charId ? { ...c, parts: { ...c.parts, [part]: relPath } } : c,
      ),
    })
    setPartPickerTarget(null)
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

  // 舞台預覽用的 script：骨骼模式時把預覽節點的 cast 換成單人置中，讓
  // BoneEditor 的固定幾何跟真實 sprite 對齊（見 forceCenterCast 註解）。
  const stageScript = script && effectiveBoneMode && boneCharId && previewNodeId
    ? forceCenterCast(script, previewNodeId, boneCharId)
    : script

  return (
    <div className="editor__workspace">
      {error && <p className="editor__error">錯誤：{error}</p>}
      {script ? (
        <>
          <aside className="editor__panel editor__panel--nodes">
            <button type="button" className="editor__story-settings" onClick={handleShowStorySettings}>
              故事設定
            </button>
            <div className="editor__left-tabs" role="tablist">
              <button
                type="button"
                role="tab"
                aria-selected={leftTab === 'nodes'}
                className={`editor__left-tab${leftTab === 'nodes' ? ' editor__left-tab--active' : ''}`}
                onClick={() => setLeftTab('nodes')}
              >
                節點
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={leftTab === 'graph'}
                className={`editor__left-tab${leftTab === 'graph' ? ' editor__left-tab--active' : ''}`}
                onClick={() => setLeftTab('graph')}
              >
                結構
              </button>
            </div>
            {leftTab === 'nodes' ? (
              <NodeList
                script={script}
                selectedId={selectedNodeId}
                onSelect={handleSelectNode}
                onReorder={handleReorder}
              />
            ) : (
              <GraphView script={script} onScriptChange={updateScript} />
            )}
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
            {previewNodeId && layout && stageScript ? (
              <StagePreview
                script={stageScript}
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
              <>
                <StoryPanel
                  script={script}
                  catalogEntry={catalogEntry}
                  characters={script.characters}
                  onScriptMeta={handleScriptMeta}
                  onBlurb={updateBlurb}
                  onPartFile={(charId, part) => setPartPickerTarget({ charId, part })}
                />
                {partPickerTarget && (
                  <AssetPicker
                    slug={slug}
                    category={`characters/${partPickerTarget.charId}`}
                    onPick={handlePartFile}
                  />
                )}
              </>
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
