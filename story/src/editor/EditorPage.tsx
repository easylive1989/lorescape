import { useEffect, useState } from 'react'
import type { CatalogEntry } from '../engine/schema'
import '../styles/editor.css'
import { getJson } from './api'
import { NodeList } from './panels/NodeList'
import { useStory } from './useStory'

function EditorWorkspace({ slug }: { slug: string }) {
  const { script, error, updateScript } = useStory(slug)
  const [selectedNodeId, setSelectedNodeId] = useState<string | null>(null)

  const handleReorder = (ids: string[]) => {
    if (!script) return
    const byId = new Map(script.nodes.map((node) => [node.id, node]))
    updateScript({ ...script, nodes: ids.map((id) => byId.get(id)!) })
  }

  return (
    <div className="editor__workspace">
      {error && <p className="editor__error">錯誤：{error}</p>}
      {script ? (
        <>
          <aside className="editor__panel editor__panel--nodes">
            <NodeList
              script={script}
              selectedId={selectedNodeId}
              onSelect={setSelectedNodeId}
              onReorder={handleReorder}
            />
          </aside>
          <main className="editor__panel editor__panel--stage">
            <h2>{script.title}</h2>
          </main>
          <aside className="editor__panel editor__panel--inspector" />
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
