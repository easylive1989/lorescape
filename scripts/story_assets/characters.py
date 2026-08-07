"""Generate a story's character reference + part sprite images.

For each character: generate one full-body reference image on a solid
magenta background, then use it as a style/likeness reference to generate
each of the four body parts (head, torso, left arm, right arm), chroma-key
them to transparent PNGs, and write them to the paths declared in
script.json's `characters[].parts`.
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

# script.json parts key -> human-readable part name used in the prompt.
PART_LABELS = {
    "head": "head",
    "torso": "torso",
    "leftArm": "left arm",
    "rightArm": "right arm",
}


def _part_prompt(part_label: str) -> str:
    return (
        f"ONLY the {part_label} of this exact character, same style and colors, "
        "nothing else, centered, plain solid magenta background #FF00FF"
    )


def run_characters(
    content_dir: Path,
    client,
    only: str | None = None,
    force: bool = False,
) -> None:
    """Generate reference + part images for each character under `content_dir`.

    Writes `assets/characters/<id>/_reference.png` and each part at the path
    declared in script.json's `characters[].parts`. Existing files are
    skipped unless `force` is set; when the reference already exists it is
    reused (not regenerated) even if some parts are still missing.

    `only` restricts the run to a single character id, optionally scoped to
    one part with `<id>:<part>` (part is one of head/torso/leftArm/rightArm).
    Raises ValueError if `only`'s id matches no character.
    """
    script = json.loads((content_dir / "script.json").read_text(encoding="utf-8"))
    art = json.loads((content_dir / "art.json").read_text(encoding="utf-8"))

    style = art["style"]
    character_prompts: dict[str, str] = art.get("characters", {})
    characters = script.get("characters", [])

    only_part: str | None = None
    if only is not None:
        only_id = only
        if ":" in only:
            only_id, only_part = only.split(":", 1)
        matched = [character for character in characters if character["id"] == only_id]
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

        parts: dict[str, str] = character.get("parts", {})
        for part_key, part_label in PART_LABELS.items():
            if only_part is not None and part_key != only_part:
                continue
            rel_path = parts.get(part_key)
            if rel_path is None:
                continue

            dest = content_dir / "assets" / rel_path
            if dest.exists() and not force:
                continue

            raw_bytes = generate_image(
                client, _part_prompt(part_label), reference_png=reference_bytes
            )
            cutout_bytes = chroma_key(raw_bytes)
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(cutout_bytes)
