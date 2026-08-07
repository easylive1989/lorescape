"""Tests for story_assets.cutout — magenta chroma-key + bbox crop."""
from __future__ import annotations

import io

import pytest
from PIL import Image

from story_assets.cutout import MAGENTA, chroma_key


def _make_png(pixels_fn, size=(10, 10)) -> bytes:
    image = Image.new("RGB", size)
    for y in range(size[1]):
        for x in range(size[0]):
            image.putpixel((x, y), pixels_fn(x, y))
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def _magenta_with_center_red_square() -> bytes:
    # 10x10 magenta background with a 4x4 red square centered at (3,3)-(6,6).
    def pixel(x, y):
        if 3 <= x <= 6 and 3 <= y <= 6:
            return (255, 0, 0)
        return MAGENTA

    return _make_png(pixel)


def test_chroma_key_crops_to_foreground_bbox():
    png_bytes = _magenta_with_center_red_square()

    result = chroma_key(png_bytes)

    image = Image.open(io.BytesIO(result))
    assert image.size == (4, 4)


def test_chroma_key_result_pixels_are_opaque_and_red():
    png_bytes = _magenta_with_center_red_square()

    result = chroma_key(png_bytes)

    image = Image.open(io.BytesIO(result)).convert("RGBA")
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.getpixel((x, y))
            assert a == 255
            assert (r, g, b) == (255, 0, 0)


def test_chroma_key_all_magenta_raises_value_error():
    png_bytes = _make_png(lambda x, y: MAGENTA)

    with pytest.raises(ValueError):
        chroma_key(png_bytes)
