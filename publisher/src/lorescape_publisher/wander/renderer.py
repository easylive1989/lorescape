# publisher/src/lorescape_publisher/wander/renderer.py
"""Playwright-based renderer for wander-style slides.

Same pattern as card/renderer.py: a headless Chromium with a 1080×1350
viewport loads the Jinja2 HTML from a temp file inside the template dir
(so file:// relative paths resolve), applies the auto-fit pass, then
screenshots as JPEG (publish format — smaller files for the monthly
archive).

CLI (manual daily flow):
    uv run python -m lorescape_publisher.wander.renderer \
        <day_dir> <photos_dir>
writes <day_dir>/slide_01.jpg … using <day_dir>/slides.json + caption.txt.
"""
from __future__ import annotations

import sys
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from playwright.sync_api import sync_playwright

from .content import (
    WanderCarousel,
    WanderContentError,
    WanderSlide,
    load_carousel,
)
from .template import render_html, template_dir

_CARD_WIDTH = 1080
_CARD_HEIGHT = 1350
_JPEG_QUALITY = 88

# Same shrink-to-fit approach as card/renderer.py, targeting the wander
# text plate (.ws-fit caps its height in wander.css; overflow is measurable).
_FIT_SCRIPT = """
(opts) => {
  const plate = document.querySelector('.ws-fit');
  if (!plate) return 1;
  // Width pass first: the cover title is nowrap, so a 4+ char place name
  // overflows its 600px plate. Shrink it until it fits on one line.
  const title = plate.querySelector('.ws-title-xl');
  if (title) {
    let tf = 1;
    let tGuard = 0;
    while (
      title.scrollWidth > title.clientWidth &&
      tf > opts.titleFloor &&
      tGuard < 80
    ) {
      tf = Math.round((tf - opts.step) * 1000) / 1000;
      title.style.setProperty('--title-fit', String(tf));
      tGuard += 1;
    }
  }
  const initial = parseFloat(
    getComputedStyle(plate).getPropertyValue('--fit'),
  );
  let fit = Number.isFinite(initial) ? initial : 1;
  let guard = 0;
  while (
    plate.scrollHeight > plate.clientHeight &&
    fit > opts.floor &&
    guard < 80
  ) {
    fit = Math.round((fit - opts.step) * 1000) / 1000;
    plate.style.setProperty('--fit', String(fit));
    guard += 1;
  }
  return fit;
}
"""

_FIT_OPTS = {"floor": 0.6, "step": 0.02, "titleFloor": 0.5}


def _photo_uri(photos_dir: Path, photo: str) -> str:
    path = photos_dir / photo
    if not path.is_file():
        raise WanderContentError(f"photo not found: {path}")
    return path.resolve().as_uri()


@contextmanager
def _html_file(slide: WanderSlide, *, photos_dir: Path) -> Iterator[Path]:
    """Render slide HTML to a temp file inside the template dir.

    Living in the template dir keeps wander.css / shared fonts loadable as
    sibling file:// resources (same reasoning as card/renderer.py).
    """
    base_url = template_dir().as_uri() + "/"
    html = render_html(
        slide,
        photo_uri=_photo_uri(photos_dir, slide.photo),
        base_url=base_url,
    )
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".html",
        dir=str(template_dir()),
        encoding="utf-8",
        delete=False,
    ) as tmp:
        tmp.write(html)
        tmp_path = Path(tmp.name)
    try:
        yield tmp_path
    finally:
        tmp_path.unlink(missing_ok=True)


def _screenshot_slide(browser, tmp_path: Path) -> bytes:
    page = browser.new_page(
        viewport={"width": _CARD_WIDTH, "height": _CARD_HEIGHT},
        device_scale_factor=1.0,
    )
    try:
        page.goto(tmp_path.as_uri(), wait_until="networkidle")
        page.evaluate(_FIT_SCRIPT, _FIT_OPTS)
        return page.screenshot(
            type="jpeg", quality=_JPEG_QUALITY, full_page=False
        )
    finally:
        page.close()


def render_slide(slide: WanderSlide, *, photos_dir: Path) -> bytes:
    """Render one slide to JPEG bytes (1080×1350)."""
    with _html_file(slide, photos_dir=photos_dir) as tmp_path:
        with sync_playwright() as pw:
            browser = pw.chromium.launch()
            try:
                return _screenshot_slide(browser, tmp_path)
            finally:
                browser.close()


def render_carousel(
    carousel: WanderCarousel, *, photos_dir: Path
) -> list[bytes]:
    """Render every slide to JPEG bytes; one browser reused across slides."""
    jpegs: list[bytes] = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        try:
            for slide in carousel.slides:
                with _html_file(slide, photos_dir=photos_dir) as tmp_path:
                    jpegs.append(_screenshot_slide(browser, tmp_path))
        finally:
            browser.close()
    return jpegs


def main(argv: list[str]) -> int:
    """CLI: render a day dir's slides.json into slide_NN.jpg files."""
    if len(argv) != 2:
        print(
            "usage: python -m lorescape_publisher.wander.renderer "
            "<day_dir> <photos_dir>",
            file=sys.stderr,
        )
        return 2
    day_dir = Path(argv[0])
    photos_dir = Path(argv[1])
    try:
        carousel = load_carousel(day_dir)
        jpegs = render_carousel(carousel, photos_dir=photos_dir)
    except WanderContentError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    for stale in day_dir.glob("slide_*.jpg"):
        stale.unlink()
    for index, jpeg in enumerate(jpegs, 1):
        out = day_dir / f"slide_{index:02d}.jpg"
        out.write_bytes(jpeg)
        print(f"wrote {out} ({len(jpeg)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
