"""Check that all assets a story's script.json refers to exist on disk."""
from __future__ import annotations

import json
from pathlib import Path


def check_content(content_dir: Path) -> list[str]:
    """Return the list of asset paths script.json references but that are
    missing under `content_dir/assets/`.

    Checks every node's `background` (always required) and `bgm` (only
    when set — a node with no bgm requires no audio file), plus every
    character's four `parts` paths. Returned paths are relative to
    `assets/`, in first-seen order, with no duplicates. An empty list
    means the content directory is complete.
    """
    script = json.loads((content_dir / "script.json").read_text(encoding="utf-8"))
    assets_dir = content_dir / "assets"

    required: list[str] = []
    seen: set[str] = set()

    def _require(rel_path: str | None) -> None:
        if rel_path and rel_path not in seen:
            seen.add(rel_path)
            required.append(rel_path)

    for node in script.get("nodes", []):
        _require(node.get("background"))
        _require(node.get("bgm"))

    for character in script.get("characters", []):
        for rel_path in character.get("parts", {}).values():
            _require(rel_path)

    return [rel_path for rel_path in required if not (assets_dir / rel_path).exists()]
