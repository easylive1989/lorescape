import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { loadCatalog } from '../data/catalog'
import type { CatalogEntry } from '../engine/schema'

export function HomePage() {
  const [entries, setEntries] = useState<CatalogEntry[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const load = async () => {
      try {
        setIsLoading(true)
        setError(null)
        const data = await loadCatalog()
        setEntries(data)
      } catch (err) {
        setError(err instanceof Error ? err.message : '載入失敗')
        setEntries([])
      } finally {
        setIsLoading(false)
      }
    }
    load()
  }, [])

  return (
    <div className="home">
      <header className="home-header">
        <h1>Lorescape 故事體驗</h1>
        <p className="home-subtitle">用第二人稱走進歷史現場</p>
      </header>
      {isLoading && <p>載入中...</p>}
      {error && <p>錯誤：{error}</p>}
      <ul className="story-list">
        {entries.map((story) => (
          <li key={story.slug}>
            <Link className="story-card" to={`/play/${story.slug}`}>
              <span className="story-card-place">{story.place}</span>
              <h2>{story.title}</h2>
              <p>{story.blurb}</p>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  )
}
