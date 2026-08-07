"""Gemini image generation for a single story scene or character sprite."""
from __future__ import annotations

from google.genai import types

IMAGE_MODEL = "gemini-2.5-flash-image"


def generate_image(client, prompt: str, reference_png: bytes | None = None) -> bytes:
    """Generate one image via Gemini and return its raw PNG bytes.

    Passes `reference_png` (if given) as an additional image Part alongside
    the prompt, e.g. for style-consistent character sprites. Raises
    RuntimeError if the response contains no image part.
    """
    contents: list = [prompt]
    if reference_png is not None:
        contents.append(
            types.Part.from_bytes(data=reference_png, mime_type="image/png")
        )

    response = client.models.generate_content(model=IMAGE_MODEL, contents=contents)

    for candidate in response.candidates or []:
        content = candidate.content
        if content is None:
            continue
        for part in content.parts or []:
            inline_data = getattr(part, "inline_data", None)
            if inline_data is not None:
                return inline_data.data

    raise RuntimeError(f"Gemini returned no image data for prompt: {prompt!r}")
