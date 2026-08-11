import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { SceneView } from './SceneView'
import { demoScript } from '../test/fixtures'
import type { Script } from '../engine/schema'
import type { PlayState } from '../engine/player'

// 第一段旁白、第二段由 master 說；用於驗證同一節點內兩種段落的切換。
const script: Script = structuredClone(demoScript)
script.nodes[0].paragraphs = [{ text: '第一段' }, { text: '第二段', speaker: 'master' }]

const playing = (paragraphIndex: number): PlayState =>
  ({ nodeId: 'n1', paragraphIndex, status: 'playing' })

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
  const state: PlayState = { nodeId: 'n1', paragraphIndex: 1, status: 'choosing' }
  render(<SceneView script={script} state={state} slug="demo" onAdvance={onAdvance} onChoose={() => {}} />)
  await userEvent.click(screen.getByTestId('scene'))
  expect(onAdvance).not.toHaveBeenCalled()
  expect(screen.getByRole('button', { name: '往左' })).toBeInTheDocument()
  expect(screen.queryByTestId('speech-bubble')).not.toBeInTheDocument()
})

test('台上人數決定 --sprite-h 與 --tail-x', () => {
  const { container, rerender } = render(
    <SceneView script={script} state={playing(0)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(container.querySelector<HTMLElement>('.scene')!.style.getPropertyValue('--sprite-h')).toBe('108cqw')
  expect(container.querySelector<HTMLElement>('.scene')!.style.getPropertyValue('--tail-x')).toBe('26cqw')

  const twoOnStage = structuredClone(script)
  twoOnStage.characters.push({ id: 'apprentice', name: '學徒', image: 'characters/apprentice/full.png' })
  twoOnStage.nodes[0].cast = [
    { character: 'master', position: 'left' },
    { character: 'apprentice', position: 'right' },
  ]
  rerender(<SceneView script={twoOnStage} state={playing(0)} slug="demo" onAdvance={() => {}} onChoose={() => {}} />)
  expect(container.querySelector<HTMLElement>('.scene')!.style.getPropertyValue('--sprite-h')).toBe('87cqw')
  expect(container.querySelector<HTMLElement>('.scene')!.style.getPropertyValue('--tail-x')).toBe('19cqw')
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
