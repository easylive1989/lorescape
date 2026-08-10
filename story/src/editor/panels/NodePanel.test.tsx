import { render, screen, fireEvent } from '@testing-library/react'
import { NodePanel } from './NodePanel'
import { demoScript } from '../../test/fixtures'
import type { ScriptNode } from '../../engine/schema'

const node = demoScript.nodes[0] // choices 型態，含 cast
const endingNode = demoScript.nodes[1] // ending 型態

// choices 型態節點另建一個 next 型態變體供測試
const { choices: _choices, ...nodeWithoutChoices } = node
const nextNode: ScriptNode = { ...nodeWithoutChoices, next: 'end-a' }

test('編輯段落文字回傳新節點', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  const box = screen.getAllByRole('textbox')[0]
  fireEvent.change(box, { target: { value: '新文字' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: ['新文字', ...node.paragraphs.slice(1)],
  }))
})

test('新增與刪除段落', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getByRole('button', { name: '新增段落' }))
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [...node.paragraphs, ''],
  }))

  fireEvent.click(screen.getAllByRole('button', { name: '刪除段落' })[0])
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: node.paragraphs.slice(1),
  }))
})

test('段落可用↓與下一段落交換順序', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getAllByRole('button', { name: '下移段落' })[0])
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [node.paragraphs[1], node.paragraphs[0]],
  }))
})

test('第一段的上移鈕與最後一段的下移鈕停用', () => {
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={() => {}} />)
  const ups = screen.getAllByRole('button', { name: '上移段落' })
  const downs = screen.getAllByRole('button', { name: '下移段落' })
  expect(ups[0]).toBeDisabled()
  expect(downs[downs.length - 1]).toBeDisabled()
})

test('next 型態：下拉可改指向節點', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={nextNode} slug="demo" onChange={onChange} />)
  const select = screen.getByRole('combobox', { name: '下一節點' })
  fireEvent.change(select, { target: { value: 'end-b' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({ next: 'end-b' }))
})

test('choices 型態：編輯選項文字與指向', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  const texts = screen.getAllByRole('textbox').slice(node.paragraphs.length)
  fireEvent.change(texts[0], { target: { value: '換個說法' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    choices: [{ ...node.choices![0], text: '換個說法' }, node.choices![1]],
  }))

  const tos = screen.getAllByRole('combobox', { name: '選項指向' })
  fireEvent.change(tos[0], { target: { value: 'end-b' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    choices: [{ ...node.choices![0], to: 'end-b' }, node.choices![1]],
  }))
})

test('choices 型態：刪除選項', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getAllByRole('button', { name: '刪除選項' })[0])
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    choices: [node.choices![1]],
  }))
})

test('choices 型態：已達 3 項時「新增選項」停用', () => {
  const threeChoices = { ...node, choices: [...node.choices!, { text: '第三個', to: 'end-a' }] }
  render(<NodePanel script={demoScript} node={threeChoices} slug="demo" onChange={() => {}} />)
  expect(screen.getByRole('button', { name: '新增選項' })).toBeDisabled()
})

test('choices 型態：未達上限時可新增選項', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getByRole('button', { name: '新增選項' }))
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    choices: [...node.choices!, { text: '', to: demoScript.startNode }],
  }))
})

test('ending 型態：編輯標題', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={endingNode} slug="demo" onChange={onChange} />)
  const input = screen.getByRole('textbox', { name: '結局標題' })
  fireEvent.change(input, { target: { value: '新標題' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({ ending: { title: '新標題' } }))
})

test('cast 新增角色', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getByRole('button', { name: '新增角色' }))
  expect(onChange).toHaveBeenCalled()
})

test('cast 編輯角色、位置與說話中', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)

  const position = screen.getAllByRole('combobox', { name: '位置' })[0]
  fireEvent.change(position, { target: { value: 'left' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [{ ...node.cast![0], position: 'left' }],
  }))

  const talking = screen.getAllByRole('checkbox')[0]
  fireEvent.click(talking)
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [{ ...node.cast![0], talking: false }],
  }))
})

test('cast 刪除角色', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getAllByRole('button', { name: '刪除角色' })[0])
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({ cast: [] }))
})

test('無角色可加時「新增角色」停用', () => {
  const emptyCastScript = { ...demoScript, characters: [] }
  const bareNode = { ...node, cast: [] }
  render(<NodePanel script={emptyCastScript} node={bareNode} slug="demo" onChange={() => {}} />)
  expect(screen.getByRole('button', { name: '新增角色' })).toBeDisabled()
})

test('背景欄位顯示檔名', () => {
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={() => {}} />)
  expect(screen.getByText(node.background)).toBeInTheDocument()
})

test('點「更換」展開 AssetPicker，選圖後回傳更新過 background 的節點', async () => {
  vi.stubGlobal('fetch', vi.fn(async () =>
    new Response(JSON.stringify({ files: [{ path: 'scenes/new-bg.png', mtime: 1 }] }))))
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)

  fireEvent.click(screen.getByRole('button', { name: '更換' }))
  const thumb = await screen.findByRole('button', { name: '選擇 scenes/new-bg.png' })
  fireEvent.click(thumb)

  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({ background: 'scenes/new-bg.png' }))
})
