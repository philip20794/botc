"""Keep PWA icons synchronized with the APK launcher source image.

Run from the repository root: python .github/scripts/sync_pwa_icons.py
Requires Pillow. The generated files are committed so browsers can install
the PWA without needing a post-build task.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/images/app/app_icon.png"
DESTINATION = ROOT / "web/icons"

RESAMPLING = Image.Resampling.LANCZOS


def save_icon(source: Image.Image, size: int, *, maskable: bool) -> None:
    if maskable:
        # Maskable icons need their important artwork inside the center safe
        # zone; Android may crop their outer edges to circles or squircles.
        canvas = Image.new("RGBA", (size, size), "#100C16")
        artwork_size = round(size * 0.78)
        artwork = source.resize((artwork_size, artwork_size), RESAMPLING)
        offset = (size - artwork_size) // 2
        canvas.alpha_composite(artwork, (offset, offset))
        filename = f"Icon-maskable-{size}.png"
    else:
        canvas = source.resize((size, size), RESAMPLING)
        filename = f"Icon-{size}.png"
    canvas.save(DESTINATION / filename, format="PNG", optimize=True)


def main() -> None:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE) as original:
        icon = original.convert("RGBA")
        for size in (192, 512):
            save_icon(icon, size, maskable=False)
            save_icon(icon, size, maskable=True)


if __name__ == "__main__":
    main()
