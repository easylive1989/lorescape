import { render, screen } from '@testing-library/react'
import { SpeechBubble } from './SpeechBubble'

test('渲染角色名與對白文字', () => {
  render(<SpeechBubble name="師傅" text="八十一個。" position="center" />)
  const bubble = screen.getByTestId('speech-bubble')
  expect(bubble).toHaveTextContent('師傅')
  expect(bubble).toHaveTextContent('八十一個。')
})

test('依站位掛上對應的 class', () => {
  const { rerender } = render(<SpeechBubble name="師傅" text="嗯。" position="left" />)
  expect(screen.getByTestId('speech-bubble')).toHaveClass('bubble', 'bubble--left')
  rerender(<SpeechBubble name="師傅" text="嗯。" position="right" />)
  expect(screen.getByTestId('speech-bubble')).toHaveClass('bubble--right')
})
