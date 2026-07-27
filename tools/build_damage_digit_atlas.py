from pathlib import Path

from PIL import Image


GLYPHS = {
    "0": ("01110", "10001", "10011", "10101", "11001", "10001", "01110"),
    "1": ("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
    "2": ("01110", "10001", "00001", "00010", "00100", "01000", "11111"),
    "3": ("11110", "00001", "00001", "01110", "00001", "00001", "11110"),
    "4": ("00010", "00110", "01010", "10010", "11111", "00010", "00010"),
    "5": ("11111", "10000", "10000", "11110", "00001", "00001", "11110"),
    "6": ("01110", "10000", "10000", "11110", "10001", "10001", "01110"),
    "7": ("11111", "00001", "00010", "00100", "01000", "01000", "01000"),
    "8": ("01110", "10001", "10001", "01110", "10001", "10001", "01110"),
    "9": ("01110", "10001", "10001", "01111", "00001", "00001", "01110"),
    "+": ("00000", "00100", "00100", "11111", "00100", "00100", "00000"),
    "-": ("00000", "00000", "00000", "11111", "00000", "00000", "00000"),
    "!": ("00100", "00100", "00100", "00100", "00100", "00000", "00100"),
}

CELL_WIDTH = 8
CELL_HEIGHT = 12
ORDER = "0123456789+-!"


def main() -> None:
    output = Path(__file__).resolve().parents[1] / "UI/labels/assets/damage_digits_12px.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (CELL_WIDTH * len(ORDER), CELL_HEIGHT), (0, 0, 0, 0))
    pixels = atlas.load()
    for glyph_index, glyph in enumerate(ORDER):
        rows = GLYPHS[glyph]
        origin_x = glyph_index * CELL_WIDTH + 1
        origin_y = 2
        for y, row in enumerate(rows):
            for x, value in enumerate(row):
                if value == "1":
                    pixels[origin_x + x, origin_y + y] = (255, 255, 255, 255)
    atlas.save(output, optimize=False)
    print(f"Wrote {output} ({atlas.width}x{atlas.height}, 12px cells)")


if __name__ == "__main__":
    main()
