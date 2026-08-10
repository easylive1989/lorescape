import { useCallback, useEffect, useState } from 'react'
import { getJson, postAsset } from '../api'
import { coverToPngBlob } from '../imageTools'

type AssetFile = { path: string; mtime: number }

function toPngFilename(name: string): string {
  const dot = name.lastIndexOf('.')
  const base = dot > 0 ? name.slice(0, dot) : name
  return `${base}.png`
}

export function AssetPicker(props: {
  slug: string
  category: 'scenes' | `characters/${string}`
  onPick(relPath: string): void
}) {
  const { slug, category, onPick } = props
  const [files, setFiles] = useState<AssetFile[]>([])
  const [error, setError] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)

  const loadFiles = useCallback(async () => {
    try {
      const data = await getJson<{ files: AssetFile[] }>(`/__editor/assets/${slug}`)
      setFiles(data.files.filter((f) => f.path.startsWith(`${category}/`)))
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    }
  }, [slug, category])

  useEffect(() => {
    void loadFiles()
  }, [loadFiles])

  const handleUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    setUploading(true)
    setError(null)
    try {
      const isScenes = category === 'scenes'
      const blob = isScenes ? await coverToPngBlob(file, 900, 1600) : file
      const filename = isScenes ? toPngFilename(file.name) : file.name
      const relPath = `${category}/${filename}`
      await postAsset(`/__editor/assets/${slug}/assets/${relPath}`, blob)
      await loadFiles()
      onPick(relPath)
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err))
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="asset-picker">
      {error && <p className="asset-picker__error">錯誤：{error}</p>}
      <div className="asset-picker__grid">
        {files.map((file) => (
          <button
            key={file.path}
            type="button"
            className="asset-picker__thumb"
            aria-label={`選擇 ${file.path}`}
            onClick={() => onPick(file.path)}
          >
            <img src={`/content/${slug}/assets/${file.path}?mtime=${file.mtime}`} alt={file.path} />
          </button>
        ))}
      </div>
      <label className="asset-picker__upload">
        上傳
        <input
          type="file"
          accept="image/png,image/jpeg"
          aria-label="上傳素材"
          disabled={uploading}
          onChange={(e) => void handleUpload(e)}
        />
      </label>
    </div>
  )
}
