import { createClient, type SupabaseClient } from '@supabase/supabase-js'

export type StoryEventType = 'start' | 'node_enter' | 'choice_made' | 'ending_reached' | 'survey_submitted'

const SESSION_KEY = 'story-session-id'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

// 本地開發不設 env 也能玩劇本；此時 client 為 null，所有函式靜默 no-op。
const supabase: SupabaseClient | null =
  supabaseUrl && supabaseAnonKey ? createClient(supabaseUrl, supabaseAnonKey) : null

export function getSessionId(): string {
  const existing = sessionStorage.getItem(SESSION_KEY)
  if (existing) return existing
  const id = crypto.randomUUID()
  sessionStorage.setItem(SESSION_KEY, id)
  return id
}

export function trackEvent(slug: string, type: StoryEventType, payload: Record<string, unknown> = {}): void {
  if (!supabase) return
  supabase
    .from('story_events')
    .insert({
      session_id: getSessionId(),
      story_slug: slug,
      event_type: type,
      payload,
    })
    .then(
      ({ error }) => {
        if (error) console.warn('trackEvent 失敗：', error)
      },
      (err: unknown) => {
        console.warn('trackEvent 失敗：', err)
      },
    )
}

export async function submitSurvey(slug: string, answers: Record<string, unknown>): Promise<boolean> {
  if (!supabase) return false
  try {
    const { error } = await supabase.from('story_surveys').insert({
      session_id: getSessionId(),
      story_slug: slug,
      answers,
    })
    if (error) {
      console.warn('submitSurvey 失敗：', error)
      return false
    }
    trackEvent(slug, 'survey_submitted')
    return true
  } catch (err) {
    console.warn('submitSurvey 失敗：', err)
    return false
  }
}
