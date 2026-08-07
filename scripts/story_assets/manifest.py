"""Build scene image-generation jobs from a story's script.json + art.json."""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


@dataclass
class SceneJob:
    """One scene background image to generate.

    `rel_path` is the destination relative to the content dir's `assets/`
    (e.g. "scenes/n1.png"), also used as the key in art.json's "scenes".
    `prompt` is the fully composed prompt (art.json "style" + scene prompt).
    """

    rel_path: str
    prompt: str


def load_scene_jobs(content_dir: Path) -> list[SceneJob]:
    """Read `script.json` + `art.json` under `content_dir` into SceneJobs.

    Collects every unique `node.background` referenced by script.json (in
    order of first appearance) and pairs it with its prompt from art.json's
    "scenes". Raises ValueError if a referenced background has no prompt in
    art.json, or if art.json has scene prompts for backgrounds no node
    references.
    """
    script = json.loads((content_dir / "script.json").read_text(encoding="utf-8"))
    art = json.loads((content_dir / "art.json").read_text(encoding="utf-8"))

    style = art["style"]
    scene_prompts: dict[str, str] = art.get("scenes", {})

    backgrounds: list[str] = []
    seen: set[str] = set()
    for node in script.get("nodes", []):
        background = node.get("background")
        if background and background not in seen:
            seen.add(background)
            backgrounds.append(background)

    missing = [bg for bg in backgrounds if bg not in scene_prompts]
    if missing:
        raise ValueError(
            "art.json is missing scene prompt(s) for background(s): "
            + ", ".join(missing)
        )

    orphaned = [key for key in scene_prompts if key not in seen]
    if orphaned:
        raise ValueError(
            "art.json has scene prompt(s) with no matching background: "
            + ", ".join(orphaned)
        )

    return [
        SceneJob(rel_path=bg, prompt=f"{style}, {scene_prompts[bg]}")
        for bg in backgrounds
    ]
