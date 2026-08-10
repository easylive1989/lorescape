import { render, screen, fireEvent } from '@testing-library/react'
import { StoryPanel } from './StoryPanel'
import { demoScript } from '../../test/fixtures'
import type { CatalogEntry, Character } from '../../engine/schema'

const catalogEntry: CatalogEntry = {
  slug: demoScript.slug, title: demoScript.title, place: demoScript.place, blurb: '一段簡介',
}

const secondCharacter: Character = {
  id: 'apprentice', name: '徒弟', image: 'characters/apprentice/full.png',
}

function renderPanel(overrides: Partial<Parameters<typeof StoryPanel>[0]> = {}) {
  const onScriptMeta = vi.fn()
  const onBlurb = vi.fn()
  const onCharacterImage = vi.fn()
  render(
    <StoryPanel
      script={demoScript}
      catalogEntry={catalogEntry}
      characters={demoScript.characters}
      onScriptMeta={onScriptMeta}
      onBlurb={onBlurb}
      onCharacterImage={onCharacterImage}
      {...overrides}
    />,
  )
  return { onScriptMeta, onBlurb, onCharacterImage }
}

test('編輯標題呼叫 onScriptMeta({ title })', () => {
  const { onScriptMeta } = renderPanel()
  const input = screen.getByRole('textbox', { name: '標題' })
  fireEvent.change(input, { target: { value: '新標題' } })
  expect(onScriptMeta).toHaveBeenCalledWith({ title: '新標題' })
})

test('編輯地點呼叫 onScriptMeta({ place })', () => {
  const { onScriptMeta } = renderPanel()
  const input = screen.getByRole('textbox', { name: '地點' })
  fireEvent.change(input, { target: { value: '新地點' } })
  expect(onScriptMeta).toHaveBeenCalledWith({ place: '新地點' })
})

test('編輯 intro 呼叫 onScriptMeta({ intro })', () => {
  const { onScriptMeta } = renderPanel()
  const textarea = screen.getByRole('textbox', { name: 'intro' })
  fireEvent.change(textarea, { target: { value: '新的開場白' } })
  expect(onScriptMeta).toHaveBeenCalledWith({ intro: '新的開場白' })
})

test('編輯 blurb 呼叫 onBlurb', () => {
  const { onBlurb } = renderPanel()
  const textarea = screen.getByRole('textbox', { name: '簡介' })
  fireEvent.change(textarea, { target: { value: '新簡介' } })
  expect(onBlurb).toHaveBeenCalledWith('新簡介')
})

test('catalogEntry 為 null 時 blurb 欄位顯示空字串', () => {
  renderPanel({ catalogEntry: null })
  const textarea = screen.getByRole('textbox', { name: '簡介' }) as HTMLTextAreaElement
  expect(textarea.value).toBe('')
})

test('角色列表列出每個角色一顆換圖鈕，且點擊呼叫 onCharacterImage(charId)', () => {
  const { onCharacterImage } = renderPanel({
    characters: [demoScript.characters[0], secondCharacter],
  })
  const buttons = screen.getAllByRole('button', { name: /^更換角色圖／/ })
  expect(buttons).toHaveLength(2)

  fireEvent.click(screen.getByRole('button', { name: '更換角色圖／師傅' }))
  expect(onCharacterImage).toHaveBeenCalledWith('master')

  fireEvent.click(screen.getByRole('button', { name: '更換角色圖／徒弟' }))
  expect(onCharacterImage).toHaveBeenCalledWith('apprentice')
})

test('無角色時不顯示換圖鈕', () => {
  renderPanel({ characters: [] })
  expect(screen.queryAllByRole('button', { name: /^更換角色圖／/ })).toHaveLength(0)
})
