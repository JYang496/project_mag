"""Pixelize dedicated loot sprites and rest-area world props reproducibly."""

from __future__ import annotations

from io import BytesIO
from pathlib import Path
import subprocess

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
LOOT_DIR = ROOT / "asset" / "images" / "loot"
REST_PROP_DIR = ROOT / "asset" / "images" / "ui" / "rest_area"


def _load_baseline(path: Path) -> Image.Image:
    relative = path.relative_to(ROOT).as_posix()
    try:
        blob = subprocess.check_output(
            ["git", "show", f"HEAD:{relative}"], cwd=ROOT, stderr=subprocess.DEVNULL
        )
        return Image.open(BytesIO(blob)).convert("RGBA")
    except subprocess.CalledProcessError:
        return Image.open(path).convert("RGBA")


def _logical_size(path: Path, size: tuple[int, int]) -> tuple[int, int]:
    width, height = size
    if path.parent == REST_PROP_DIR:
        return (128, 128)
    if max(width, height) > 32:
        return (max(1, round(width / 2)), max(1, round(height / 2)))
    return size


def pixelize(path: Path) -> None:
    source = _load_baseline(path)
    original_size = source.size
    logical = source.resize(_logical_size(path, original_size), Image.Resampling.BOX)
    alpha = logical.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    rgb = logical.convert("RGB")
    transparent_mask = alpha.point(lambda value: 255 if value == 0 else 0)
    rgb.paste((0, 0, 0), mask=transparent_mask)
    palette_size = 32 if path.parent == REST_PROP_DIR else 20
    rgb = rgb.quantize(colors=palette_size, method=Image.Quantize.MEDIANCUT).convert("RGB")
    logical = Image.merge("RGBA", (*rgb.split(), alpha))
    logical.resize(original_size, Image.Resampling.NEAREST).save(path, optimize=True)


def main() -> None:
    files = sorted(LOOT_DIR.glob("*.png")) + sorted(REST_PROP_DIR.glob("*.png"))
    for path in files:
        pixelize(path)
        print(path.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
