-- 沉浸式故事體驗 demo 的匿名回收表。
-- 前端（story.lorescape.app）以 anon key 直寫；insert-only，禁止讀取，
-- 分析一律走 service role（本地腳本）。
CREATE TABLE IF NOT EXISTS public.story_events (
  id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  story_slug TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN (
    'start', 'node_enter', 'choice_made', 'ending_reached', 'survey_submitted'
  )),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.story_surveys (
  id UUID NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  story_slug TEXT NOT NULL,
  answers JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.story_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_surveys ENABLE ROW LEVEL SECURITY;

CREATE POLICY story_events_anon_insert ON public.story_events
  FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY story_surveys_anon_insert ON public.story_surveys
  FOR INSERT TO anon WITH CHECK (true);

GRANT INSERT ON public.story_events TO anon;
GRANT INSERT ON public.story_surveys TO anon;
