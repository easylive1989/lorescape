"""Tests for story_assets.check — verifying script.json's assets all exist."""
from __future__ import annotations

import json

from story_assets.check import check_content

_CHARACTERS = [
    {
        "id": "anne",
        "name": "Anne",
        "parts": {
            "head": "characters/anne/head.png",
            "torso": "characters/anne/torso.png",
            "leftArm": "characters/anne/left-arm.png",
            "rightArm": "characters/anne/right-arm.png",
        },
    }
]

_NODES = [
    {"id": "n1", "background": "scenes/a.png", "bgm": "audio/main.mp3"},
    {"id": "n2", "background": "scenes/b.png"},
]


def _write_script(content_dir, nodes=_NODES, characters=_CHARACTERS):
    (content_dir / "script.json").write_text(
        json.dumps({"nodes": nodes, "characters": characters}), encoding="utf-8"
    )


def _touch(content_dir, rel_path):
    dest = content_dir / "assets" / rel_path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(b"x")


def _write_all_assets(content_dir, nodes=_NODES, characters=_CHARACTERS):
    for node in nodes:
        background = node.get("background")
        if background:
            _touch(content_dir, background)
        bgm = node.get("bgm")
        if bgm:
            _touch(content_dir, bgm)
    for character in characters:
        for rel_path in character["parts"].values():
            _touch(content_dir, rel_path)


def test_all_assets_present_returns_empty_list(tmp_path):
    _write_script(tmp_path)
    _write_all_assets(tmp_path)

    assert check_content(tmp_path) == []


def test_missing_character_part_file_is_reported(tmp_path):
    _write_script(tmp_path)
    _write_all_assets(tmp_path)
    (tmp_path / "assets" / "characters" / "anne" / "torso.png").unlink()

    missing = check_content(tmp_path)

    assert missing == ["characters/anne/torso.png"]


def test_missing_background_is_reported(tmp_path):
    _write_script(tmp_path)
    _write_all_assets(tmp_path)
    (tmp_path / "assets" / "scenes" / "a.png").unlink()

    missing = check_content(tmp_path)

    assert missing == ["scenes/a.png"]


def test_missing_bgm_is_reported(tmp_path):
    _write_script(tmp_path)
    _write_all_assets(tmp_path)
    (tmp_path / "assets" / "audio" / "main.mp3").unlink()

    missing = check_content(tmp_path)

    assert missing == ["audio/main.mp3"]


def test_node_without_bgm_does_not_require_audio_file(tmp_path):
    # n2 has no "bgm" key at all; nothing should be required for it.
    _write_script(tmp_path)
    _write_all_assets(tmp_path)

    assert check_content(tmp_path) == []


def test_multiple_missing_files_are_all_reported(tmp_path):
    _write_script(tmp_path)
    _write_all_assets(tmp_path)
    (tmp_path / "assets" / "scenes" / "a.png").unlink()
    (tmp_path / "assets" / "audio" / "main.mp3").unlink()
    (tmp_path / "assets" / "characters" / "anne" / "head.png").unlink()

    missing = check_content(tmp_path)

    assert set(missing) == {
        "scenes/a.png",
        "audio/main.mp3",
        "characters/anne/head.png",
    }
    assert len(missing) == 3
