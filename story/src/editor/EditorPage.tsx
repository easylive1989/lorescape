import { useEffect, useState } from 'react'
import type { CatalogEntry, Script, ScriptNode } from '../engine/schema'
import '../styles/editor.css'
import { getJson } from './api'
import { GraphView } from './graph/GraphView'
import { AssetPicker } from './panels/AssetPicker'
import { NodeList } from './panels/NodeList'
import { NodePanel } from './panels/NodePanel'
import { StoryPanel } from './panels/StoryPanel'
import { StagePreview } from './stage/StagePreview'
import { useStory } from './useStory'

const EXTERNAL_UPDATE_TOAST_MS = 4000

// SSE 收到外部更新（例如 Claude 或其他工具直接改 public/content 底下的檔案，
// 不經工作台 PUT）時的顯著提示：非 null 就顯示、EXTERNAL_UPDATE_TOAST_MS 後自動
// 消失。依賴 [file, seq] 而非只有 file——同一檔案連續被外部改動時 file 字串值
// 不變，但 seq 每次都遞增，確保計時器確實重置（見 useStory.ts 的 externalUpdateSeq 註解）。
function ExternalUpdateToast({ file, seq }: { file: string | null; seq: number }) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (!file) return
    setVisible(true)
    const timer = setTimeout(() => setVisible(false), EXTERNAL_UPDATE_TOAST_MS)
    return () => clearTimeout(timer)
  }, [file, seq])

  if (!visible || !file) return null
  return (
    <div className="editor__external-toast" role="status">
      內容已被外部更新：{file}
    </div>
  )
}

function EditorWorkspace({ slug }: { slug: string }) {
  const {
    script, catalogEntry, error, externalUpdate, externalUpdateSeq,
    updateScript, updateBlurb, updateCatalogEntry,
  } = useStory(slug)
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null)
  // Task 16：左欄「節點／結構」分頁——結構分頁顯示 GraphView（React Flow 節點圖）
  const [leftTab, setLeftTab] = useState<'nodes' | 'graph'>('nodes')
  const [paragraphIndex, setParagraphIndex] = useState(0)
  // 故事屬性面板的角色圖換檔——StoryPanel 只負責通知「要換哪個角色的圖」，
  // 實際開哪個 AssetPicker、選完怎麼落盤都由 EditorPage 這層統籌（多角色共用一個 picker）
  const [imagePickerCharId, setImagePickerCharId] = useState<string | null>(null)

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
    setImagePickerCharId(null)
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

  const handleCharacterImage = (relPath: string) => {
    if (!script || !imagePickerCharId) return
    updateScript({
      ...script,
      characters: script.characters.map((c) =>
        c.id === imagePickerCharId ? { ...c, image: relPath } : c,
      ),
    })
    setImagePickerCharId(null)
  }

  const previewNodeId = selectedNodeId ?? script?.startNode ?? null
  const selectedNode = script?.nodes.find((n) => n.id === selectedNodeId) ?? null
  const previewNode = script?.nodes.find((n) => n.id === previewNodeId) ?? null

  return (
    <div className="editor__workspace">
      {error && <p className="editor__error">錯誤：{error}</p>}
      <ExternalUpdateToast file={externalUpdate} seq={externalUpdateSeq} />
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
            {previewNodeId && previewNode ? (
              <StagePreview
                script={script}
                slug={slug}
                nodeId={previewNodeId}
                paragraphIndex={paragraphIndex}
                onParagraphChange={setParagraphIndex}
              />
            ) : (
              <h2>{script.title}</h2>
            )}
          </main>
          <aside className="editor__panel editor__panel--inspector">
            {selectedNode ? (
              <NodePanel script={script} node={selectedNode} slug={slug} onChange={handleNodeChange} />
            ) : (
              <>
                <StoryPanel
                  script={script}
                  catalogEntry={catalogEntry}
                  characters={script.characters}
                  onScriptMeta={handleScriptMeta}
                  onBlurb={updateBlurb}
                  onCharacterImage={(charId) => setImagePickerCharId(charId)}
                />
                {imagePickerCharId && (
                  <AssetPicker
                    slug={slug}
                    category={`characters/${imagePickerCharId}`}
                    onPick={handleCharacterImage}
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
