import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, test, vi } from 'vitest'
import { SurveyForm } from './SurveyForm'

test('必答未填時送出鈕 disabled', () => {
  render(<SurveyForm onSubmit={vi.fn()} />)
  expect(screen.getByRole('button', { name: '送出' })).toBeDisabled()
})

test('填齊必答後 enabled，送出時 onSubmit 收到正確 answers 物件', async () => {
  const onSubmit = vi.fn(async () => true)
  render(<SurveyForm onSubmit={onSubmit} />)

  await userEvent.click(screen.getByRole('radio', { name: '4' }))
  await userEvent.click(screen.getByRole('radio', { name: '想玩' }))
  await userEvent.type(screen.getByRole('textbox', { name: /印象深刻/ }), '很有沉浸感')

  const submitButton = screen.getByRole('button', { name: '送出' })
  expect(submitButton).toBeEnabled()
  await userEvent.click(submitButton)

  expect(onSubmit).toHaveBeenCalledWith({
    immersion: 4,
    weekly_interest: 'yes',
    memorable: '很有沉浸感',
  })
})

test('選填 pay_intent 與 ig_handle 有填時一併帶入 answers', async () => {
  const onSubmit = vi.fn(async () => true)
  render(<SurveyForm onSubmit={onSubmit} />)

  await userEvent.click(screen.getByRole('radio', { name: '3' }))
  await userEvent.click(screen.getByRole('radio', { name: '看情況' }))
  await userEvent.type(screen.getByRole('textbox', { name: /印象深刻/ }), '普通')
  await userEvent.click(screen.getByRole('radio', { name: '看內容' }))
  await userEvent.type(screen.getByRole('textbox', { name: /Instagram/ }), '@tester')

  await userEvent.click(screen.getByRole('button', { name: '送出' }))

  expect(onSubmit).toHaveBeenCalledWith({
    immersion: 3,
    weekly_interest: 'maybe',
    memorable: '普通',
    pay_intent: 'depends',
    ig_handle: '@tester',
  })
})

test('onSubmit 回 false 顯示「送出失敗，再試一次」', async () => {
  const onSubmit = vi.fn(async () => false)
  render(<SurveyForm onSubmit={onSubmit} />)

  await userEvent.click(screen.getByRole('radio', { name: '3' }))
  await userEvent.click(screen.getByRole('radio', { name: '看情況' }))
  await userEvent.type(screen.getByRole('textbox', { name: /印象深刻/ }), '普通')
  await userEvent.click(screen.getByRole('button', { name: '送出' }))

  expect(await screen.findByText('送出失敗，再試一次')).toBeInTheDocument()
})
