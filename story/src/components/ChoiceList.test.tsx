import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { vi } from 'vitest'
import { ChoiceList } from './ChoiceList'
import type { Choice } from '../engine/schema'

const choices: Choice[] = [
  { text: '說實話：我來把一樣東西交給王后', to: 'n5a' },
  { text: '謊稱奉命前來清點王后的衣物', to: 'n5b' },
  { text: '什麼也不說，把書放在桌上就走', to: 'n5b' },
]

test('多個選項指向同一節點時仍全部渲染，且無 React key 警告', () => {
  const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
  render(<ChoiceList choices={choices} onChoose={() => {}} />)
  expect(screen.getAllByRole('button')).toHaveLength(3)
  expect(errorSpy).not.toHaveBeenCalled()
  errorSpy.mockRestore()
})

test('點選第二個選項時，以該選項的 index 呼叫 onChoose', async () => {
  const onChoose = vi.fn()
  render(<ChoiceList choices={choices} onChoose={onChoose} />)
  await userEvent.click(screen.getByText('謊稱奉命前來清點王后的衣物'))
  expect(onChoose).toHaveBeenCalledWith(1)
})
