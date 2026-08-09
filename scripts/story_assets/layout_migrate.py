"""把 registered 全畫布部件 PNG 裁回緊裁圖，並以其 bbox 產出 layout.json。"""
from __future__ import annotations

import json
from io import BytesIO
from pathlib import Path

from PIL import Image

PART_KEYS = ("head", "torso", "leftArm", "rightArm")
CANVAS = (1024, 1536)


def part_bbox_layout(png_bytes: bytes, canvas: tuple[int, int]) -> tuple[bytes, dict]:
    im = Image.open(BytesIO(png_bytes)).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("部件圖全透明，無法遷移")
    left, top, right, bottom = bbox
    w, h = right - left, bottom - top
    cw, ch = canvas
    part = {
        "cx": (left + w / 2) / cw,
        "top": top / ch,
        "height": h / ch,
    }
    buf = BytesIO()
    im.crop(bbox).save(buf, "PNG")
    return buf.getvalue(), part


def migrate(content_dir: Path) -> dict:
    script = json.loads((content_dir / "script.json").read_text(encoding="utf-8"))
    characters: dict[str, dict] = {}
    for character in script["characters"]:
        parts: dict[str, dict] = {}
        for key in PART_KEYS:
            rel = character["parts"][key]
            dest = content_dir / "assets" / rel
            tight, part = part_bbox_layout(dest.read_bytes(), CANVAS)
            dest.write_bytes(tight)
            parts[key] = part
        characters[character["id"]] = parts
    layout = {"canvas": {"width": CANVAS[0], "height": CANVAS[1]}, "characters": characters}
    (content_dir / "layout.json").write_text(
        json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return layout
