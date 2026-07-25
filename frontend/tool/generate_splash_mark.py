#!/usr/bin/env python3
"""Regenerate the native-splash mark asset.

The native splash (flutter_native_splash `image`) is intentionally a fully
transparent image so the Android 12 splash shows only the paper `SPLASH_BG`
with no icon — a blank paper screen during `init()`. The Flutter SplashScreen
then plays the full Claude Design build-up (mountain draws in → fill/snow fade
→ footprints pop → wordmark), drawn entirely with SplashMarkPainter (no image
asset). A transparent icon is required because the Android 12 SplashScreen API
would otherwise fall back to the launcher icon.

Run from the repo root:  python3 frontend/tool/generate_splash_mark.py
Requires Pillow.
"""
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "frontend" / "assets" / "images" / "splash_mark.png"
SIZE = 512
SPLASH_BG = "#F7F1E6"  # paper; keep in sync with pubspec + SplashScreen bg


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)).save(OUT)
    print(f"wrote transparent {OUT.relative_to(REPO)} ({SIZE}x{SIZE}); splash bg {SPLASH_BG}")


if __name__ == "__main__":
    main()
