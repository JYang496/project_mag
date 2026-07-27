"""Build the scalable-looking modern combat HUD textures.

The runtime sizes are exactly half of these source textures. Rendering at 2x and
using linear mipmapped sampling keeps diagonal cuts, arcs, and glow edges smooth.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "UI" / "themes" / "modern"
FONT = ROOT / "asset" / "fonts" / "NotoSansSC-Regular.ttf"


def _cut_box(box: tuple[int, int, int, int], cut: int) -> list[tuple[int, int]]:
    left, top, right, bottom = box
    return [
        (left + cut, top),
        (right - cut, top),
        (right, top + cut),
        (right, bottom - cut),
        (right - cut, bottom),
        (left + cut, bottom),
        (left, bottom - cut),
        (left, top + cut),
    ]


def _vertical_gradient(size: tuple[int, int], top: tuple[int, ...], bottom: tuple[int, ...]) -> Image.Image:
    image = Image.new("RGBA", size)
    pixels = image.load()
    height = max(size[1] - 1, 1)
    for y in range(size[1]):
        t = y / height
        color = tuple(round(top[i] * (1.0 - t) + bottom[i] * t) for i in range(4))
        for x in range(size[0]):
            pixels[x, y] = color
    return image


def _glow_line(image: Image.Image, points: list[tuple[int, int]], color: tuple[int, int, int, int], width: int, blur: int) -> None:
    glow = Image.new("RGBA", image.size)
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.line(points, fill=color, width=width, joint="curve")
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(blur)))
    ImageDraw.Draw(image).line(points, fill=color, width=max(1, width // 2), joint="curve")


def _make_weapon_slot(size: tuple[int, int], main: bool) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size)
    draw = ImageDraw.Draw(image)
    outer_cut = 14 if main else 12
    draw.polygon(_cut_box((4, 4, width - 5, height - 5), outer_cut), fill=(1, 7, 11, 225), outline=(8, 20, 27, 255), width=7)
    inner_box = (9, 9, width - 10, height - 10)
    inner_cut = 11 if main else 10
    mask = Image.new("L", size)
    ImageDraw.Draw(mask).polygon(_cut_box(inner_box, inner_cut), fill=255)
    panel = _vertical_gradient(size, (15, 43, 56, 250), (2, 9, 14, 252))
    image.alpha_composite(Image.composite(panel, Image.new("RGBA", size), mask))
    draw = ImageDraw.Draw(image)
    draw.line(_cut_box(inner_box, inner_cut) + [_cut_box(inner_box, inner_cut)[0]], fill=(66, 203, 229, 242), width=3, joint="curve")
    inset = (15, 15, width - 16, height - 16)
    inset_cut = 9 if main else 8
    draw.line(_cut_box(inset, inset_cut) + [_cut_box(inset, inset_cut)[0]], fill=(25, 76, 91, 235), width=2, joint="curve")
    mid = width // 2
    top_points = [(22, 12), (mid - 22, 12), (mid - 15, 18), (mid + 15, 18), (mid + 22, 12), (width - 23, 12)]
    _glow_line(image, top_points, (93, 232, 250, 210), 5, 5)
    if main:
        bottom_points = [(25, height - 12), (mid - 23, height - 12), (mid - 15, height - 18), (mid + 15, height - 18), (mid + 23, height - 12), (width - 26, height - 12)]
        _glow_line(image, bottom_points, (245, 168, 42, 235), 7, 6)
        draw.line([(16, height - 28), (16, height - 49)], fill=(43, 202, 232, 230), width=4)
        draw.line([(width - 16, 28), (width - 16, 49)], fill=(43, 202, 232, 230), width=4)
    else:
        draw.line([(17, height - 43), (17, height - 24), (28, height - 13), (47, height - 13)], fill=(43, 174, 202, 220), width=3, joint="curve")
        draw.line([(width - 47, 13), (width - 28, 13), (width - 17, 24), (width - 17, 43)], fill=(43, 174, 202, 220), width=3, joint="curve")
    return image


def _make_heat_gauge() -> Image.Image:
    size = (304, 304)
    image = Image.new("RGBA", size)
    draw = ImageDraw.Draw(image)
    draw.ellipse((10, 10, 294, 294), fill=(1, 7, 11, 218), outline=(15, 45, 57, 255), width=9)
    draw.ellipse((20, 20, 284, 284), fill=(4, 19, 27, 246), outline=(62, 218, 240, 238), width=3)
    draw.ellipse((32, 32, 272, 272), outline=(22, 72, 86, 245), width=3)
    glow = Image.new("RGBA", size)
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.arc((31, 31, 273, 273), 137, 403, fill=(64, 221, 245, 190), width=13)
    glow_draw.arc((31, 31, 273, 273), 315, 403, fill=(255, 108, 38, 230), width=13)
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(7)))
    draw = ImageDraw.Draw(image)
    draw.arc((31, 31, 273, 273), 137, 315, fill=(93, 235, 250, 255), width=7)
    draw.arc((31, 31, 273, 273), 315, 403, fill=(245, 163, 40, 255), width=7)
    import math

    center = (152, 152)
    for index in range(15):
        degrees = 137 + (266 / 14) * index
        radians = math.radians(degrees)
        inner = 105 if index % 2 else 100
        outer = 119
        p1 = (round(center[0] + math.cos(radians) * inner), round(center[1] + math.sin(radians) * inner))
        p2 = (round(center[0] + math.cos(radians) * outer), round(center[1] + math.sin(radians) * outer))
        color = (245, 168, 42, 255) if degrees >= 315 else (105, 231, 246, 240)
        draw.line((p1, p2), fill=color, width=4 if index % 2 == 0 else 2)
    draw.ellipse((121, 121, 183, 183), fill=(2, 14, 20, 255), outline=(43, 188, 215, 255), width=3)
    draw.ellipse((130, 130, 174, 174), outline=(22, 78, 94, 255), width=2)
    draw.line([(59, 239), (88, 239), (102, 253), (202, 253), (216, 239), (245, 239)], fill=(33, 101, 121, 235), width=3)
    draw.line([(59, 239), (88, 239), (102, 253)], fill=(244, 168, 42, 255), width=3)
    font = ImageFont.truetype(str(FONT), 15) if FONT.exists() else ImageFont.load_default()
    label = "H E A T"
    bbox = draw.textbbox((0, 0), label, font=font)
    draw.text(((304 - (bbox[2] - bbox[0])) / 2, 198), label, font=font, fill=(124, 233, 246, 255))
    return image


def _make_heat_needle() -> Image.Image:
    size = (304, 304)
    image = Image.new("RGBA", size)
    glow = Image.new("RGBA", size)
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.polygon([(145, 153), (152, 54), (159, 153)], fill=(255, 137, 38, 220))
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6)))
    draw = ImageDraw.Draw(image)
    draw.polygon([(145, 153), (152, 54), (159, 153)], fill=(248, 172, 47, 255), outline=(255, 242, 188, 255))
    draw.ellipse((136, 136, 168, 168), fill=(4, 19, 27, 255), outline=(106, 232, 247, 255), width=4)
    draw.ellipse((145, 145, 159, 159), fill=(243, 168, 42, 255), outline=(255, 243, 202, 255), width=2)
    return image


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    _make_weapon_slot((192, 144), True).save(OUT / "weapon_slot_main.png")
    _make_weapon_slot((144, 144), False).save(OUT / "weapon_slot_offhand.png")
    _make_heat_gauge().save(OUT / "heat_gauge.png")
    _make_heat_needle().save(OUT / "heat_needle.png")


if __name__ == "__main__":
    main()
