"""Pixelize combat VFX textures while preserving runtime canvas dimensions."""

from __future__ import annotations

from io import BytesIO
from pathlib import Path
import subprocess

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
EFFECT_DIR = ROOT / "asset" / "images" / "effects"
ALPHA_STEPS = (0, 80, 144, 208, 255)


def _factor(path: Path) -> int:
    return 2 if path.parent == EFFECT_DIR else 4


def _quantize_alpha(alpha: Image.Image) -> Image.Image:
    return alpha.point(lambda value: min(ALPHA_STEPS, key=lambda step: abs(step - value)))


def _load_baseline(path: Path) -> Image.Image:
    relative = path.relative_to(ROOT).as_posix()
    try:
        blob = subprocess.check_output(
            ["git", "show", f"HEAD:{relative}"], cwd=ROOT, stderr=subprocess.DEVNULL
        )
        return Image.open(BytesIO(blob)).convert("RGBA")
    except subprocess.CalledProcessError:
        return Image.open(path).convert("RGBA")


def pixelize(path: Path) -> None:
    source = _load_baseline(path)
    width, height = source.size
    factor = _factor(path)
    logical_size = (max(1, round(width / factor)), max(1, round(height / factor)))
    logical = source.resize(logical_size, Image.Resampling.BOX)

    alpha = _quantize_alpha(logical.getchannel("A"))
    rgb = logical.convert("RGB")
    transparent_mask = alpha.point(lambda value: 255 if value == 0 else 0)
    rgb.paste((0, 0, 0), mask=transparent_mask)
    palette_size = 20 if path.parent.name == "explosion" else 16
    rgb = rgb.quantize(colors=palette_size, method=Image.Quantize.MEDIANCUT).convert("RGB")
    logical = Image.merge("RGBA", (*rgb.split(), alpha))
    result = logical.resize((width, height), Image.Resampling.NEAREST)
    result.save(path, optimize=True)


def main() -> None:
    files = sorted(EFFECT_DIR.rglob("*.png"))
    for path in files:
        pixelize(path)
        print(path.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
