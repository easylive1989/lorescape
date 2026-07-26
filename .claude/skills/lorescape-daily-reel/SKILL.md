---
name: lorescape-daily-reel
description: Use when producing the daily-story reel/video for a Lorescape place — the place-photo, aspect-switching, narration-text style rendered locally (NOT Google Flow). Triggers on 「產每日故事影片」「做 reel / 短影片」「不要用 flow 做影片」「把今天的故事做成影片」, and lorescape-manual-daily-story's post-publish video step. Covers preparing the story, condensing narration, rendering, and muxing BGM.
---

# Lorescape Daily-Story Reel (Remotion)

## Overview

Produce the daily-story reel **locally with Remotion** — no Google Flow.
The video focuses on the real place photos, switches between the story's
aspects (beats), and overlays the guide narration as animated text. This is
the default video method for daily stories (replaces the Flow reel, which
felt stiff and generic).

Engine: `marketing/tools/reel-remotion/` (a parametrised Remotion project).
Content comes from the day's carousel `slides.json` + Unsplash photos, so the
reel tells the same story the carousel does.

## When to Use

- The daily-story post-publish video step (lorescape-manual-daily-story Step 9)
- Any "make a reel / short video from today's story", explicitly not Flow
- Re-rendering a day's reel after tweaking text, fonts, or BGM

## The Cinematic style (the locked look)

Keep these when editing — this IS the approved style:

- **9:16, 30fps, 目標 20–30s, no voiceover baked in** (narration added later in post)
- Full-bleed photo with a slow continuous **Ken Burns** push (never static)
- **Cross-dissolve** between beats; each beat = one aspect of the place
- Narration reveals **line-by-line** with a spring (weight, not a linear ramp)
- Type: **Songti TC bold serif** for title + lines, **Heiti TC** kicker;
  gold `#f4c869` highlights on key phrases
- Small **white Lorescape lockup** bottom-right (line-art, trail visible)
- **Condensed** narration so a later voiceover keeps pace
- A quiet **BGM bed** muxed in (fade in/out, loudness-normalised)

Three alternate styles exist for one-offs (`--style Editorial|Collage|Focus`);
Cinematic is the daily default.

## Pipeline

```bash
cd marketing/tools/reel-remotion

# 1. Scaffold story.json from the day's carousel + copy its photos
node scripts/prepare_story.mjs <YYYY-MM-DD>

# 2. Claude condenses story.json's narration (the judgment step — see below)

# 2b. STOP — 把文字稿貼給使用者審核，取得明確同意後才往下走（見 Step 2b）

# 3a. 音樂版（無語音）：Render + mux BGM -> daily_video/<date>/cinematic.mp4
scripts/build_video.sh <YYYY-MM-DD>              # music-forward (-20 LUFS)

# 3b. 語音版（zh-TW 旁白，逐 beat 同步）-> daily_video/<date>/final.mp4
#     先在 story.json 每拍填 `narration`（口說版，見 Step 2），再：
cd ../../../scripts && uv run python -m reel_voiceover <YYYY-MM-DD>
#     旁白一律用 Gemini TTS（預設）；不要用離線 say。
#     改一句只重唸一句（逐拍快取）；--force-tts 全部重唸
```

`build_video.sh` subsets the fonts (required after any text change), renders,
then muxes the newest track in `marketing/sound/`. Preview the mp4, iterate,
then hand off to upload (lorescape-manual-daily-story Step 11).

### Step 2 — condensing narration（目標 20–30 秒，do NOT skip）

`prepare_story.mjs` 會把 carousel 全 9 拍的完整 lines 搬進來——那對 reel
太長（實測會到 60–100 秒，壓低完播與觸及）。目標是**成片 20–30 秒**。
編輯 `src/data/story.json`：

- **挑拍（硬規則）**：**3–4 拍 ＋ ending**，cover 算第一拍。其餘整拍刪掉。
  低於 3 拍講不完故事、超過 4 拍太長，都不行。（carousel 仍是 9 拍，reel
  用子集不影響圖組。）
- **敘事骨架**：這 3–4 拍儘量成一條 **起 → 承 → 轉**：
  - **起（cover）**＝ hook，一句話丟出反轉或懸念
  - **承**（1–2 拍）＝ 衝突或代價升高，每拍都要接得上一拍（用「而」「同
    一時間」「隔天」這類接續詞明示因果，別讓觀眾自己補）
  - **轉**（最後一拍）＝ 反轉／代價／揭曉，且必須**扣回 cover 的畫面**
    （直接重述 cover 用過的名詞，別用「那個畫面」這種需要觀眾回想的指涉）
  - 反例：中間拍與 cover 各講各的、最後一拍的「但」找不到反駁對象——這
    會讓整支片讀起來散掉。
- **ending 收在品牌句型**：最後一拍一律以「**旅行，**」起句，用
  「旅行，不只 A，／也是 B。」這個構句——**固定的只有這個句型**，A / B
  每天依當篇故事微調，讓收尾呼應本篇主題，不要每天照抄同一句。
  - 通用款：「旅行，不只走進一個地方，／也是走進一個故事。」
  - 傳說／查無實據的故事：「旅行，不只走進一個地方，／也是走近一個真相。」
  - 遺跡／消失之謎：「旅行，不只走進一個地方，／也是走進一段沒說完的
    時間。」
  - B 半句要接得上「轉」那拍的主題詞（今天的主題詞是「真實」，B 就往
    真相／真偽收）。
  - 不要拿劇情句當結語——劇情的反轉屬於「轉」那一拍，ending 只做品牌收尾。
- **零秒 hook（cover）**：cover 的 `lines[0]` 寫成一句話講完反轉/懸念的
  **拋問句或反轉句**（例：「全世界最著名的建築，其實是一座墳墓。」）。
  render 會讓 `lines[0]` 第一幀就以最大字級出現，地區/地名自動降為小字，
  所以 hook 句要能獨立抓住人、別依賴標題。cover `lines` 儘量只留 hook 句
  ＋最多一句補充。
- **每拍精煉**：非 cover 拍收成 **1–2 句短 clause**（口說唸完約 3–4 秒），
  不要複句。
- 每個 `highlights` 必須是某句 `lines` 的**精確子字串**，否則不會highlight。
- `narration`（口說旁白）每拍填一句，比畫面 `lines` 完整一點即可；
  `reel_voiceover` 會逐拍 TTS、用實測長度回寫 `durationFrames`。因此
  **寫短旁白＝片子自然短**，不需另設上限。
- 算下來若仍超過 ~35 秒（beats × 各拍旁白秒數相加），先縮句；縮不動才砍
  到 3 拍——**不可少於 3 拍**。
- ending 拍會自動保留 ≥7 秒讓片尾下載 CTA 讀得完（`ENDING_MIN_FRAMES`），
  ending 旁白就是那句品牌收尾，不用硬撐長度。

### Step 2b — 文字稿必須先過審（GATE，不可略過）

**在跑任何 render / TTS 指令之前**，把完整文字稿貼給使用者審核。TTS 是
免費層每把 key 每天 10 次的稀缺資源，先渲染再改＝白燒配額。

貼審核時逐拍列出：拍序、layout、kicker、畫面 `lines`、`narration`，並標
明起／承／轉對應到哪拍。使用者說「可以／OK／就這樣／開始產」等明確同意
後才往下跑 Step 3。使用者要求修改就改完**重新貼一次**，改到同意為止。

改稿時**沿用原本的 beat `id`**（`cover` / `beat1` / `beat2` / … /
`ending`），只換文字。`reel_voiceover` 的語音快取是以 `beat_id → 文字
hash` 對應的，重新編號會讓所有拍的快取失效、整批重唸，一次就能把當天配額
用光（2026-07-26 實際踩過）。刪拍時寧可留下 id 的空隙，也不要往前遞補。

## Quick Reference

| Task | Command |
|---|---|
| 結構（硬規則） | 3–4 拍 ＋ ending，起→承→轉；ending 一律以「旅行，」起句、用「旅行，不只 A，／也是 B。」句型，A/B 依當篇故事調整 |
| 文字稿過審 | **render / TTS 前必須先貼給使用者同意**（Step 2b） |
| Scaffold a day | `node scripts/prepare_story.mjs <date>` |
| Live preview / tweak | `npx remotion studio` |
| One-frame check | `npx remotion still Cinematic out.png --frame=90 --scale=0.5` |
| Build final | `scripts/build_video.sh <date> [--style S] [--bgm F] [--lufs N]` |
| Build voiced (final.mp4) | `cd ../../../scripts && uv run python -m reel_voiceover <date> [--force-tts]`（Gemini TTS；不要用 say） |
| Output | `marketing/outputs/daily_video/<date>/cinematic.mp4` |

## Common Mistakes

- **Text changed but fonts not re-subset** → missing glyphs. `build_video.sh`
  re-subsets automatically; if rendering by hand, run `scripts/subset_fonts.py`
  first. Fonts are macOS Songti/Heiti subset locally (not the Google CJK font,
  which pulls hundreds of chunks and hangs the render).
- **Highlight not showing** → the phrase isn't an exact substring of a line.
- **改稿時重新編 beat id** → 語音快取全失效、整批重唸，Gemini TTS 免費層
  一天 10 次/key 立刻見底。沿用原 id、只換文字（見 Step 2b）。
- **還沒過審就開始 render / TTS** → 使用者一改就得重唸，等於白燒配額。
  Step 2b 是硬性 gate。
- **拍數不對** → 一律 3–4 拍 ＋ ending。
- **ending 每天照抄同一句** → 固定的只有「旅行，不只 A，／也是 B。」這個
  句型，A/B 要跟著當篇主題走；反過來把劇情反轉塞進 ending 也不行。
- **Logo detail (the trail) lost** → use `public/logo-lockup-white.png`
  (blue strokes → white, light fill → transparent). Don't flatten the whole
  logo to solid white; that swallows the trail.
- **BGM too loud under the voiceover** → the voiced flow (`reel_voiceover`) already builds the bed at `--lufs -28` automatically; only reach for a manual `--lufs -28` on the music-only `build_video.sh` path.
- **ffmpeg has no `drawtext`/libass here** → all text is Remotion (or PIL
  overlays), never ffmpeg drawtext.

## BGM

Drop a royalty-free, commercial-OK track in `marketing/sound/` (Pixabay Music
= no attribution required). `build_video.sh` picks the newest one; override
with `--bgm <file>`. Courtesy-credit it in the IG caption.
