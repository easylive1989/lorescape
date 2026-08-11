-- Cache for /narration results (the long-form story).
--
-- Every generation costs a grounded Gemini call. The first request for a
-- (place, language, hook) triple pays that cost; every later request is
-- served from this table, so the same place + same chosen angle always
-- replays the same story.
--
-- Written and read ONLY by the backend (service role). place_key is the
-- Wikidata Q-id for the modern request path, or "title:<wikipedia_title>"
-- for the deprecated title-only path. hook_id is the chosen hook's id, or
-- '' when the story was generated without one. Only successful
-- generations are cached (never insufficient_source / empty paragraphs),
-- so a place that failed once can succeed later.
CREATE TABLE IF NOT EXISTS public.narration_cache (
  place_key  TEXT NOT NULL,
  language   TEXT NOT NULL,
  hook_id    TEXT NOT NULL,
  narration  JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (place_key, language, hook_id)
);

-- Backend-only table: enable RLS with no policies so anon/authenticated
-- clients can do nothing; the service role bypasses RLS.
ALTER TABLE public.narration_cache ENABLE ROW LEVEL SECURITY;

-- Granted here, in the same migration as the CREATE — narration_hooks_cache
-- shipped without a grant and silently failed every read/write for a month
-- (see 20260705120001).
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.narration_cache TO service_role;
