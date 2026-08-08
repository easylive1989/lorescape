/// Columns of `daily_stories` that the story pages actually render.
///
/// Shared between the page code (`dailyStory.ts`) and the deploy-marker
/// script (`scripts/deploy-marker.mjs`), which hashes exactly these columns to
/// decide whether a scheduled rebuild has anything new to publish. Keeping one
/// list means a newly rendered column can never be left out of that hash — if
/// it were, an edit to it would silently never reach the live site.
///
/// Plain `.mjs` so the standalone Node script can import it without a build
/// step or TypeScript loader.
export const STORY_COLUMNS = [
  "publish_date",
  "language",
  "place_name",
  "place_location",
  "era",
  "story",
  "image_url",
  "image_attribution",
  "card_title",
  "card_title_sub",
  "card_paragraphs",
  "card_pull_quote",
  "card_pull_quote_attrib",
];
