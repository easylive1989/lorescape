#!/usr/bin/env python3
"""Regenerate the splash mark asset from the brand logo.

Recolours the blue line-art of `marketing/brand/logo.png` into a cream
(#F7F1E6) monochrome line-art on a transparent background, centred with a
small margin, and writes it to `frontend/assets/images/splash_mark.png`.

This asset feeds BOTH the native splash (flutter_native_splash `image`) and
the Flutter SplashScreen (`Image.asset`), so the two stages show the exact
same mark and hand off seamlessly.

Run from the repo root:  python3 frontend/tool/generate_splash_mark.py
Requires Pillow.
"""
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SRC = REPO / "marketing" / "brand" / "logo.png"
OUT = REPO / "frontend" / "assets" / "images" / "splash_mark.png"
CREAM = (247, 241, 230)  # #F7F1E6
CANVAS = 512
MARGIN = 0.12  # fraction of canvas kept as empty border


def recolor(src: Image.Image) -> Image.Image:
    """Keep only the blue strokes, painted cream with antialiased alpha."""
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
            blueness = b - max(r, g)  # blue strokes are strongly blue-dominant
            if blueness <= 30:  # drop the soft blue halo/shadow around strokes
                continue
            # Steep ramp: solid cream cores, only a thin antialiased edge.
            alpha = 255 if blueness >= 60 else int((blueness - 30) * 8.5)
            alpha = max(0, min(255, alpha))
            if alpha > 0:
                op[x, y] = (CREAM[0], CREAM[1], CREAM[2], alpha)
    return out


def center_on_canvas(mark: Image.Image) -> Image.Image:
    bbox = mark.getbbox()
    if bbox:
        mark = mark.crop(bbox)
    inner = int(CANVAS * (1 - 2 * MARGIN))
    mw, mh = mark.size
    scale = min(inner / mw, inner / mh)
    mark = mark.resize((max(1, int(mw * scale)), max(1, int(mh * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(mark, ((CANVAS - mark.size[0]) // 2, (CANVAS - mark.size[1]) // 2))
    return canvas


def main() -> None:
    mark = center_on_canvas(recolor(Image.open(SRC)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    mark.save(OUT)
    print(f"wrote {OUT.relative_to(REPO)} ({mark.size[0]}x{mark.size[1]})")


if __name__ == "__main__":
    main()
