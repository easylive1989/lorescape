"""Tests for story_assets.characters — reference + part generation and cutout."""
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
        [
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
        ],
        {"anne": "Anne Boleyn, a queen"},
    )


def test_run_characters_makes_one_reference_and_four_part_calls(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client)

    assert len(client.calls) == 5
    assert (content_dir / "assets" / "characters" / "anne" / "_reference.png").exists()
    for rel_path in (
        "characters/anne/head.png",
        "characters/anne/torso.png",
        "characters/anne/left-arm.png",
        "characters/anne/right-arm.png",
    ):
        dest = content_dir / "assets" / rel_path
        assert dest.exists()
        # cutout ran: result should be smaller than the 10x10 source.
        image = Image.open(dest)
        assert image.size == (4, 4)


def test_run_characters_part_prompt_mentions_only_the_part(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client)

    part_call_prompts = [call["contents"][0] for call in client.calls[1:]]
    assert any("ONLY the head" in prompt for prompt in part_call_prompts)


def test_run_characters_skips_existing_reference_and_only_generates_missing_parts(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    reference_dest = content_dir / "assets" / "characters" / "anne" / "_reference.png"
    reference_dest.parent.mkdir(parents=True)
    reference_dest.write_bytes(b"existing-reference")

    # Pre-populate 3 of the 4 parts; only "torso" is missing.
    for rel_path in (
        "characters/anne/head.png",
        "characters/anne/left-arm.png",
        "characters/anne/right-arm.png",
    ):
        dest = content_dir / "assets" / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(b"existing-part")

    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client)

    assert reference_dest.read_bytes() == b"existing-reference"
    assert len(client.calls) == 1  # only the missing "torso" part
    torso_dest = content_dir / "assets" / "characters" / "anne" / "torso.png"
    assert torso_dest.read_bytes() != b"existing-part"
    # No reference part was appended? Actually reference bytes should be
    # passed as the reference_png for the generate_image call.
    contents = client.calls[0]["contents"]
    assert len(contents) == 2
    assert contents[1].inline_data.data == b"existing-reference"


def test_run_characters_only_filters_to_single_character(tmp_path):
    content_dir = _write_content_dir(
        tmp_path,
        [
            {
                "id": "anne",
                "name": "Anne",
                "parts": {
                    "head": "characters/anne/head.png",
                    "torso": "characters/anne/torso.png",
                    "leftArm": "characters/anne/left-arm.png",
                    "rightArm": "characters/anne/right-arm.png",
                },
            },
            {
                "id": "kingston",
                "name": "Kingston",
                "parts": {
                    "head": "characters/kingston/head.png",
                    "torso": "characters/kingston/torso.png",
                    "leftArm": "characters/kingston/left-arm.png",
                    "rightArm": "characters/kingston/right-arm.png",
                },
            },
        ],
        {"anne": "Anne Boleyn, a queen", "kingston": "William Kingston, a constable"},
    )
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client, only="anne")

    assert not (content_dir / "assets" / "characters" / "kingston").exists()
    assert (content_dir / "assets" / "characters" / "anne" / "_reference.png").exists()
    assert len(client.calls) == 5


def test_run_characters_only_with_part_suffix_generates_single_part(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client, only="anne:head")

    assert len(client.calls) == 2  # reference + head only
    assert (content_dir / "assets" / "characters" / "anne" / "head.png").exists()
    assert not (content_dir / "assets" / "characters" / "anne" / "torso.png").exists()


def test_run_characters_only_with_unknown_id_raises_value_error(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    with pytest.raises(ValueError, match="anne"):
        run_characters(content_dir, client, only="typo")

    assert client.calls == []


def test_run_characters_only_with_unknown_part_raises_value_error_without_calling_client(
    tmp_path,
):
    content_dir = _one_character_content_dir(tmp_path)
    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    with pytest.raises(ValueError, match="head"):
        run_characters(content_dir, client, only="anne:hed")

    # No reference image should have been generated either — the bad part
    # must be rejected before any generation call is made.
    assert client.calls == []
    assert not (content_dir / "assets" / "characters" / "anne" / "_reference.png").exists()


def test_run_characters_force_overwrites_existing_reference_and_parts(tmp_path):
    content_dir = _one_character_content_dir(tmp_path)
    reference_dest = content_dir / "assets" / "characters" / "anne" / "_reference.png"
    reference_dest.parent.mkdir(parents=True)
    reference_dest.write_bytes(b"existing-reference")
    torso_dest = content_dir / "assets" / "characters" / "anne" / "torso.png"
    torso_dest.write_bytes(b"existing-torso")

    client = _FakeClient(_Response([_Part(_magenta_with_center_red_square_png())]))

    run_characters(content_dir, client, force=True)

    assert reference_dest.read_bytes() != b"existing-reference"
    assert torso_dest.read_bytes() != b"existing-torso"
    assert len(client.calls) == 5
