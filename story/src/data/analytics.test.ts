import { beforeEach, expect, test, vi } from 'vitest'

const insertMock = vi.fn(async (): Promise<{ error: Error | null }> => ({ error: null }))
const fromMock = vi.fn(() => ({ insert: insertMock }))
const createClientMock = vi.fn((..._args: unknown[]) => ({ from: fromMock }))

vi.mock('@supabase/supabase-js', () => ({
  createClient: (...args: unknown[]) => createClientMock(...args),
}))

beforeEach(() => {
  vi.resetModules()
  insertMock.mockClear()
  fromMock.mockClear()
  createClientMock.mockClear()
  insertMock.mockResolvedValue({ error: null })
  sessionStorage.clear()
  vi.stubEnv('VITE_SUPABASE_URL', 'http://x')
  vi.stubEnv('VITE_SUPABASE_ANON_KEY', 'anon-key')
})

test('getSessionId 兩次呼叫回傳相同值，清 sessionStorage 後不同', async () => {
  const { getSessionId } = await import('./analytics')
  const first = getSessionId()
  const second = getSessionId()
  expect(second).toBe(first)

  sessionStorage.clear()
  const third = getSessionId()
  expect(third).not.toBe(first)
})

test('trackEvent 呼叫 story_events insert 並帶 session_id/story_slug/event_type/payload', async () => {
  const { getSessionId, trackEvent } = await import('./analytics')
  const sessionId = getSessionId()
  trackEvent('demo', 'start', { foo: 'bar' })
  await Promise.resolve()
  await Promise.resolve()

  expect(fromMock).toHaveBeenCalledWith('story_events')
  expect(insertMock).toHaveBeenCalledWith({
    session_id: sessionId,
    story_slug: 'demo',
    event_type: 'start',
    payload: { foo: 'bar' },
  })
})

test('trackEvent 遇 insert reject 不 throw，只 console.warn', async () => {
  insertMock.mockRejectedValueOnce(new Error('network down'))
  const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})
  const { trackEvent } = await import('./analytics')

  expect(() => trackEvent('demo', 'start')).not.toThrow()
  await Promise.resolve()
  await Promise.resolve()

  expect(warnSpy).toHaveBeenCalled()
  warnSpy.mockRestore()
})

test('submitSurvey 成功時回傳 true 並追加 survey_submitted 事件', async () => {
  const { submitSurvey } = await import('./analytics')
  const answers = { rating: 5 }
  const ok = await submitSurvey('demo', answers)

  expect(ok).toBe(true)
  expect(fromMock).toHaveBeenCalledWith('story_surveys')
  expect(insertMock).toHaveBeenCalledWith(
    expect.objectContaining({ story_slug: 'demo', answers }),
  )
  expect(fromMock).toHaveBeenCalledWith('story_events')
  expect(insertMock).toHaveBeenCalledWith(
    expect.objectContaining({ story_slug: 'demo', event_type: 'survey_submitted' }),
  )
})

test('submitSurvey 失敗時回傳 false', async () => {
  insertMock.mockResolvedValueOnce({ error: new Error('insert failed') })
  const { submitSurvey } = await import('./analytics')
  const ok = await submitSurvey('demo', { rating: 1 })
  expect(ok).toBe(false)
})

test('env 缺值時所有函式靜默 no-op（createClient 未被呼叫）', async () => {
  vi.stubEnv('VITE_SUPABASE_URL', '')
  vi.stubEnv('VITE_SUPABASE_ANON_KEY', '')
  const { getSessionId, trackEvent, submitSurvey } = await import('./analytics')

  const sessionId = getSessionId()
  expect(typeof sessionId).toBe('string')
  trackEvent('demo', 'start')
  const ok = await submitSurvey('demo', { rating: 1 })

  expect(ok).toBe(false)
  expect(createClientMock).not.toHaveBeenCalled()
  expect(fromMock).not.toHaveBeenCalled()
})
