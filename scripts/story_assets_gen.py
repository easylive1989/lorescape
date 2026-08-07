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


def _cmd_characters(args: argparse.Namespace) -> None:
    from story_assets.characters import run_characters

    content_dir = _content_dir(args.slug)
    client = _build_client()
    run_characters(content_dir, client, only=args.only, force=args.force)


def _cmd_check(args: argparse.Namespace) -> int:
    from story_assets.check import check_content

    content_dir = _content_dir(args.slug)
    missing = check_content(content_dir)
    if missing:
        print(f"Missing {len(missing)} asset(s):")
        for rel_path in missing:
            print(f"  {rel_path}")
        return 1
    print("All assets present.")
    return 0


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

    characters_parser = subparsers.add_parser(
        "characters", help="Generate character reference + part sprite images"
    )
    characters_parser.add_argument(
        "--slug", required=True, help="Story slug under story/public/content/"
    )
    characters_parser.add_argument(
        "--only",
        default=None,
        help="Generate only this character id, or <id>:<part> "
        "(part is head/torso/leftArm/rightArm), e.g. anne or anne:head",
    )
    characters_parser.add_argument(
        "--force", action="store_true", help="Overwrite existing files"
    )
    characters_parser.set_defaults(func=_cmd_characters)

    check_parser = subparsers.add_parser(
        "check", help="Check that all assets script.json refers to exist"
    )
    check_parser.add_argument(
        "--slug", required=True, help="Story slug under story/public/content/"
    )
    check_parser.set_defaults(func=_cmd_check)

    args = parser.parse_args(argv)
    return args.func(args) or 0


if __name__ == "__main__":
    sys.exit(main())
