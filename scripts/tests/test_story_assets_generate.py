"""Tests for story_assets.generate — writing generated scene images to assets/."""
from __future__ import annotations

import json

import pytest

from story_assets.gemini import generate_image
from story_assets.generate import run_scenes


class _InlineData:
    def __init__(self, data: bytes) -> None:
        self.data = data


class _Part:
    def __init__(self, data: bytes | None) -> None:
        self.inline_data = _InlineData(data) if data is not None else None


class _Content:
    def __init__(self, parts) -> None:
        self.parts = parts


class _Candidate:
    def __init__(self, parts) -> None:
        self.content = _Content(parts)


class _Response:
    def __init__(self, parts) -> None:
        self.candidates = [_Candidate(parts)]


class _FakeModels:
    def __init__(self, response, calls) -> None:
        self._response = response
        self._calls = calls

    def generate_content(self, **kwargs):
        self._calls.append(kwargs)
        return self._response


class _FakeClient:
    def __init__(self, response) -> None:
        self.calls: list = []
        self.models = _FakeModels(response, self.calls)


def _write_content_dir(tmp_path, nodes, scenes):
    (tmp_path / "script.json").write_text(json.dumps({"nodes": nodes}), encoding="utf-8")
    (tmp_path / "art.json").write_text(
        json.dumps({"style": "style", "scenes": scenes, "characters": {}}),
        encoding="utf-8",
    )
    return tmp_path


def test_run_scenes_writes_generated_image_bytes(tmp_path):
    content_dir = _write_content_dir(
        tmp_path,
        [{"id": "n1", "background": "scenes/a.png"}],
        {"scenes/a.png": "a street"},
    )
    client = _FakeClient(_Response([_Part(b"png")]))

    run_scenes(content_dir, client)

    written = (content_dir / "assets" / "scenes" / "a.png").read_bytes()
    assert written == b"png"
    assert len(client.calls) == 1


def test_run_scenes_skips_existing_file_without_calling_client(tmp_path):
    content_dir = _write_content_dir(
        tmp_path,
        [{"id": "n1", "background": "scenes/a.png"}],
        {"scenes/a.png": "a street"},
    )
    dest = content_dir / "assets" / "scenes" / "a.png"
    dest.parent.mkdir(parents=True)
    dest.write_bytes(b"existing")
    client = _FakeClient(_Response([_Part(b"png")]))

    run_scenes(content_dir, client)

    assert dest.read_bytes() == b"existing"
    assert client.calls == []


def test_run_scenes_force_overwrites_existing_file(tmp_path):
    content_dir = _write_content_dir(
        tmp_path,
        [{"id": "n1", "background": "scenes/a.png"}],
        {"scenes/a.png": "a street"},
    )
    dest = content_dir / "assets" / "scenes" / "a.png"
    dest.parent.mkdir(parents=True)
    dest.write_bytes(b"existing")
    client = _FakeClient(_Response([_Part(b"png")]))

    run_scenes(content_dir, client, force=True)

    assert dest.read_bytes() == b"png"
    assert len(client.calls) == 1


def test_run_scenes_only_filters_to_single_rel_path(tmp_path):
    content_dir = _write_content_dir(
        tmp_path,
        [
            {"id": "n1", "background": "scenes/a.png"},
            {"id": "n2", "background": "scenes/b.png"},
        ],
        {"scenes/a.png": "a street", "scenes/b.png": "a wharf"},
    )
    client = _FakeClient(_Response([_Part(b"png")]))

    run_scenes(content_dir, client, only="scenes/b.png")

    assert not (content_dir / "assets" / "scenes" / "a.png").exists()
    assert (content_dir / "assets" / "scenes" / "b.png").read_bytes() == b"png"
    assert len(client.calls) == 1


def test_generate_image_raises_when_no_inline_data():
    client = _FakeClient(_Response([_Part(None)]))

    with pytest.raises(RuntimeError):
        generate_image(client, "prompt")
