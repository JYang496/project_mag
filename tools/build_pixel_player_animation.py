"""Build the 128x128 pixel player idle and locomotion frames."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CHARACTER_DIR = ROOT / "asset" / "images" / "characters"
OUTPUT_DIR = CHARACTER_DIR / "pixel"
KEY_FRAME_INDICES = (1, 4, 7, 10, 12, 15, 18, 21)
CANVAS_SIZE = (128, 128)
TARGET_HEIGHT = 104
BASELINE_Y = 114


def _pixel_sprite(source_path: Path) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    alpha = source.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"Source frame is empty: {source_path}")
    cropped = source.crop(bounds)
    scale = min(TARGET_HEIGHT / cropped.height, 116 / cropped.width)
    target_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    sprite = cropped.resize(target_size, Image.Resampling.BOX)
    hard_alpha = sprite.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    rgb = sprite.convert("RGB")
    transparent_mask = hard_alpha.point(lambda value: 255 if value == 0 else 0)
    rgb.paste((0, 0, 0), mask=transparent_mask)
    rgb = rgb.quantize(colors=32, method=Image.Quantize.MEDIANCUT).convert("RGB")
    sprite = Image.merge("RGBA", (*rgb.split(), hard_alpha))

    # Thresholding can remove a faint source edge; crop again so every frame
    # is aligned from its final opaque pixels rather than its source bounds.
    final_bounds = sprite.getchannel("A").getbbox()
    if final_bounds is None:
        raise ValueError(f"Pixel frame became empty: {source_path}")
    sprite = sprite.crop(final_bounds)

    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    x = (CANVAS_SIZE[0] - sprite.width) // 2
    y = BASELINE_Y - sprite.height
    canvas.alpha_composite(sprite, (x, y))
    return canvas


def _save(source_path: Path, output_name: str) -> None:
    output_path = OUTPUT_DIR / output_name
    output_path.parent.mkdir(parents=True, exist_ok=True)
    _pixel_sprite(source_path).save(output_path, optimize=True)
    print(output_path.relative_to(ROOT).as_posix())


def main() -> None:
    _save(CHARACTER_DIR / "2f.png", "idle_bottom.png")
    _save(CHARACTER_DIR / "2b.png", "idle_top.png")
    for output_index, source_index in enumerate(KEY_FRAME_INDICES, start=1):
        _save(
            CHARACTER_DIR / "move_f" / f"move_forward_{source_index:03d}.png",
            f"move_bottom_{output_index:02d}.png",
        )
        _save(
            CHARACTER_DIR / "move_b" / f"move_back_{source_index:03d}.png",
            f"move_top_{output_index:02d}.png",
        )


if __name__ == "__main__":
    main()
