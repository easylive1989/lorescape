import { render, screen, fireEvent, within } from '@testing-library/react'
import { NodePanel } from './NodePanel'
import { demoScript } from '../../test/fixtures'
import type { Script, ScriptNode } from '../../engine/schema'

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
    paragraphs: [{ text: '新文字' }, ...node.paragraphs.slice(1)],
  }))
})

test('新增與刪除段落', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getByRole('button', { name: '新增段落' }))
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [...node.paragraphs, { text: '' }],
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

test('cast 編輯角色與位置', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)

  const position = screen.getAllByRole('combobox', { name: '位置' })[0]
  fireEvent.change(position, { target: { value: 'left' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [{ ...node.cast![0], position: 'left' }],
  }))
})

test('cast 刪除角色', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getAllByRole('button', { name: '刪除角色' })[0])
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({ cast: [] }))
})

// cast 的角色與站位都必須唯一（validateScript 會擋），所以面板不能讓使用者做出
// 重複的狀態。以下四個測試用兩個角色的劇本驗證這件事。
const twoCharScript: Script = {
  ...demoScript,
  characters: [
    ...demoScript.characters,
    { id: 'apprentice', name: '學徒', image: 'characters/apprentice/full.png' },
  ],
}

test('新增角色挑還沒上台的角色與還空著的站位', () => {
  const onChange = vi.fn()
  render(<NodePanel script={twoCharScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getByRole('button', { name: '新增角色' }))
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [{ character: 'master', position: 'center' }, { character: 'apprentice', position: 'left' }],
  }))
})

test('所有角色都上台時「新增角色」停用', () => {
  const fullNode: ScriptNode = {
    ...node,
    cast: [
      { character: 'master', position: 'center' },
      { character: 'apprentice', position: 'left' },
    ],
  }
  render(<NodePanel script={twoCharScript} node={fullNode} slug="demo" onChange={() => {}} />)
  expect(screen.getByRole('button', { name: '新增角色' })).toBeDisabled()
})

test('角色下拉不列出已被其他 cast 成員佔用的角色', () => {
  const fullNode: ScriptNode = {
    ...node,
    cast: [
      { character: 'master', position: 'center' },
      { character: 'apprentice', position: 'left' },
    ],
  }
  render(<NodePanel script={twoCharScript} node={fullNode} slug="demo" onChange={() => {}} />)
  const options = within(screen.getAllByRole('combobox', { name: '角色' })[0])
    .getAllByRole('option')
    .map((o) => o.textContent)
  expect(options).toEqual(['師傅'])
})

test('位置下拉不列出已被其他 cast 成員佔用的站位', () => {
  const fullNode: ScriptNode = {
    ...node,
    cast: [
      { character: 'master', position: 'center' },
      { character: 'apprentice', position: 'left' },
    ],
  }
  render(<NodePanel script={twoCharScript} node={fullNode} slug="demo" onChange={() => {}} />)
  const options = within(screen.getAllByRole('combobox', { name: '位置' })[0])
    .getAllByRole('option')
    .map((o) => o.textContent)
  expect(options).toEqual(['中', '右'])
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

test('說話者下拉列出旁白與台上角色，選取後寫入 speaker', () => {
  const onChange = vi.fn()
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  const speaker = screen.getAllByRole('combobox', { name: '說話者' })[0]
  expect(speaker).toHaveValue('')
  expect(screen.getAllByRole('option', { name: '旁白' })[0]).toBeInTheDocument()

  fireEvent.change(speaker, { target: { value: 'master' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [{ text: node.paragraphs[0].text, speaker: 'master' }, ...node.paragraphs.slice(1)],
  }))
})

test('說話者選回旁白時移除 speaker 欄位', () => {
  const onChange = vi.fn()
  const withSpeaker: ScriptNode = {
    ...node,
    paragraphs: [{ text: '第一段', speaker: 'master' }, ...node.paragraphs.slice(1)],
  }
  render(<NodePanel script={demoScript} node={withSpeaker} slug="demo" onChange={onChange} />)
  fireEvent.change(screen.getAllByRole('combobox', { name: '說話者' })[0], { target: { value: '' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    paragraphs: [{ text: '第一段' }, ...node.paragraphs.slice(1)],
  }))
  expect(onChange.mock.calls[0][0].paragraphs[0]).not.toHaveProperty('speaker')
})

test('刪除 cast 成員時清空指向他的段落 speaker', () => {
  const onChange = vi.fn()
  const withSpeaker: ScriptNode = {
    ...node,
    paragraphs: [{ text: '第一段', speaker: 'master' }, { text: '第二段' }],
  }
  render(<NodePanel script={demoScript} node={withSpeaker} slug="demo" onChange={onChange} />)
  fireEvent.click(screen.getAllByRole('button', { name: '刪除角色' })[0])
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [],
    paragraphs: [{ text: '第一段' }, { text: '第二段' }],
  }))
})

test('抽換 cast 角色時把段落 speaker 一併換過去', () => {
  const onChange = vi.fn()
  const twoCharScript: Script = {
    ...demoScript,
    characters: [
      ...demoScript.characters,
      { id: 'apprentice', name: '學徒', image: 'characters/apprentice/full.png' },
    ],
  }
  const withSpeaker: ScriptNode = {
    ...node,
    paragraphs: [{ text: '第一段', speaker: 'master' }, { text: '第二段' }],
  }
  render(<NodePanel script={twoCharScript} node={withSpeaker} slug="demo" onChange={onChange} />)
  fireEvent.change(screen.getAllByRole('combobox', { name: '角色' })[0], { target: { value: 'apprentice' } })
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
    cast: [{ character: 'apprentice', position: 'center' }],
    paragraphs: [{ text: '第一段', speaker: 'apprentice' }, { text: '第二段' }],
  }))
})

test('可以編輯選項要設定的 flag', async () => {
  const onChange = vi.fn()
  const node = demoScript.nodes[0]
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  const input = screen.getAllByLabelText('設定 flag')[0]
  fireEvent.change(input, { target: { value: 'sealed, warned' } })
  expect(onChange).toHaveBeenCalledWith(
    expect.objectContaining({
      choices: [
        expect.objectContaining({ set: ['sealed', 'warned'] }),
        expect.objectContaining({ text: '往右' }),
      ],
    }),
  )
})

test('清空 flag 輸入會移除 set 欄位', () => {
  const onChange = vi.fn()
  const node = structuredClone(demoScript.nodes[0])
  node.choices![0].set = ['sealed']
  render(<NodePanel script={demoScript} node={node} slug="demo" onChange={onChange} />)
  fireEvent.change(screen.getAllByLabelText('設定 flag')[0], { target: { value: '' } })
  expect(onChange.mock.calls[0][0].choices[0]).not.toHaveProperty('set')
})

test('段落的顯示條件下拉列出劇本內所有 flag 的正反兩版', () => {
  const script = structuredClone(demoScript)
  script.nodes[0].choices![0].set = ['sealed']
  render(
    <NodePanel script={script} node={script.nodes[0]} slug="demo" onChange={() => {}} />,
  )
  const select = screen.getAllByLabelText('顯示條件')[0]
  expect([...select.querySelectorAll('option')].map((o) => o.textContent))
    .toEqual(['無條件', 'sealed', '!sealed'])
})

test('選段落的顯示條件會寫進 when', () => {
  const onChange = vi.fn()
  const script = structuredClone(demoScript)
  script.nodes[0].choices![0].set = ['sealed']
  render(<NodePanel script={script} node={script.nodes[0]} slug="demo" onChange={onChange} />)
  fireEvent.change(screen.getAllByLabelText('顯示條件')[0], { target: { value: '!sealed' } })
  expect(onChange.mock.calls[0][0].paragraphs[0].when).toBe('!sealed')
})
