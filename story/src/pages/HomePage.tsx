import { Link } from 'react-router-dom'
import { catalog } from '../data/catalog'

export function HomePage() {
  return (
    <div className="home">
      <header className="home-header">
        <h1>Lorescape 故事體驗</h1>
        <p className="home-subtitle">用第二人稱走進歷史現場</p>
      </header>
      <ul className="story-list">
        {catalog.map((story) => (
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
