"""Build the modular floating-board front-skirt atlas and assembly previews.

The atlas is intentionally deterministic: every 64x64 tile shares the same
connection profile, so nearest-filtered runtime quads cannot reveal seams.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = PROJECT_ROOT / "Visual" / "Oblique" / "assets" / "board_support"
PREVIEW_DIR = PROJECT_ROOT / "Visual" / "Oblique" / "concepts" / "board_support"
ATLAS_PATH = ASSET_DIR / "floating_board_skirt_atlas.png"
LAYOUT_PATH = ASSET_DIR / "floating_board_skirt_atlas.layout.json"

TILE_SIZE = 64
ATLAS_SIZE = 256
MODULES = {
    "left_cap": (0, 0),
    "plain_middle": (1, 0),
    "seam_middle": (2, 0),
    "detail_middle_a": (3, 0),
    "detail_middle_b": (0, 1),
    "right_cap": (1, 1),
}

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (8, 13, 19, 255)
DEEP = (15, 23, 31, 255)
SHADOW = (24, 34, 43, 255)
MID = (42, 54, 64, 255)
LIGHT = (75, 88, 98, 255)
TOP = (104, 116, 124, 255)
CYAN_DARK = (8, 79, 102, 255)
CYAN = (12, 189, 224, 255)


def _rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color: tuple[int, int, int, int]) -> None:
    draw.rectangle(box, fill=color)


def _base_middle(draw: ImageDraw.ImageDraw) -> None:
    # Straight shared profile at x=0 and x=63 is identical for every middle tile.
    _rect(draw, (0, 4, 63, 8), OUTLINE)
    _rect(draw, (0, 5, 63, 6), TOP)
    _rect(draw, (0, 7, 63, 10), LIGHT)
    _rect(draw, (0, 11, 63, 14), OUTLINE)
    _rect(draw, (0, 15, 63, 18), SHADOW)
    _rect(draw, (0, 19, 63, 47), MID)
    _rect(draw, (0, 20, 63, 23), SHADOW)
    _rect(draw, (0, 44, 63, 49), DEEP)
    _rect(draw, (0, 50, 63, 53), OUTLINE)
    _rect(draw, (0, 51, 63, 51), LIGHT)


def _draw_module(name: str) -> Image.Image:
    image = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), TRANSPARENT)
    draw = ImageDraw.Draw(image)
    _base_middle(draw)

    if name == "left_cap":
        draw.polygon([(0, 4), (10, 4), (10, 53), (0, 45)], fill=OUTLINE)
        draw.polygon([(1, 9), (10, 6), (10, 49), (2, 43)], fill=LIGHT)
        draw.polygon([(5, 18), (18, 18), (25, 48), (10, 48)], fill=SHADOW)
        draw.line([(10, 18), (20, 48)], fill=OUTLINE, width=2)
    elif name == "right_cap":
        draw.polygon([(53, 4), (63, 4), (63, 45), (53, 53)], fill=OUTLINE)
        draw.polygon([(53, 6), (62, 9), (61, 43), (53, 49)], fill=LIGHT)
        draw.polygon([(39, 48), (46, 18), (58, 18), (53, 48)], fill=SHADOW)
        draw.line([(53, 18), (43, 48)], fill=OUTLINE, width=2)
    elif name == "seam_middle":
        _rect(draw, (29, 15, 34, 53), OUTLINE)
        _rect(draw, (31, 16, 32, 48), LIGHT)
        _rect(draw, (27, 20, 28, 45), DEEP)
        _rect(draw, (35, 20, 36, 45), DEEP)
    elif name == "detail_middle_a":
        draw.line([(18, 23), (24, 29), (24, 43)], fill=OUTLINE, width=2)
        draw.line([(46, 23), (40, 29), (40, 43)], fill=OUTLINE, width=2)
        _rect(draw, (25, 28, 39, 34), DEEP)
        _rect(draw, (27, 29, 37, 30), CYAN_DARK)
        _rect(draw, (28, 30, 36, 31), CYAN)
    elif name == "detail_middle_b":
        draw.line([(18, 23), (23, 30), (23, 44)], fill=OUTLINE, width=2)
        draw.line([(46, 23), (41, 30), (41, 44)], fill=OUTLINE, width=2)
        for x in (28, 32, 36):
            _rect(draw, (x, 29, x + 1, 35), CYAN_DARK)
            _rect(draw, (x, 30, x + 1, 33), CYAN)
    else:
        _rect(draw, (30, 31, 33, 33), DEEP)
        _rect(draw, (31, 31, 32, 31), CYAN_DARK)

    return image


def _assembly_sequence(board_count: int) -> list[str]:
    module_count = board_count * 4
    sequence: list[str] = []
    for index in range(module_count):
        if index == 0:
            sequence.append("left_cap")
        elif index == module_count - 1:
            sequence.append("right_cap")
        elif index % 4 == 0:
            sequence.append("seam_middle")
        elif index % 4 == 2:
            sequence.append("detail_middle_a" if (index // 4) % 2 == 0 else "detail_middle_b")
        else:
            sequence.append("plain_middle")
    return sequence


def _build_preview(board_count: int, tiles: dict[str, Image.Image]) -> None:
    sequence = _assembly_sequence(board_count)
    width = len(sequence) * TILE_SIZE
    image = Image.new("RGBA", (width, 112), (2, 7, 14, 255))
    draw = ImageDraw.Draw(image)
    # A small board-top strip demonstrates that the skirt reads as an underside.
    _rect(draw, (0, 0, width - 1, 25), (38, 50, 59, 255))
    for x in range(0, width, TILE_SIZE):
        _rect(draw, (x, 0, min(x + TILE_SIZE - 2, width - 1), 3), (82, 96, 105, 255))
        _rect(draw, (x + 3, 9, min(x + TILE_SIZE - 5, width - 1), 22), (47, 60, 69, 255))
        _rect(draw, (min(x + TILE_SIZE - 3, width - 1), 4, min(x + TILE_SIZE - 1, width - 1), 25), (8, 13, 19, 255))
    for index, name in enumerate(sequence):
        image.alpha_composite(tiles[name], (index * TILE_SIZE, 22))
    # Sparse falling data packets are preview-only and are not part of the skirt atlas.
    for index in range(board_count * 3):
        x = (index * 97 + 31) % width
        y = 88 + (index * 7) % 18
        _rect(draw, (x, y, x + 1, y + 2), CYAN_DARK if index % 2 else CYAN)
    image.save(PREVIEW_DIR / f"floating_board_skirt_{board_count}x_preview.png")


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), TRANSPARENT)
    tiles: dict[str, Image.Image] = {}
    for name, (column, row) in MODULES.items():
        tile = _draw_module(name)
        tiles[name] = tile
        atlas.alpha_composite(tile, (column * TILE_SIZE, row * TILE_SIZE))
    atlas.save(ATLAS_PATH)
    for board_count in (1, 2, 3):
        _build_preview(board_count, tiles)
    layout = {
        "atlas_size": [ATLAS_SIZE, ATLAS_SIZE],
        "tile_size": [TILE_SIZE, TILE_SIZE],
        "logical_module_width": 128,
        "modules_per_512_unit_board": 4,
        "modules": {name: {"column": cell[0], "row": cell[1]} for name, cell in MODULES.items()},
        "assembly_examples": {str(count): _assembly_sequence(count) for count in (1, 2, 3)},
        "rules": [
            "Use left_cap and right_cap exactly once per exposed bottom segment.",
            "Use seam_middle at each 512 logical-unit board junction.",
            "Plain and detail middle modules share an identical edge profile and may alternate.",
            "Never scale the source atlas with linear filtering or generate mipmaps.",
        ],
    }
    LAYOUT_PATH.write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
