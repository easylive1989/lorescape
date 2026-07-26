"""IG Reels post-production for the daily-story Flow reel.

The lorescape-manual-daily-story skill produces a clean 9:16 / 10s reel in
Google Flow with NO narration and NO on-screen text (Step 9). That clip is
the master. This script is Step 10: it takes the downloaded master and
overlays a short zh-TW voiceover plus full burned-in captions, producing an
IG-ready cut in ``marketing/outputs/daily_video/{date}/final.mp4``.

The voiceover uses Gemini TTS by default (natural zh-TW; macOS ``say`` is
the offline fallback via ``--engine say``). Captions are kept in sync by
speaking each line separately, measuring its duration with ``ffprobe``,
and showing each line only during its measured interval. The original
ambient audio is kept but ducked under the voiceover.

Captions are rendered to transparent PNGs with Pillow and composited via
ffmpeg's ``overlay`` filter. This deliberately avoids ffmpeg's libass /
drawtext text filters, which are not compiled into the Homebrew ffmpeg on
this machine.

Run from scripts/:

    uv run python -m daily_video_post --date 2026-06-20
    uv run python -m daily_video_post \\
        --date 2026-06-20 \\
        --input marketing/outputs/daily_video/2026-06-20/source.mp4 \\
        --text  marketing/outputs/daily_video/2026-06-20/narration.txt \\
        --voice Meijia --bg-volume 0.28

``--text`` points at a UTF-8 file with one caption line per row (Claude
writes it in Step 10). Alternatively pass ``--line "句子"`` one or more
times. With neither, the script reads ``narration.txt`` from the date dir.
"""
from __future__ import annotations

import argparse
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

logger = logging.getLogger("daily_video_post")

REPO_ROOT = Path(__file__).resolve().parents[1]

DEFAULT_SAY_VOICE = "Meijia"  # Taiwanese Mandarin voice shipped with macOS.
DEFAULT_GEMINI_VOICE = "Despina"  # Smooth female prebuilt Gemini TTS voice.
# 2.5-flash-preview-tts is being wound down (new keys 404 on 2.5; it returns
# finishReason OTHER + empty audio). Its official successor is 3.1-flash-tts.
GEMINI_TTS_MODEL = "gemini-3.1-flash-tts-preview"
# Natural-language style steer prepended to each line for Gemini TTS.
DEFAULT_GEMINI_STYLE = "用溫暖、沉穩、語速稍快的紀錄片旁白語氣說："
DEFAULT_FONT = "/System/Library/Fonts/STHeiti Medium.ttc"  # CJK font file.
DEFAULT_BG_VOLUME = 0.28  # Ambient kept audible but well under the voiceover.
LEAD_IN_SECONDS = 0.3  # Small silence before the first line starts.
PAUSE_SECONDS = 0.25  # Gap inserted between spoken lines.
AUDIO_RATE = 44100
# IG serves ≥1080p uploads through a higher-quality encode and skips its own
# upscaler, so we floor every reel at a 1080-wide 9:16 frame even when the
# Flow master came down at 720p. Pass --target-height 0 to keep the source.
DEFAULT_TARGET_HEIGHT = 1920
# IG Reels overlays its own UI on the bottom ~20% (caption, handle, audio,
# progress) and the right ~13% (action buttons). Keep the caption block's
# bottom edge above that band so nothing important is covered.
CAPTION_BOTTOM_MARGIN_FRACTION = 0.20
# The first narration line is the curiosity hook: render it larger and
# centred slightly above the middle so it grabs attention in the opening
# seconds, instead of sitting in the bottom body-caption position.
HOOK_FONT_FRACTION = 0.060
BODY_FONT_FRACTION = 0.045
HOOK_CENTER_FRACTION = 0.40
# Fade from/to black at the clip edges so a looping reel has a clean, calm
# boundary on replay (a true seamless loop is impossible for distinct scenes
# with burned-in captions). Ken Burns is opt-in: the Flow master already has
# camera motion, so a slow zoom only helps genuinely static footage.
DEFAULT_FADE_SECONDS = 0.3
KEN_BURNS_MAX_ZOOM = 1.12
KEN_BURNS_FPS = 30


def _target_dimensions(
    width: int, height: int, target_height: int
) -> tuple[int, int]:
    """Output size for ``target_height``, preserving aspect (even width).

    Returns the source size unchanged when ``target_height`` is 0 or already
    matches, so an already-1080p master is never needlessly re-scaled.
    """
    if target_height <= 0 or height == target_height:
        return width, height
    scaled_width = round(width * target_height / height)
    if scaled_width % 2:
        scaled_width += 1
    return scaled_width, target_height


class PostProductionError(RuntimeError):
    """Raised when an external tool is missing or a step fails."""


class _EmptyTtsResponse(RuntimeError):
    """Raised when Gemini TTS returns a candidate with no audio parts."""


def _run(cmd: list[str], *, cwd: Path | None = None) -> None:
    """Run a subprocess, raising PostProductionError on failure."""
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise PostProductionError(
            f"command failed ({result.returncode}): {' '.join(cmd)}\n"
            f"{result.stderr.strip()}"
        )


def _require_tools(engine: str) -> None:
    tools = ["ffmpeg", "ffprobe"]
    if engine == "say":
        tools.append("say")
    for tool in tools:
        if shutil.which(tool) is None:
            raise PostProductionError(
                f"required tool {tool!r} not found on PATH"
            )


def _ffprobe_duration(path: Path) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(out.stdout.strip())


def _ffprobe_dimensions(path: Path) -> tuple[int, int]:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, text=True, check=True,
    )
    width, height = out.stdout.split()
    return int(width), int(height)


def _has_audio_stream(path: Path) -> bool:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a",
         "-show_entries", "stream=index", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, check=True,
    )
    return bool(out.stdout.strip())


def _read_lines(args: argparse.Namespace, out_dir: Path) -> list[str]:
    """Resolve caption/narration lines from --line, --text, or narration.txt."""
    if args.line:
        raw = args.line
    else:
        text_path = Path(args.text) if args.text else out_dir / "narration.txt"
        if not text_path.is_absolute():
            text_path = REPO_ROOT / text_path
        if not text_path.exists():
            raise PostProductionError(
                f"no narration found — provide --text/--line or create "
                f"{text_path}"
            )
        raw = text_path.read_text(encoding="utf-8").splitlines()
    lines = [line.strip() for line in raw if line.strip()]
    if not lines:
        raise PostProductionError("narration is empty after stripping blanks")
    return lines


def _make_silence(path: Path, seconds: float) -> None:
    _run([
        "ffmpeg", "-y", "-f", "lavfi",
        "-i", f"anullsrc=r={AUDIO_RATE}:cl=mono",
        "-t", f"{seconds:.3f}", "-c:a", "pcm_s16le", str(path),
    ])


def _say_to_wav(text: str, voice: str, rate: int | None, dest: Path) -> None:
    """Synthesize one line with macOS `say` into a 44.1k mono wav."""
    aiff = dest.with_suffix(".aiff")
    cmd = ["say", "-v", voice]
    if rate:
        cmd += ["-r", str(rate)]
    cmd += ["-o", str(aiff), text]
    _run(cmd)
    _run([
        "ffmpeg", "-y", "-i", str(aiff),
        "-ar", str(AUDIO_RATE), "-ac", "1", "-c:a", "pcm_s16le", str(dest),
    ])
    aiff.unlink(missing_ok=True)


def _gemini_to_wav(
    client, voice: str, style: str, text: str, dest: Path
) -> None:
    """Synthesize one line with Gemini TTS into a 44.1k mono wav.

    Gemini returns raw little-endian 16-bit PCM whose sample rate is in the
    inline-data mime type (e.g. ``audio/L16;rate=24000``); ffmpeg reads it
    raw and resamples to the pipeline's 44.1k mono.
    """
    from google.genai import types

    response = client.models.generate_content(
        model=GEMINI_TTS_MODEL,
        contents=f"{style}{text}",
        config=types.GenerateContentConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(
                        voice_name=voice
                    )
                )
            ),
        ),
    )
    if (
        not response.candidates
        or response.candidates[0].content is None
        or not response.candidates[0].content.parts
    ):
        raise _EmptyTtsResponse(
            f"Gemini TTS returned no audio for line: {text[:30]}…"
        )
    inline = response.candidates[0].content.parts[0].inline_data
    rate = "24000"
    for token in (inline.mime_type or "").split(";"):
        if token.strip().startswith("rate="):
            rate = token.split("=", 1)[1].strip()
    pcm = dest.with_suffix(".pcm")
    pcm.write_bytes(inline.data)
    _run([
        "ffmpeg", "-y", "-f", "s16le", "-ar", rate, "-ac", "1",
        "-i", str(pcm),
        "-ar", str(AUDIO_RATE), "-ac", "1", "-c:a", "pcm_s16le", str(dest),
    ])
    pcm.unlink(missing_ok=True)


def _build_voice_track(
    lines: list[str], synth, work_dir: Path, voice_path: Path,
) -> list[tuple[float, float, str]]:
    """Speak each line, concat with pauses; return (start, end, text) rows."""
    pause_path = work_dir / "pause.wav"
    lead_path = work_dir / "lead.wav"
    _make_silence(pause_path, PAUSE_SECONDS)
    _make_silence(lead_path, LEAD_IN_SECONDS)

    concat_parts: list[Path] = [lead_path]
    timings: list[tuple[float, float, str]] = []
    cursor = LEAD_IN_SECONDS
    for index, text in enumerate(lines, start=1):
        chunk = work_dir / f"chunk_{index}.wav"
        synth(text, chunk)
        duration = _ffprobe_duration(chunk)
        timings.append((cursor, cursor + duration, text))
        cursor += duration + PAUSE_SECONDS
        concat_parts.append(chunk)
        if index < len(lines):
            concat_parts.append(pause_path)

    list_file = work_dir / "concat.txt"
    list_file.write_text(
        "".join(f"file '{p.resolve()}'\n" for p in concat_parts),
        encoding="utf-8",
    )
    _run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(list_file),
        "-c:a", "pcm_s16le", str(voice_path),
    ])
    return timings


# CJK closing punctuation that must not start a line (避頭尾 / kinsoku rule).
_NO_LINE_START = set("。，、；：！？）〕】」』》〉”’%")


def _wrap(
    text: str, font: ImageFont.FreeTypeFont, max_width: float
) -> list[str]:
    """Greedily wrap text to max_width; breaks between characters (CJK-safe).

    Trailing closing punctuation is kept on the current line rather than
    orphaned onto the next one, even if it slightly overflows the width.
    """
    lines: list[str] = []
    current = ""
    for char in text:
        fits = font.getlength(current + char) <= max_width
        keep_punct = char in _NO_LINE_START and current
        if fits or keep_punct:
            current += char
        else:
            if current:
                lines.append(current)
            current = char
    if current:
        lines.append(current)
    return lines or [""]


def _line_height(font: ImageFont.FreeTypeFont, font_size: int) -> int:
    """Vertical advance per wrapped row, with a little extra leading."""
    ascent, descent = font.getmetrics()
    return ascent + descent + round(font_size * 0.25)


def _draw_caption(
    width: int, height: int, rows: list[str],
    font: ImageFont.FreeTypeFont, top_y: int, line_height: int, stroke: int,
) -> Image.Image:
    """Draw centred, stroked white rows onto a transparent full-frame image."""
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    y = top_y
    for row in rows:
        x = (width - font.getlength(row)) / 2
        draw.text(
            (x, y), row, font=font, fill=(255, 255, 255, 255),
            stroke_width=stroke, stroke_fill=(0, 0, 0, 235),
        )
        y += line_height
    return image


def _render_caption_pngs(
    timings: list[tuple[float, float, str]],
    width: int, height: int, font_file: str, work_dir: Path,
) -> list[tuple[Path, float, float]]:
    """Render each caption line to a full-frame transparent PNG with Pillow.

    The first line is the spoken hook: it is drawn larger and centred just
    above the middle to grab attention in the opening seconds. Remaining
    lines are the standard body captions, bottom-anchored above IG's UI band.
    """
    max_text_width = width * 0.84
    stroke = max(2, round(height * 0.004))
    body_size = max(20, round(height * BODY_FONT_FRACTION))
    hook_size = max(24, round(height * HOOK_FONT_FRACTION))
    body_font = ImageFont.truetype(font_file, body_size)
    hook_font = ImageFont.truetype(font_file, hook_size)
    bottom_margin = round(height * CAPTION_BOTTOM_MARGIN_FRACTION)

    captions: list[tuple[Path, float, float]] = []
    for index, (start, end, text) in enumerate(timings):
        is_hook = index == 0
        font = hook_font if is_hook else body_font
        line_height = _line_height(font, hook_size if is_hook else body_size)
        rows = _wrap(text, font, max_text_width)
        block_height = line_height * len(rows)
        if is_hook:
            top_y = round(height * HOOK_CENTER_FRACTION - block_height / 2)
        else:
            top_y = height - bottom_margin - block_height
        image = _draw_caption(
            width, height, rows, font, top_y, line_height, stroke
        )
        png = work_dir / f"caption_{index + 1}.png"
        image.save(png)
        captions.append((png, start, end))
    return captions


def _render(
    source: Path, voice_path: Path | None,
    captions: list[tuple[Path, float, float]],
    badge: tuple[Path, int, int] | None,
    delogo: tuple[int, int, int, int] | None, out_dir: Path,
    final_path: Path, bg_volume: float, voice_dur: float, video_dur: float,
    has_audio: bool, scale_to: tuple[int, int] | None = None,
    ken_burns: bool = False, fade_duration: float = 0.0,
    out_size: tuple[int, int] | None = None,
) -> bool:
    """Composite delogo + scale + badge + captions + audio; return if padded.

    ``voice_path`` None means no narration: original audio is kept and no
    captions are burned (caption timing comes from the voiceover). ``badge``
    is an optional ``(path, x, y)`` brand mark overlaid full-duration on top.
    ``delogo`` is an optional ``(x, y, w, h)`` region blurred away first (to
    erase the Flow/Veo watermark before the brand mark covers it); its
    coordinates are in source pixels, so the blur and the badge overlay both
    run before ``scale_to``. ``scale_to`` is an optional ``(w, h)`` the base
    frame is scaled to (after delogo + badge) so captions — rendered at the
    final resolution — composite crisply on top. ``ken_burns`` applies a slow
    zoom (using ``out_size``) to the scaled frame before captions. A non-zero
    ``fade_duration`` fades video + audio from/to black at the clip edges.
    """
    inputs = ["-i", str(source)]
    index = 1
    voice_idx = None
    if voice_path is not None:
        inputs += ["-i", str(voice_path)]
        voice_idx = index
        index += 1
    caption_idx0 = index
    for png, _start, _end in captions:
        inputs += ["-i", str(png)]
        index += 1
    badge_idx = None
    if badge is not None:
        inputs += ["-i", str(badge[0])]
        badge_idx = index
        index += 1

    vparts: list[str] = []
    padded = voice_path is not None and voice_dur > video_dur + 0.05
    current = "[0:v]"
    if delogo is not None:
        dx, dy, dw, dh = delogo
        vparts.append(f"{current}delogo=x={dx}:y={dy}:w={dw}:h={dh}[vdl]")
        current = "[vdl]"
    # The badge covers the delogo'd Flow watermark, so its coordinates are in
    # SOURCE pixels — overlay it before scaling so it stays aligned. Captions,
    # by contrast, are rendered at the final resolution and overlaid after.
    if badge_idx is not None:
        bx, by = badge[1], badge[2]
        vparts.append(f"{current}[{badge_idx}:v]overlay={bx}:{by}[vbdg]")
        current = "[vbdg]"
    if scale_to is not None:
        sw, sh = scale_to
        vparts.append(f"{current}scale={sw}:{sh}:flags=lanczos[vsc]")
        current = "[vsc]"
    out_dur = voice_dur if padded else video_dur
    # Ken Burns: a gentle continuous zoom over the moving portion, completing
    # by video_dur so any padded tail freezes on the fully-zoomed frame.
    if ken_burns and out_size is not None:
        kw, kh = out_size
        frames = max(1, round(video_dur * KEN_BURNS_FPS))
        # Drive zoom off the output frame number ``on`` (linear ramp): the
        # accumulating ``zoom+rate`` form silently fails to persist in some
        # ffmpeg builds, leaving the clip un-zoomed.
        rate = (KEN_BURNS_MAX_ZOOM - 1.0) / frames
        vparts.append(
            f"{current}zoompan=z='min(1+{rate:.6f}*on,{KEN_BURNS_MAX_ZOOM})':"
            f"d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
            f"s={kw}x{kh}:fps={KEN_BURNS_FPS}[vkb]"
        )
        current = "[vkb]"
    if padded:
        vparts.append(
            f"{current}tpad=stop_mode=clone:"
            f"stop_duration={voice_dur - video_dur:.3f}[vbase]"
        )
        current = "[vbase]"

    overlays = [
        (f"[{caption_idx0 + i}:v]",
         f"overlay=eof_action=repeat:enable='between(t,{s:.3f},{e:.3f})'")
        for i, (_png, s, e) in enumerate(captions)
    ]
    for pos, (overlay_in, op) in enumerate(overlays):
        label = f"[vo{pos}]"
        vparts.append(f"{current}{overlay_in}{op}{label}")
        current = label

    fade_d = min(fade_duration, out_dur / 3) if fade_duration > 0 else 0.0
    fade_out_start = max(0.0, out_dur - fade_d)
    if fade_d > 0:
        vparts.append(
            f"{current}fade=t=in:st=0:d={fade_d:.3f}:color=black,"
            f"fade=t=out:st={fade_out_start:.3f}:d={fade_d:.3f}:"
            "color=black[v]"
        )
        current = "[v]"
    video_map = current if vparts else "0:v"

    aparts: list[str] = []
    if voice_path is not None:
        if has_audio:
            aparts.append(
                f"[0:a]volume={bg_volume}[bg];[{voice_idx}:a]volume=1.0[vo];"
                "[bg][vo]amix=inputs=2:duration=longest:dropout_transition=0:"
                "normalize=0[a]"
            )
        else:
            aparts.append(
                f"[{voice_idx}:a]volume=1.0,aresample={AUDIO_RATE}[a]"
            )
        audio_map = "[a]"
    else:
        audio_map = "0:a" if has_audio else None

    if fade_d > 0 and audio_map is not None:
        aparts.append(
            f"{audio_map}afade=t=in:st=0:d={fade_d:.3f},"
            f"afade=t=out:st={fade_out_start:.3f}:d={fade_d:.3f}[aout]"
        )
        audio_map = "[aout]"

    filter_complex = ";".join(vparts + aparts)
    cmd = ["ffmpeg", "-y", *inputs]
    if filter_complex:
        cmd += ["-filter_complex", filter_complex]
    cmd += ["-map", video_map]
    if audio_map:
        cmd += ["-map", audio_map]
    cmd += [
        "-c:v", "libx264", "-preset", "medium", "-crf", "20",
        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k",
        "-movflags", "+faststart", str(final_path),
    ]
    _run(cmd, cwd=out_dir)
    return padded


def _build_gemini_client():
    """Build a google-genai client from the publisher's .env / config.

    Reuses the project's GenaiSettings (AI Studio key or Vertex) so the
    backend switch stays in one place. GOOGLE_API_KEY is popped first: the
    SDK prefers it over GEMINI_API_KEY, but on this machine it is a
    non-Gemini key.
    """
    from dotenv import load_dotenv

    load_dotenv(REPO_ROOT / "publisher" / ".env")
    os.environ.pop("GOOGLE_API_KEY", None)
    from lorescape_publisher.config import Config
    from lorescape_publisher.genai import build_client

    return build_client(Config.from_env().genai_settings)


def _numbered_fallback_keys() -> list[tuple[str, str]]:
    """Return ``GEMINI_API_KEY_2``, ``_3``, … in order, skipping gaps."""
    keys = []
    for n in range(2, 10):
        name = f"GEMINI_API_KEY_{n}"
        value = os.environ.get(name)
        if value:
            keys.append((name, value))
    return keys


class _GeminiSynth:
    """Gemini TTS ``synth(text, dest)`` with quota fallback and retries.

    The free tier caps TTS at 10 requests/day per key, and flaky empty
    candidates still count against it. When the primary key 429s, the
    ``GEMINI_API_KEY_2``, ``GEMINI_API_KEY_3``, … keys from
    ``publisher/.env`` take over in turn for the rest of the run; empty
    responses are retried a couple of times before failing the render.
    """

    _MAX_ATTEMPTS = 4

    def __init__(self, voice: str, style: str) -> None:
        self._voice = voice
        self._style = style
        self._client = _build_gemini_client()
        self._fallback_keys = _numbered_fallback_keys()

    def __call__(self, text: str, dest: Path) -> None:
        from google.genai.errors import ClientError

        for attempt in range(1, self._MAX_ATTEMPTS + 1):
            try:
                _gemini_to_wav(
                    self._client, self._voice, self._style, text, dest
                )
                return
            except _EmptyTtsResponse:
                logger.warning(
                    "gemini TTS returned empty audio (attempt %d/%d)",
                    attempt, self._MAX_ATTEMPTS,
                )
                if attempt >= 2:
                    self._switch_to_fallback()
            except ClientError as exc:
                if getattr(exc, "code", None) != 429:
                    raise
                if not self._switch_to_fallback():
                    raise PostProductionError(
                        "Gemini TTS quota exhausted on all keys (free tier "
                        "= 10 requests/day/key; resets at midnight Pacific)"
                    ) from exc
        raise PostProductionError(
            "Gemini TTS kept returning empty audio; try again later"
        )

    def _switch_to_fallback(self) -> bool:
        if not self._fallback_keys:
            return False
        from google import genai

        name, key = self._fallback_keys.pop(0)
        logger.warning(
            "GEMINI TTS key quota exhausted; switching to %s", name
        )
        self._client = genai.Client(api_key=key)
        return True


def _make_synth(engine: str, voice: str, rate: int | None, style: str):
    """Return a ``synth(text, dest)`` callable for the chosen TTS engine."""
    if engine == "gemini":
        return _GeminiSynth(voice, style)
    return lambda text, dest: _say_to_wav(text, voice, rate, dest)


def _resolve_badge(
    args: argparse.Namespace, width: int, height: int
) -> tuple[Path, int, int] | None:
    """Resolve the optional brand badge to ``(path, x, y)`` top-left.

    Position is fixed/configurable: ``--badge-x``/``--badge-y`` override,
    otherwise the badge sits in the bottom-right corner with a margin.
    """
    if not args.badge:
        return None
    path = Path(args.badge)
    if not path.is_absolute():
        path = REPO_ROOT / path
    if not path.exists():
        raise PostProductionError(f"badge image not found: {path}")
    bw, bh = Image.open(path).size
    margin = 44
    x = args.badge_x if args.badge_x is not None else width - bw - margin
    y = args.badge_y if args.badge_y is not None else height - bh - margin
    return (path, x, y)


def _parse_delogo(spec: str | None) -> tuple[int, int, int, int] | None:
    """Parse a ``"x,y,w,h"`` delogo region string into a tuple."""
    if not spec:
        return None
    try:
        x, y, w, h = (int(v) for v in spec.split(","))
    except ValueError as exc:
        raise PostProductionError(
            f"--delogo must be 'x,y,w,h' integers, got {spec!r}"
        ) from exc
    return (x, y, w, h)


def cmd_build(args: argparse.Namespace) -> int:
    _require_tools(args.engine)
    _engine_default_voice = {
        "gemini": DEFAULT_GEMINI_VOICE,
        "say": DEFAULT_SAY_VOICE,
    }
    voice = args.voice or _engine_default_voice[args.engine]

    out_dir = REPO_ROOT / "marketing" / "outputs" / "daily_video" / args.date
    out_dir.mkdir(parents=True, exist_ok=True)

    source = Path(args.input) if args.input else out_dir / "source.mp4"
    if not source.is_absolute():
        source = REPO_ROOT / source
    if not source.exists():
        raise PostProductionError(
            f"input video not found: {source}\n"
            "Download the Flow reel and place it at "
            f"marketing/outputs/daily_video/{args.date}/source.mp4 (or pass --input)."
        )

    width, height = _ffprobe_dimensions(source)
    video_dur = _ffprobe_duration(source)
    has_audio = _has_audio_stream(source)
    render_width, render_height = _target_dimensions(
        width, height, args.target_height
    )
    scale_to = (
        (render_width, render_height)
        if (render_width, render_height) != (width, height)
        else None
    )
    # Badge coords are source-space (they cover the Flow watermark before
    # scaling); captions are rendered at the final scaled resolution.
    badge = _resolve_badge(args, width, height)
    delogo = _parse_delogo(args.delogo)
    logger.info(
        "source %dx%d -> output %dx%d, %.2fs, audio=%s, badge=%s, delogo=%s",
        width, height, render_width, render_height, video_dur, has_audio,
        bool(badge), bool(delogo),
    )
    final_path = out_dir / "final.mp4"
    out_size = (render_width, render_height)
    fade_duration = 0.0 if args.no_fade else DEFAULT_FADE_SECONDS

    if args.no_voice:
        logger.info("no-voice: branding + original audio only")
        _render(
            source, None, [], badge, delogo, out_dir, final_path,
            args.bg_volume, 0.0, video_dur, has_audio, scale_to,
            args.ken_burns, fade_duration, out_size,
        )
        logger.info("done: %s (%.2fs)", final_path, video_dur)
        return 0

    lines = _read_lines(args, out_dir)
    logger.info("narration: %d line(s)", len(lines))

    work_dir = out_dir / ".work"
    if work_dir.exists():
        shutil.rmtree(work_dir)
    work_dir.mkdir()

    voice_path = out_dir / "voice.wav"
    synth = _make_synth(args.engine, voice, args.rate, args.style)
    logger.info("tts: engine=%s voice=%s", args.engine, voice)
    timings = _build_voice_track(lines, synth, work_dir, voice_path)
    voice_dur = _ffprobe_duration(voice_path)
    logger.info("voiceover: %.2fs", voice_dur)

    captions = _render_caption_pngs(
        timings, render_width, render_height, args.font, work_dir
    )

    padded = _render(
        source, voice_path, captions, badge, delogo, out_dir, final_path,
        args.bg_volume, voice_dur, video_dur, has_audio, scale_to,
        args.ken_burns, fade_duration, out_size,
    )

    shutil.rmtree(work_dir, ignore_errors=True)

    if voice_dur > video_dur + 2.0:
        logger.warning(
            "voiceover (%.1fs) is much longer than the clip (%.1fs); consider "
            "a shorter intro so the reel stays tight.", voice_dur, video_dur
        )
    logger.info(
        "done: %s (%.2fs%s)", final_path, max(voice_dur, video_dur),
        ", last frame held to fit narration" if padded else "",
    )
    logger.info("kept for review: %s", voice_path.name)
    return 0


def main(argv: list[str]) -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--date", required=True, help="Reel date YYYY-MM-DD (output folder)"
    )
    parser.add_argument(
        "--input", help="Source video (default: "
        "marketing/outputs/daily_video/{date}/source.mp4)"
    )
    parser.add_argument(
        "--text", help="UTF-8 file, one caption line per row (default: "
        "marketing/outputs/daily_video/{date}/narration.txt)"
    )
    parser.add_argument(
        "--line", action="append", help="Caption line (repeatable; overrides "
        "--text)"
    )
    parser.add_argument(
        "--engine", choices=("gemini", "say"), default="gemini",
        help="TTS engine (default: gemini, via the backend's GEMINI_API_KEY "
        "/ GenaiSettings). 'say' is the offline macOS fallback."
    )
    parser.add_argument(
        "--voice", default=None,
        help=f"Voice name. Default: {DEFAULT_GEMINI_VOICE} (gemini) / "
        f"{DEFAULT_SAY_VOICE} (say)."
    )
    parser.add_argument(
        "--rate", type=int, help="say speaking rate (say engine only)"
    )
    parser.add_argument(
        "--style", default=DEFAULT_GEMINI_STYLE,
        help="Gemini TTS style steer prepended to each line"
    )
    parser.add_argument(
        "--font", default=DEFAULT_FONT,
        help=f"Caption font file path (default: {DEFAULT_FONT})"
    )
    parser.add_argument(
        "--target-height", type=int, default=DEFAULT_TARGET_HEIGHT,
        help="Scale output to this height (9:16 width kept), flooring IG "
        f"quality at 1080p (default: {DEFAULT_TARGET_HEIGHT}; 0 = keep source)"
    )
    parser.add_argument(
        "--ken-burns", action="store_true",
        help="Apply a slow Ken Burns zoom (for static footage; the Flow "
        "master usually already has camera motion, so this is off by default)"
    )
    parser.add_argument(
        "--no-fade", action="store_true",
        help="Disable the fade from/to black at the clip edges (on by "
        f"default, {DEFAULT_FADE_SECONDS}s, for a clean loop boundary)"
    )
    parser.add_argument(
        "--bg-volume", type=float, default=DEFAULT_BG_VOLUME,
        help=f"Ambient volume under narration (default: {DEFAULT_BG_VOLUME})"
    )
    parser.add_argument(
        "--badge", help="Brand badge PNG overlaid on the video (e.g. to "
        "cover the Flow/Veo watermark)"
    )
    parser.add_argument(
        "--badge-x", type=int, help="Badge top-left x (default: bottom-right "
        "corner)"
    )
    parser.add_argument(
        "--badge-y", type=int, help="Badge top-left y (default: bottom-right "
        "corner)"
    )
    parser.add_argument(
        "--no-voice", action="store_true", help="Skip narration + captions; "
        "keep original audio (brand-only preview)"
    )
    parser.add_argument(
        "--delogo", help="Watermark region 'x,y,w,h' to erase before the "
        "badge covers it (Google moves it per video — measure per run)"
    )

    args = parser.parse_args(argv)
    try:
        return cmd_build(args)
    except PostProductionError as exc:
        logger.error("error: %s", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
