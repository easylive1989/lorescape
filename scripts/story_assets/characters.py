"""Generate a story's character reference + full-body sprite images.

For each character: generate one full-body reference image on a solid
magenta background, then chroma-key it to a transparent PNG and write it to
the path declared in script.json's `characters[].image`.
"""
from __future__ import annotations

import json
from pathlib import Path

from story_assets.cutout import chroma_key
from story_assets.gemini import generate_image

REFERENCE_SUFFIX = (
    "full body, front facing, standing, plain solid magenta background #FF00FF, "
    "single character, no text"
)


def run_characters(
    content_dir: Path,
    client,
    only: str | None = None,
    force: bool = False,
) -> None:
    """Generate reference + full-body image for each character under `content_dir`.

    Writes `assets/characters/<id>/_reference.png` and the chroma-keyed
    cutout at the path declared in script.json's `characters[].image`.
    Existing files are skipped unless `force` is set; when the reference
    already exists it is reused (not regenerated) even if the cutout image
    is still missing.

    `only` restricts the run to a single character id. Raises ValueError if
    `only` matches no character — before any generation call is made.
    """
    script = json.loads((content_dir / "script.json").read_text(encoding="utf-8"))
    art = json.loads((content_dir / "art.json").read_text(encoding="utf-8"))

    style = art["style"]
    character_prompts: dict[str, str] = art.get("characters", {})
    characters = script.get("characters", [])

    if only is not None:
        matched = [character for character in characters if character["id"] == only]
        if not matched:
            available = ", ".join(character["id"] for character in characters)
            raise ValueError(
                f"--only {only!r} matched no character; available id(s): {available}"
            )
        characters = matched

    for character in characters:
        char_id = character["id"]
        prompt_suffix = character_prompts.get(char_id)
        if prompt_suffix is None:
            raise ValueError(f"art.json is missing character prompt for {char_id!r}")

        reference_dest = content_dir / "assets" / "characters" / char_id / "_reference.png"
        if reference_dest.exists() and not force:
            reference_bytes = reference_dest.read_bytes()
        else:
            reference_prompt = f"{style}, {prompt_suffix}, {REFERENCE_SUFFIX}"
            reference_bytes = generate_image(client, reference_prompt)
            reference_dest.parent.mkdir(parents=True, exist_ok=True)
            reference_dest.write_bytes(reference_bytes)

        image_rel = character.get("image")
        if image_rel is None:
            raise ValueError(f"script.json character {char_id!r} is missing an image path")

        dest = content_dir / "assets" / image_rel
        if dest.exists() and not force:
            continue

        cutout_bytes = chroma_key(reference_bytes)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(cutout_bytes)
