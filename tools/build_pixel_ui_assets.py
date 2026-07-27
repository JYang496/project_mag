"""Build archived pixel HUD experiments for MagArena.

Deprecated: runtime UI must not reference outputs from this script. Modern
combat HUD sources are built by ``tools/build_modern_ui_assets.py``. This file
is retained only so legacy experiments under ``UI/themes/pixel`` remain
reproducible.

Module icons are generated from their editable SVG sources by
``tools/build_pixel_module_icons.gd`` so Godot's own SVG loader remains the
single rendering dependency.
"""

from __future__ import annotations

from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
HUD_DIR = ROOT / "UI" / "themes" / "player_status_hud" / "generated"
PIXEL_UI_DIR = ROOT / "UI" / "themes" / "pixel" / "generated"
MODULE_DIR = ROOT / "asset" / "images" / "modules" / "pixel"

INK = (5, 10, 18, 255)
PANEL = (12, 25, 38, 238)
EDGE_DARK = (24, 55, 73, 255)
EDGE = (57, 153, 184, 255)
EDGE_LIGHT = (132, 230, 242, 255)
WHITE = (222, 247, 244, 255)


def _save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def _pixel_frame(size: tuple[int, int], inset: int = 3) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width - 1, height - 1), fill=INK)
    draw.rectangle((2, 2, width - 3, height - 3), fill=EDGE)
    draw.rectangle((inset + 1, inset + 1, width - inset - 2, height - inset - 2), fill=PANEL)
    for x, y in ((2, 2), (width - 7, 2), (2, height - 7), (width - 7, height - 7)):
        draw.rectangle((x, y, x + 4, y + 4), fill=EDGE_LIGHT)
    return image


def build_hud() -> None:
    frame = _pixel_frame((356, 96), 4)
    draw = ImageDraw.Draw(frame)
    draw.rectangle((8, 8, 347, 10), fill=EDGE_DARK)
    draw.rectangle((8, 85, 347, 87), fill=EDGE_DARK)
    _save(frame, HUD_DIR / "ui_frame_clean_panel.png")

    hp = Image.new("RGBA", (198, 20), (0, 0, 0, 0))
    draw = ImageDraw.Draw(hp)
    draw.rectangle((0, 0, 197, 19), fill=(18, 42, 31, 255))
    draw.rectangle((2, 2, 195, 17), fill=(41, 198, 104, 255))
    draw.rectangle((4, 3, 193, 6), fill=(120, 248, 168, 255))
    draw.rectangle((4, 15, 193, 16), fill=(17, 110, 70, 255))
    for x in range(12, 196, 16):
        draw.line((x, 4, x, 15), fill=(31, 145, 87, 255), width=1)
    _save(hp, HUD_DIR / "hp_fill.png")

    shield = Image.new("RGBA", (198, 7), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shield)
    draw.rectangle((0, 0, 197, 6), fill=(12, 34, 62, 255))
    draw.rectangle((2, 1, 195, 5), fill=(48, 159, 222, 255))
    draw.line((3, 1, 194, 1), fill=(157, 229, 255, 255), width=1)
    for x in range(10, 196, 12):
        draw.point((x, 4), fill=(19, 89, 155, 255))
    _save(shield, HUD_DIR / "shield_fill.png")

    energy = Image.new("RGBA", (135, 20), (0, 0, 0, 0))
    draw = ImageDraw.Draw(energy)
    segments = ((0, 54), (59, 54), (118, 17))
    for x, width in segments:
        draw.rectangle((x, 0, x + width - 1, 19), fill=(52, 27, 7, 255))
        draw.rectangle((x + 2, 2, x + width - 3, 17), fill=(245, 150, 26, 255))
        draw.rectangle((x + 4, 3, x + width - 5, 6), fill=(255, 230, 96, 255))
        for cut in range(x + 10, x + width - 2, 10):
            draw.line((cut, 7, cut, 16), fill=(167, 75, 11, 255), width=1)
    _save(energy, HUD_DIR / "energy_125_fill.png")

    ammo = Image.new("RGBA", (20, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(ammo)
    for x in (2, 8, 14):
        draw.rectangle((x, 4, x + 3, 13), fill=(49, 106, 126, 255))
        draw.rectangle((x + 1, 1, x + 2, 3), fill=(214, 243, 238, 255))
        draw.point((x + 1, 7), fill=(117, 222, 232, 255))
    _save(ammo, HUD_DIR / "ammo_icon.png")

    _save(_weapon_slot(main=True), PIXEL_UI_DIR / "weapon_slot_main.png")
    _save(_weapon_slot(main=False), PIXEL_UI_DIR / "weapon_slot_offhand.png")


def _weapon_slot(main: bool) -> Image.Image:
    size = (96, 72) if main else (72, 72)
    image = _pixel_frame(size, 4)
    draw = ImageDraw.Draw(image)
    width, height = size
    accent = (255, 190, 55, 255) if main else (78, 199, 236, 255)
    draw.rectangle((7, 7, width - 8, 9), fill=accent)
    draw.rectangle((7, height - 10, width - 8, height - 8), fill=accent)
    if main:
        draw.rectangle((7, height - 6, width - 8, height - 4), fill=(255, 212, 76, 255))
        draw.polygon(((42, 3), (53, 3), (49, 8), (46, 8)), fill=(255, 235, 145, 255))
    else:
        center = width // 2
        draw.rectangle((center - 3, 4, center + 2, 7), fill=(160, 240, 255, 255))
    return image


def _module_base(accent: tuple[int, int, int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = _pixel_frame((32, 32), 3)
    draw = ImageDraw.Draw(image)
    draw.rectangle((5, 5, 26, 26), fill=(9, 18, 28, 255))
    draw.rectangle((7, 7, 24, 8), fill=accent)
    draw.rectangle((7, 23, 24, 24), fill=accent)
    return image, draw


def _damage(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int]) -> None:
    draw.polygon(((17, 8), (21, 8), (17, 15), (22, 15), (12, 25), (15, 18), (10, 18)), fill=color)


def _pierce(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int]) -> None:
    draw.rectangle((8, 14, 22, 17), fill=color)
    draw.polygon(((22, 10), (27, 16), (22, 21)), fill=color)
    for x in (11, 16):
        draw.rectangle((x, 10, x + 1, 21), fill=(88, 131, 146, 255))


def _speed(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int]) -> None:
    for offset in (0, 6):
        draw.polygon(((8 + offset, 9), (16 + offset, 16), (8 + offset, 23), (11 + offset, 16)), fill=color)


def _size(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int]) -> None:
    draw.rectangle((12, 12, 20, 20), fill=color)
    draw.rectangle((8, 8, 11, 11), fill=(111, 180, 198, 255))
    draw.rectangle((21, 21, 25, 25), fill=(239, 247, 230, 255))


def _reload(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int]) -> None:
    draw.arc((8, 8, 24, 24), 30, 300, fill=color, width=3)
    draw.polygon(((20, 7), (26, 9), (22, 14)), fill=color)


def _magazine(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int]) -> None:
    draw.rectangle((10, 8, 21, 22), fill=color)
    draw.rectangle((12, 10, 19, 12), fill=(243, 242, 210, 255))
    draw.rectangle((12, 15, 19, 17), fill=(72, 94, 102, 255))
    draw.polygon(((10, 22), (21, 22), (18, 26), (12, 26)), fill=color)


def _lifesteal(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int]) -> None:
    draw.polygon(((16, 24), (8, 16), (8, 11), (12, 8), (16, 12), (20, 8), (24, 11), (24, 16)), fill=color)
    draw.rectangle((15, 12, 17, 20), fill=(255, 214, 220, 255))
    draw.rectangle((12, 15, 20, 17), fill=(255, 214, 220, 255))


def _link(draw: ImageDraw.ImageDraw, color: tuple[int, int, int, int]) -> None:
    draw.rectangle((7, 11, 17, 15), outline=color, width=2)
    draw.rectangle((15, 17, 25, 21), outline=color, width=2)
    draw.line((13, 16, 19, 16), fill=(222, 247, 244, 255), width=2)


def build_module_icons() -> None:
    specs: dict[str, tuple[tuple[int, int, int, int], Callable[[ImageDraw.ImageDraw, tuple[int, int, int, int]], None]]] = {
        "wmod_damage_up_stat": ((255, 93, 72, 255), _damage),
        "wmod_pierce_stat": ((255, 188, 65, 255), _pierce),
        "wmod_projectile_speed_stat": ((65, 209, 244, 255), _speed),
        "wmod_bullet_size_stat": ((102, 220, 170, 255), _size),
        "wmod_fast_reload": ((255, 197, 68, 255), _reload),
        "wmod_expanded_magazine": ((152, 195, 210, 255), _magazine),
        "wmod_lifesteal_on_hit": ((238, 72, 111, 255), _lifesteal),
        "wmod_reload_speed_link": ((110, 194, 255, 255), _link),
    }
    for name, (accent, painter) in specs.items():
        image, draw = _module_base(accent)
        painter(draw, accent)
        _save(image, MODULE_DIR / f"{name}.png")


def main() -> None:
    build_hud()
    build_module_icons()
    print("Built pixel UI assets.")


if __name__ == "__main__":
    main()
