import { getSupabaseClient } from "./supabase";
import { STORY_COLUMNS } from "./storyColumns.mjs";

export type StoryTeaser = {
  placeName: string;
  placeLocation: string;
  era: string;
  title: string;
  hook: string;
  paragraphs: string[];
  imageUrl: string | null;
  imageAttribution: string | null;
};

const COLUMNS = STORY_COLUMNS.join(", ");

export function localeToLanguage(locale: "zh" | "en"): "zh-TW" | "en" {
  return locale === "zh" ? "zh-TW" : "en";
}

export function isValidStoryDate(date: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return false;
  const [y, m, d] = date.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  return (
    dt.getUTCFullYear() === y &&
    dt.getUTCMonth() === m - 1 &&
    dt.getUTCDate() === d
  );
}

export function firstParagraphs(
  row: Record<string, unknown>,
  max = 2,
): string[] {
  const cards = row.card_paragraphs;
  if (Array.isArray(cards) && cards.length > 0) {
    return (cards as string[]).slice(0, max);
  }
  const story = typeof row.story === "string" ? row.story : "";
  return story
    .split(/\n+/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0)
    .slice(0, max);
}

export function rowToTeaser(row: Record<string, unknown>): StoryTeaser {
  const str = (v: unknown): string => (typeof v === "string" ? v : "");
  return {
    placeName: str(row.place_name),
    placeLocation: str(row.place_location),
    era: str(row.era),
    title: str(row.card_title) || str(row.place_name),
    hook: str(row.card_pull_quote) || str(row.card_title_sub),
    paragraphs: firstParagraphs(row, 2),
    imageUrl: typeof row.image_url === "string" ? row.image_url : null,
    imageAttribution:
      typeof row.image_attribution === "string"
        ? row.image_attribution
        : null,
  };
}

/// Fetches one daily story teaser by locale + date. Returns null when the
/// story does not exist or the read fails — the page renders a fallback.
export async function getDailyStory(
  locale: "zh" | "en",
  date: string,
): Promise<StoryTeaser | null> {
  try {
    const client = getSupabaseClient();
    const { data, error } = await client
      .from("daily_stories")
      .select(COLUMNS)
      .eq("language", localeToLanguage(locale))
      .eq("publish_date", date)
      .limit(1)
      .maybeSingle();
    if (error || !data) return null;
    // COLUMNS is built via string concatenation, so it widens to `string`
    // and postgrest-js's compile-time query parser can't infer a precise
    // row shape from it (no generated `Database` type is wired in either).
    // Cast through `unknown` to narrow to the row shape we actually use.
    return rowToTeaser(data as unknown as Record<string, unknown>);
  } catch {
    return null;
  }
}

export type StorySlug = { locale: "zh" | "en"; date: string };

/// Lists every published story as a {locale, date} slug for static
/// generation. Reads only `publish_date` + `language` from `daily_stories`
/// (anon; RLS limits to past dates). Throws on a query error so a broken
/// build fails loudly instead of silently shipping zero pages.
export async function getPublishedStorySlugs(): Promise<StorySlug[]> {
  const client = getSupabaseClient();
  const { data, error } = await client
    .from("daily_stories")
    .select("publish_date, language")
    .order("publish_date", { ascending: false });
  if (error) throw new Error(`Failed to list stories: ${error.message}`);
  return ((data ?? []) as Array<{ publish_date: string; language: string }>).map(
    (r) => ({
      locale: r.language.startsWith("zh") ? "zh" : "en",
      date: r.publish_date,
    }),
  );
}
