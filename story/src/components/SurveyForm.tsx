import { useState, type FormEvent } from 'react'

export function SurveyForm({
  onSubmit,
}: {
  onSubmit: (answers: Record<string, unknown>) => Promise<boolean>
}) {
  const [immersion, setImmersion] = useState('')
  const [weeklyInterest, setWeeklyInterest] = useState('')
  const [memorable, setMemorable] = useState('')
  const [payIntent, setPayIntent] = useState('')
  const [igHandle, setIgHandle] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [failed, setFailed] = useState(false)

  const canSubmit = immersion !== '' && weeklyInterest !== '' && memorable.trim() !== ''

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!canSubmit || submitting) return
    setSubmitting(true)
    setFailed(false)
    const answers: Record<string, unknown> = {
      immersion: Number(immersion),
      weekly_interest: weeklyInterest,
      memorable,
    }
    if (payIntent) answers.pay_intent = payIntent
    if (igHandle) answers.ig_handle = igHandle
    const ok = await onSubmit(answers)
    setSubmitting(false)
    if (!ok) setFailed(true)
  }

  return (
    <form className="survey-form" onSubmit={handleSubmit}>
      <fieldset>
        <legend>這趟體驗的沉浸感如何？（1–5）</legend>
        {[1, 2, 3, 4, 5].map((n) => (
          <label key={n}>
            <input
              type="radio"
              name="immersion"
              value={n}
              checked={immersion === String(n)}
              onChange={() => setImmersion(String(n))}
            />
            {n}
          </label>
        ))}
      </fieldset>

      <fieldset>
        <legend>下週有新故事，你想繼續玩嗎？</legend>
        {[
          ['yes', '想玩'],
          ['maybe', '看情況'],
          ['no', '不想'],
        ].map(([value, label]) => (
          <label key={value}>
            <input
              type="radio"
              name="weekly_interest"
              value={value}
              checked={weeklyInterest === value}
              onChange={() => setWeeklyInterest(value)}
            />
            {label}
          </label>
        ))}
      </fieldset>

      <label>
        最印象深刻的片段是？
        <textarea value={memorable} onChange={(e) => setMemorable(e.target.value)} />
      </label>

      <fieldset>
        <legend>如果要付費才能繼續玩，你會願意嗎？（選答）</legend>
        {[
          ['yes', '願意'],
          ['depends', '看內容'],
          ['no', '不會'],
        ].map(([value, label]) => (
          <label key={value}>
            <input
              type="radio"
              name="pay_intent"
              value={value}
              checked={payIntent === value}
              onChange={() => setPayIntent(value)}
            />
            {label}
          </label>
        ))}
      </fieldset>

      <label>
        Instagram 帳號（選答，方便我們邀請你參加下一輪測試）
        <input type="text" value={igHandle} onChange={(e) => setIgHandle(e.target.value)} />
      </label>

      {failed && <p role="alert">送出失敗，再試一次</p>}

      <button type="submit" disabled={!canSubmit || submitting}>
        送出
      </button>
    </form>
  )
}
