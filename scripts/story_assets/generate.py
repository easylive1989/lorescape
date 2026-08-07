"""Generate a story's scene background images and write them to assets/."""
from __future__ import annotations

from pathlib import Path

from story_assets.gemini import generate_image
from story_assets.manifest import load_scene_jobs


def run_scenes(
    content_dir: Path,
    client,
    only: str | None = None,
    force: bool = False,
) -> None:
    """Generate each scene job's background image under `content_dir/assets`.

    A job whose destination file already exists is skipped unless `force`
    is set. `only` restricts the run to the job whose `rel_path` matches;
    if nothing matches, raises ValueError listing the available paths.
    """
    jobs = load_scene_jobs(content_dir)
    if only is not None:
        matched = [job for job in jobs if job.rel_path == only]
        if not matched:
            available = ", ".join(job.rel_path for job in jobs)
            raise ValueError(
                f"--only {only!r} matched no scene job; "
                f"available rel_path(s): {available}"
            )
        jobs = matched

    for job in jobs:
        dest = content_dir / "assets" / job.rel_path
        if dest.exists() and not force:
            continue
        image_bytes = generate_image(client, job.prompt)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(image_bytes)
