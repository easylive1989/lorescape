"""Magenta chroma-key cutout for character sprite images."""
from __future__ import annotations

import io

from PIL import Image

MAGENTA = (255, 0, 255)


def chroma_key(png_bytes: bytes, threshold: int = 60) -> bytes:
    """Key out a solid-magenta background and crop to the foreground bbox.

    Any pixel within Euclidean RGB distance `threshold` of MAGENTA becomes
    fully transparent. The result is cropped to the bounding box of the
    remaining opaque pixels and returned as PNG bytes. Raises ValueError if
    every pixel keys out (no foreground left).
    """
    image = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    threshold_sq = threshold * threshold

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            dr = r - MAGENTA[0]
            dg = g - MAGENTA[1]
            db = b - MAGENTA[2]
            if dr * dr + dg * dg + db * db < threshold_sq:
                pixels[x, y] = (r, g, b, 0)

    bbox = image.getbbox()
    if bbox is None:
        raise ValueError("chroma_key: no foreground pixels remain after keying out magenta")

    cropped = image.crop(bbox)
    buffer = io.BytesIO()
    cropped.save(buffer, format="PNG")
    return buffer.getvalue()
