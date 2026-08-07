#!/usr/bin/env python3
"""CLI for generating a story's image assets via Gemini.

Usage:
    uv run python story_assets_gen.py scenes --slug <slug> \\
        [--only scenes/n1.png] [--force]
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def _content_dir(slug: str) -> Path:
    return REPO_ROOT / "story" / "public" / "content" / slug


def _build_client():
    from dotenv import load_dotenv

    load_dotenv(REPO_ROOT / "publisher" / ".env")
    from google import genai

    return genai.Client(api_key=os.environ["GEMINI_API_KEY"])


def _cmd_scenes(args: argparse.Namespace) -> None:
    from story_assets.generate import run_scenes

    content_dir = _content_dir(args.slug)
    client = _build_client()
    run_scenes(content_dir, client, only=args.only, force=args.force)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate story image assets via Gemini")
    subparsers = parser.add_subparsers(dest="command", required=True)

    scenes_parser = subparsers.add_parser("scenes", help="Generate scene background images")
    scenes_parser.add_argument(
        "--slug", required=True, help="Story slug under story/public/content/"
    )
    scenes_parser.add_argument(
        "--only", default=None, help="Generate only this scene rel_path, e.g. scenes/n1.png"
    )
    scenes_parser.add_argument(
        "--force", action="store_true", help="Overwrite existing files"
    )
    scenes_parser.set_defaults(func=_cmd_scenes)

    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
