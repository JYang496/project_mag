"""Pixelize weapon and projectile sprites without changing their canvas size.

The runtime uses the source canvas dimensions as world-space dimensions, so this
tool performs a logical downsample, palette reduction, hard-alpha cleanup, and a
nearest-neighbour upscale back to the original canvas.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
WEAPON_DIR = ROOT / "asset" / "images" / "weapons"


def _pixel_factor(path: Path, width: int, height: int) -> int:
    if path.parent.name == "projectiles":
        # Tiny bullets are already near their intended logical resolution.
        return 1 if min(width, height) <= 16 else 2
    return 4


def _quantize_rgb(image: Image.Image, colors: int) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    return rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGB")


def pixelize(path: Path) -> None:
    source = Image.open(path).convert("RGBA")
    width, height = source.size
    factor = _pixel_factor(path, width, height)
    logical_size = (max(1, round(width / factor)), max(1, round(height / factor)))

    logical = source.resize(logical_size, Image.Resampling.BOX)
    alpha = logical.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    color_count = 16 if path.parent.name == "projectiles" else 24
    rgb = _quantize_rgb(logical, color_count)
    logical = Image.merge("RGBA", (*rgb.split(), alpha))

    # Transparent pixels carry black RGB to prevent colored import fringes.
    transparent = Image.new("RGBA", logical.size, (0, 0, 0, 0))
    transparent.alpha_composite(logical)
    result = transparent.resize((width, height), Image.Resampling.NEAREST)
    result.save(path, optimize=True)


def main() -> None:
    files = sorted(WEAPON_DIR.glob("*.png"))
    files.extend(sorted((WEAPON_DIR / "projectiles").glob("*.png")))
    for path in files:
        pixelize(path)
        print(path.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
