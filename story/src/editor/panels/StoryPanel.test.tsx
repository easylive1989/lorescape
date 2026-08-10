import { render, screen, fireEvent } from '@testing-library/react'
import { StoryPanel } from './StoryPanel'
import { demoScript } from '../../test/fixtures'
import type { CatalogEntry, Character } from '../../engine/schema'

const catalogEntry: CatalogEntry = {
  slug: demoScript.slug, title: demoScript.title, place: demoScript.place, blurb: '一段簡介',
}

const secondCharacter: Character = {
  id: 'apprentice', name: '徒弟',
  parts: {
    head: 'characters/apprentice/head.png', torso: 'characters/apprentice/torso.png',
    leftArm: 'characters/apprentice/left-arm.png', rightArm: 'characters/apprentice/right-arm.png',
  },
}

function renderPanel(overrides: Partial<Parameters<typeof StoryPanel>[0]> = {}) {
  const onScriptMeta = vi.fn()
  const onBlurb = vi.fn()
  const onPartFile = vi.fn()
  render(
    <StoryPanel
      script={demoScript}
      catalogEntry={catalogEntry}
      characters={demoScript.characters}
      onScriptMeta={onScriptMeta}
      onBlurb={onBlurb}
      onPartFile={onPartFile}
      {...overrides}
    />,
  )
  return { onScriptMeta, onBlurb, onPartFile }
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

test('部件列表列出 4 部件 × 角色數的換檔鈕，且點擊呼叫 onPartFile(charId, part)', () => {
  const { onPartFile } = renderPanel({
    characters: [demoScript.characters[0], secondCharacter],
  })
  const buttons = screen.getAllByRole('button', { name: /^換檔／/ })
  expect(buttons).toHaveLength(8) // 4 部件 × 2 角色

  fireEvent.click(screen.getByRole('button', { name: '換檔／師傅／頭' }))
  expect(onPartFile).toHaveBeenCalledWith('master', 'head')

  fireEvent.click(screen.getByRole('button', { name: '換檔／徒弟／右臂' }))
  expect(onPartFile).toHaveBeenCalledWith('apprentice', 'rightArm')
})

test('無角色時不顯示換檔鈕', () => {
  renderPanel({ characters: [] })
  expect(screen.queryAllByRole('button', { name: /^換檔／/ })).toHaveLength(0)
})
