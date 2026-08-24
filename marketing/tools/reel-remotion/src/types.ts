export type BeatLayout = "cover" | "beat" | "bright" | "ending";

export interface Beat {
  id: string;
  layout: BeatLayout;
  photo: string;
  /** CSS object-position, e.g. "50% 40%" — where the frame focuses. */
  focus: string;
  /** Short kicker / aspect label shown above the narration. */
  kicker: string;
  title: string;
  subtitle?: string;
  /** darker = push a heavier scrim for readability on bright photos. */
  overlay?: "darker";
  /** Narration lines; an empty string marks a stanza break. */
  lines: string[];
  /** Substrings inside `lines` to emphasise. Optional: a beat that emphasises
   * nothing (the ending beat, typically) may omit the key entirely, and
   * prepare_story.mjs carries carousel beats over without one. */
  highlights?: string[];
  /** Spoken (for-the-ear) narration for this beat. Fuller than the on-screen
   * `lines`; the voiceover pipeline (reel_voiceover.py) reads it for TTS. */
  narration?: string;
  /** Optional explicit on-screen duration (frames); overrides the text-derived
   * default. Set by the voiceover pipeline so each beat holds long enough for
   * its spoken narration. */
  durationFrames?: number;
}

export interface Story {
  date: string;
  place: string;
  placeZh: string;
  titleZh: string;
  titleEn: string;
  region: string;
  credits: string;
  beats: Beat[];
}
