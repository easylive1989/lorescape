#!/usr/bin/env python3
"""Regenerate the splash mark asset from the real brand app icon.

Extracts just the blue line-work (mountain outline + footprint trail) of
`marketing/brand/launch_icon_light.png` onto a transparent background, so the
splash shows the icon's lines only — no near-white background square and no
white fill. This asset feeds BOTH the native splash (flutter_native_splash
`image`) and the Flutter SplashScreen (`Image.asset`), floating on the light
`SPLASH_BG`.

Run from the repo root:  python3 frontend/tool/generate_splash_mark.py
Requires Pillow.
"""
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SRC = REPO / "marketing" / "brand" / "launch_icon_light.png"
OUT = REPO / "frontend" / "assets" / "images" / "splash_mark.png"
SIZE = 512
MARGIN = 0.20  # empty border fraction
BLUE = (26, 83, 148)  # brand blue #1A5394, matches the icon stroke
SPLASH_BG = "#F9F9F9"  # keep in sync with pubspec + SplashScreen bg


def extract_lines(src: Image.Image) -> Image.Image:
    """Keep only the blue strokes, painted flat brand blue with AA alpha."""
    src = src.convert("RGBA")
    px = src.load()
    w, h = src.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            blueness = b - max(r, g)  # strokes are strongly blue; fill/bg ~0
            if blueness <= 25:
                continue
            alpha = 255 if blueness >= 55 else int((blueness - 25) * 8.5)
            alpha = max(0, min(255, alpha))
            if alpha > 0:
                op[x, y] = (BLUE[0], BLUE[1], BLUE[2], alpha)
    return out


def center_on_canvas(mark: Image.Image) -> Image.Image:
    bbox = mark.getbbox()
    if bbox:
        mark = mark.crop(bbox)
    inner = int(SIZE * (1 - 2 * MARGIN))
    mw, mh = mark.size
    scale = min(inner / mw, inner / mh)
    mark = mark.resize((max(1, int(mw * scale)), max(1, int(mh * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(mark, ((SIZE - mark.size[0]) // 2, (SIZE - mark.size[1]) // 2))
    return canvas


def main() -> None:
    mark = center_on_canvas(extract_lines(Image.open(SRC)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    mark.save(OUT)
    print(f"wrote {OUT.relative_to(REPO)} ({SIZE}x{SIZE}); splash bg {SPLASH_BG}")


if __name__ == "__main__":
    main()
