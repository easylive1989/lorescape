"""Tests for story_assets.characters — reference + full-body generation and cutout."""
from __future__ import annotations

import io
import json

import pytest
from PIL import Image

from story_assets.characters import run_characters
from story_assets.cutout import MAGENTA


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


def _magenta_with_center_red_square_png() -> bytes:
    # 10x10 magenta background with a 4x4 red square centered — chroma_key
    # can cut this out to a valid 4x4 opaque result without raising.
    image = Image.new("RGB", (10, 10), MAGENTA)
    for y in range(3, 7):
        for x in range(3, 7):
            image.putpixel((x, y), (255, 0, 0))
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def _write_content_dir(tmp_path, characters, character_prompts):
    (tmp_path / "script.json").write_text(
        json.dumps({"nodes": [], "characters": characters}), encoding="utf-8"
    )
    (tmp_path / "art.json").write_text(
        json.dumps({"style": "style", "scenes": {}, "characters": character_prompts}),
        encoding="utf-8",
    )
    return tmp_path


def _one_character_content_dir(tmp_path):
    return _write_content_dir(
        tmp_path,
        [{"id": "anne", "name": "Anne", "image": "characters/anne/full.png"}],
        {"anne": "Anne Boleyn, a queen"},
    )


def test_run_characters_makes_one_reference_call_and_writes_reference_and_image(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client)

    assert len(client.calls) == 1
    assert (content_dir / "assets" / "characters" / "anne" / "_reference.png").exists()
    dest = content_dir / "assets" / "characters" / "anne" / "full.png"
    assert dest.exists()
    # cutout ran: result should be smaller than the 10x10 source.
    image = Image.open(dest)
    assert image.size == (4, 4)


def test_run_characters_skips_existing_reference_but_still_writes_missing_image(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    reference_dest = content_dir / "assets" / "characters" / "anne" / "_reference.png"
    reference_dest.parent.mkdir(parents=True)
    reference_dest.write_bytes(_magenta_with_center_red_square_png())

    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client)

    assert reference_dest.read_bytes() == _magenta_with_center_red_square_png()
    assert client.calls == []  # reference reused, no generation call needed
    image_dest = content_dir / "assets" / "characters" / "anne" / "full.png"
    assert image_dest.exists()


def test_run_characters_skips_existing_image(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    image_dest = content_dir / "assets" / "characters" / "anne" / "full.png"
    image_dest.parent.mkdir(parents=True)
    image_dest.write_bytes(b"existing-image")

    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client)

    assert image_dest.read_bytes() == b"existing-image"
    assert len(client.calls) == 1  # still needs to generate the reference


def test_run_characters_only_filters_to_single_character(tmp_path):
    content_dir = _write_content_dir(
        tmp_path,
        [
            {"id": "anne", "name": "Anne", "image": "characters/anne/full.png"},
            {"id": "kingston", "name": "Kingston", "image": "characters/kingston/full.png"},
        ],
        {"anne": "Anne Boleyn, a queen", "kingston": "William Kingston, a constable"},
    )
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client, only="anne")

    assert not (content_dir / "assets" / "characters" / "kingston").exists()
    assert (content_dir / "assets" / "characters" / "anne" / "_reference.png").exists()
    assert len(client.calls) == 1


def test_run_characters_only_with_unknown_id_raises_value_error(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    with pytest.raises(ValueError, match="anne"):
        run_characters(content_dir, client, only="typo")

    assert client.calls == []


def test_run_characters_force_overwrites_existing_reference_and_image(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    reference_dest = content_dir / "assets" / "characters" / "anne" / "_reference.png"
    reference_dest.parent.mkdir(parents=True)
    reference_dest.write_bytes(_magenta_with_center_red_square_png())
    image_dest = content_dir / "assets" / "characters" / "anne" / "full.png"
    image_dest.write_bytes(b"existing-image")

    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client, force=True)

    assert len(client.calls) == 1
    assert image_dest.read_bytes() != b"existing-image"
