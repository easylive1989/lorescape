import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { SceneView } from './SceneView'
import { demoScript, flagScript } from '../test/fixtures'
import type { Script } from '../engine/schema'
import type { PlayState } from '../engine/player'

// 第一段旁白、第二段由 master 說；用於驗證同一節點內兩種段落的切換。
const script: Script = structuredClone(demoScript)
script.nodes[0].paragraphs = [{ text: '第一段' }, { text: '第二段', speaker: 'master' }]

const playing = (paragraphIndex: number): PlayState =>
  ({ nodeId: 'n1', paragraphIndex, status: 'playing', flags: [] })

test('旁白段渲染下方旁白框，不出現泡泡', () => {
  render(<SceneView script={script} state={playing(0)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(screen.getByTestId('text-card')).toHaveTextContent('第一段')
  expect(screen.queryByTestId('speech-bubble')).not.toBeInTheDocument()
})

test('對白段渲染角色頭上的泡泡，不出現旁白框', () => {
  render(<SceneView script={script} state={playing(1)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  const bubble = screen.getByTestId('speech-bubble')
  expect(bubble).toHaveTextContent('第二段')
  expect(bubble).toHaveTextContent('師傅')
  expect(bubble).toHaveClass('bubble--center')
  expect(screen.queryByTestId('text-card')).not.toBeInTheDocument()
})

test('playing 時點 scene 推進', async () => {
  const onAdvance = vi.fn()
  render(<SceneView script={script} state={playing(0)} slug="demo" onAdvance={onAdvance} onChoose={() => {}} />)
  await userEvent.click(screen.getByTestId('scene'))
  expect(onAdvance).toHaveBeenCalledTimes(1)
})

test('choosing 時點 scene 不推進，且渲染選項', async () => {
  const onAdvance = vi.fn()
  const state: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing', flags: [] }
  render(<SceneView script={script} state={state} slug="demo" onAdvance={onAdvance} onChoose={() => {}} />)
  await userEvent.click(screen.getByTestId('scene'))
  expect(onAdvance).not.toHaveBeenCalled()
  expect(screen.getByRole('button', { name: '往左' })).toBeInTheDocument()
  expect(screen.queryByTestId('speech-bubble')).not.toBeInTheDocument()
})

test('paragraphIndex 越界時退回最後一段，不拋錯', () => {
  render(<SceneView script={script} state={playing(99)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  const bubble = screen.getByTestId('speech-bubble')
  expect(bubble).toHaveTextContent('第二段')
})

test('對白段只壓暗非說話者，旁白段誰都不壓暗', () => {
  const twoOnStage = structuredClone(script)
  twoOnStage.characters.push({ id: 'apprentice', name: '學徒', image: 'characters/apprentice/full.png' })
  twoOnStage.nodes[0].cast = [
    { character: 'master', position: 'left' },
    { character: 'apprentice', position: 'right' },
  ]

  const { rerender } = render(
    <SceneView script={twoOnStage} state={playing(1)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-dimmed')
  expect(screen.getByTestId('sprite-apprentice')).toHaveClass('is-dimmed')

  rerender(
    <SceneView script={twoOnStage} state={playing(0)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(screen.getByTestId('sprite-master')).not.toHaveClass('is-dimmed')
  expect(screen.getByTestId('sprite-apprentice')).not.toHaveClass('is-dimmed')
})

test('條件段落依 flags 顯示', () => {
  render(
    <SceneView
      script={flagScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 1, status: 'playing', flags: ['sealed'] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.getByTestId('text-card')).toHaveTextContent('封了爐才有的一段')
})

test('條件不成立時該段不出現，索引落在另一段', () => {
  render(
    <SceneView
      script={flagScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 1, status: 'playing', flags: [] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.getByTestId('text-card')).toHaveTextContent('沒封才有的一段')
})

test('可見段落為 0 時退回節點原始第一段，不拋錯', () => {
  // mid 節點的段落全部改成帶 when 且傳入的 flags 讓它們全部不成立——這是還沒經過
  // validateScript 的狀態（該規則本會擋下這種節點），刻意不呼叫 validateScript，
  // 直接用物件字面值組出這個劇本，模擬工作台預覽會踩到的未驗證狀態。
  const noVisibleScript: Script = {
    ...flagScript,
    nodes: flagScript.nodes.map((n) =>
      n.id === 'mid' ? { ...n, paragraphs: [{ text: '只有這段', when: 'never-set' }] } : n),
  }
  render(
    <SceneView
      script={noVisibleScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 0, status: 'playing', flags: [] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.getByTestId('text-card')).toHaveTextContent('只有這段')
})

test('條件選項依 flags 出現或消失', () => {
  const { rerender } = render(
    <SceneView
      script={flagScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 2, status: 'choosing', flags: [] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.getByRole('button', { name: '去港口' })).toBeInTheDocument()
  rerender(
    <SceneView
      script={flagScript} slug="flags"
      state={{ nodeId: 'mid', paragraphIndex: 1, status: 'choosing', flags: ['sealed'] }}
      onAdvance={() => {}} onChoose={() => {}}
    />,
  )
  expect(screen.queryByRole('button', { name: '去港口' })).not.toBeInTheDocument()
  expect(screen.getByRole('button', { name: '走城門' })).toBeInTheDocument()
})
