import { useEffect, useState } from 'react'
import type { CatalogEntry } from '../engine/schema'
import '../styles/editor.css'
import { getJson } from './api'
import { useStory } from './useStory'

function EditorWorkspace({ slug }: { slug: string }) {
  const { script, error } = useStory(slug)
  return (
    <div className="editor__workspace">
      {error && <p className="editor__error">錯誤：{error}</p>}
      {script ? <h2>{script.title}</h2> : <p>載入中…</p>}
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
      {slug && <EditorWorkspace slug={slug} />}
    </div>
  )
}
