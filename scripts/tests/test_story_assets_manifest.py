"""Tests for story_assets.manifest — building SceneJobs from script.json + art.json."""
from __future__ import annotations

import json

import pytest

from story_assets.manifest import SceneJob, load_scene_jobs


def _write_script(content_dir, nodes):
    (content_dir / "script.json").write_text(
        json.dumps({"nodes": nodes}), encoding="utf-8"
    )


def _write_art(content_dir, style, scenes):
    (content_dir / "art.json").write_text(
        json.dumps({"style": style, "scenes": scenes, "characters": {}}),
        encoding="utf-8",
    )


def test_returns_scene_job_per_unique_background_with_composed_prompt(tmp_path):
    _write_script(
        tmp_path,
        [
            {"id": "n1", "background": "scenes/a.png"},
            {"id": "n2", "background": "scenes/b.png"},
        ],
    )
    _write_art(
        tmp_path,
        style="cel-shaded illustration",
        scenes={
            "scenes/a.png": "a street at dusk",
            "scenes/b.png": "a river wharf",
        },
    )

    jobs = load_scene_jobs(tmp_path)

    assert jobs == [
        SceneJob(
            rel_path="scenes/a.png",
            prompt="cel-shaded illustration, a street at dusk",
        ),
        SceneJob(
            rel_path="scenes/b.png",
            prompt="cel-shaded illustration, a river wharf",
        ),
    ]


def test_duplicate_background_across_nodes_yields_one_job(tmp_path):
    _write_script(
        tmp_path,
        [
            {"id": "n1", "background": "scenes/a.png"},
            {"id": "n2", "background": "scenes/a.png"},
        ],
    )
    _write_art(tmp_path, style="style", scenes={"scenes/a.png": "a street"})

    jobs = load_scene_jobs(tmp_path)

    assert jobs == [SceneJob(rel_path="scenes/a.png", prompt="style, a street")]


def test_missing_prompt_for_background_raises_value_error(tmp_path):
    _write_script(
        tmp_path,
        [
            {"id": "n1", "background": "scenes/a.png"},
            {"id": "n2", "background": "scenes/b.png"},
        ],
    )
    _write_art(tmp_path, style="style", scenes={"scenes/a.png": "a street"})

    with pytest.raises(ValueError, match="scenes/b.png"):
        load_scene_jobs(tmp_path)


def test_extra_scene_prompt_with_no_matching_background_raises_value_error(tmp_path):
    _write_script(tmp_path, [{"id": "n1", "background": "scenes/a.png"}])
    _write_art(
        tmp_path,
        style="style",
        scenes={"scenes/a.png": "a street", "scenes/orphan.png": "unused"},
    )

    with pytest.raises(ValueError, match="scenes/orphan.png"):
        load_scene_jobs(tmp_path)
