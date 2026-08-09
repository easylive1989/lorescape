import json
from pathlib import Path

from PIL import Image

from story_assets.layout_migrate import migrate, part_bbox_layout


def _canvas_with_box(left, top, w, h, size=(1024, 1536)):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    for x in range(left, left + w):
        for y in range(top, top + h):
            im.putpixel((x, y), (200, 10, 10, 255))
    from io import BytesIO
    buf = BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


def test_part_bbox_layout_計算比例與緊裁():
    png = _canvas_with_box(left=412, top=46, w=200, h=300)
    tight, part = part_bbox_layout(png, (1024, 1536))
    assert abs(part["cx"] - (412 + 100) / 1024) < 1e-6
    assert abs(part["top"] - 46 / 1536) < 1e-6
    assert abs(part["height"] - 300 / 1536) < 1e-6
    from io import BytesIO
    im = Image.open(BytesIO(tight))
    assert im.size == (200, 300)


def test_migrate_寫入_layout_json(tmp_path: Path):
    content = tmp_path
    (content / "assets" / "characters" / "anne").mkdir(parents=True)
    script = {
        "slug": "s", "title": "t", "place": "p", "intro": "i", "startNode": "n1",
        "characters": [{"id": "anne", "name": "安妮", "parts": {
            "head": "characters/anne/head.png", "torso": "characters/anne/torso.png",
            "leftArm": "characters/anne/left-arm.png", "rightArm": "characters/anne/right-arm.png"}}],
        "nodes": [{"id": "n1", "background": "b.png", "paragraphs": ["x"], "ending": {"title": "e"}}],
    }
    (content / "script.json").write_text(json.dumps(script), encoding="utf-8")
    for name, box in {
        "head.png": (412, 46, 200, 300), "torso.png": (300, 300, 400, 1100),
        "left-arm.png": (250, 340, 150, 500), "right-arm.png": (600, 330, 150, 500),
    }.items():
        (content / "assets" / "characters" / "anne" / name).write_bytes(
            _canvas_with_box(*box))
    layout = migrate(content)
    saved = json.loads((content / "layout.json").read_text(encoding="utf-8"))
    assert saved == layout
    assert abs(layout["characters"]["anne"]["head"]["top"] - 46 / 1536) < 1e-6
    im = Image.open(content / "assets" / "characters" / "anne" / "torso.png")
    assert im.size == (400, 1100)


def test_ensure_layout_entry_不覆蓋既有(tmp_path: Path):
    from story_assets.characters import ensure_layout_entry
    ensure_layout_entry(tmp_path, "anne")
    layout = json.loads((tmp_path / "layout.json").read_text(encoding="utf-8"))
    assert "anne" in layout["characters"]
    layout["characters"]["anne"]["head"]["cx"] = 0.42
    (tmp_path / "layout.json").write_text(json.dumps(layout), encoding="utf-8")
    ensure_layout_entry(tmp_path, "anne")
    layout2 = json.loads((tmp_path / "layout.json").read_text(encoding="utf-8"))
    assert layout2["characters"]["anne"]["head"]["cx"] == 0.42
