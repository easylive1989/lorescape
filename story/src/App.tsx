import { lazy, Suspense } from 'react'
import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { HomePage } from './pages/HomePage'
import { PlayPage } from './pages/PlayPage'

// 編輯器僅供本機開發使用：lazy import + DEV 守衛，確保不進入 production bundle。
const EditorPage = lazy(() => import('./editor/EditorPage'))

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/play/:slug" element={<PlayPage />} />
      {import.meta.env.DEV && (
        <Route path="/editor" element={<Suspense fallback={null}><EditorPage /></Suspense>} />
      )}
    </Routes>
  )
}

export function App() {
  return (
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  )
}
