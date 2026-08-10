"""Build the eight-frame irregular MagArena flamethrower spray animation."""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw


SIZE = (256, 80)
TRANSPARENT = (0, 0, 0, 0)
OUTER_RED = (255, 72, 7, 63)
OUTER_ORANGE = (253, 123, 18, 127)
MID_ORANGE = (253, 179, 60, 191)
HOT_YELLOW = (253, 224, 157, 255)
CORE_CREAM = (253, 237, 184, 255)


def _q(value: float) -> int:
    return int(round(value / 2.0) * 2)


def _wave(frame: int, x: int, phase: float, amplitude: float) -> float:
    return math.sin(frame * 0.91 + x * 0.071 + phase) * amplitude


def _profile(frame: int, inset: int = 0) -> tuple[list[tuple[int, int]], list[tuple[int, int]]]:
    xs = [0, 12, 24, 40, 56, 72, 88, 104, 120, 136, 152, 168, 184, 200, 216, 232]
    # Large, deliberately uneven contour events. Values vary independently on
    # the two sides so the spray never reads as a mirrored geometric cone.
    top_events = [0, 1, -1, 2, -2, 4, -4, 1, -6, 3, -3, 5, -5, 2, -2, 4, 0]
    bottom_events = [0, -1, 2, -2, 4, -3, 5, -5, 2, -4, 6, -2, 4, -6, 3, -3, 0]
    top: list[tuple[int, int]] = []
    bottom: list[tuple[int, int]] = []
    for i, x in enumerate(xs):
        growth = 2.0 + 33.0 * math.pow(x / 232.0, 0.72)
        taper = max(0.0, (x - 204) / 28.0) * 8.0
        top_jitter = top_events[(i + frame * 2) % len(top_events)] + _wave(frame, x, 0.2, 2.8)
        bottom_jitter = bottom_events[(i + frame * 3) % len(bottom_events)] + _wave(frame, x, 2.1, 3.0)
        top_y = 40.0 - growth + taper + top_jitter + inset
        bottom_y = 40.0 + growth - taper + bottom_jitter - inset
        top.append((x, max(2, min(39, _q(top_y)))))
        bottom.append((x, min(77, max(41, _q(bottom_y)))))
    return top, bottom


def _polygon(draw: ImageDraw.ImageDraw, top: list[tuple[int, int]], bottom: list[tuple[int, int]], color: tuple[int, int, int, int]) -> None:
    midpoint_y = _q((top[-1][1] + bottom[-1][1]) * 0.5)
    inset = max(top[0][1] - 38, 0)
    center_tip = (246 - inset // 2, midpoint_y)
    draw.polygon(top + [center_tip] + list(reversed(bottom)), fill=color)


def _flow_streak(draw: ImageDraw.ImageDraw, frame: int, index: int, color: tuple[int, int, int, int]) -> None:
    start_x = 30 + index * 18
    end_x = min(230, start_x + 86 + ((frame * 13 + index * 17) % 46))
    center = 40 + _q(math.sin(frame * 0.83 + index * 1.7) * (4 + index))
    thickness = 4 + (index % 3) * 2
    points_top: list[tuple[int, int]] = []
    points_bottom: list[tuple[int, int]] = []
    for x in range(start_x, end_x + 1, 12):
        bend = _q(math.sin(x * 0.085 + frame * 0.7 + index) * (3 + index))
        taper = int((x - start_x) / max(end_x - start_x, 1) * thickness)
        half = max(2, thickness - taper // 2)
        points_top.append((x, center + bend - half))
        points_bottom.append((x, center + bend + half))
    tip = (min(end_x + 12, 244), center + _q(math.sin(end_x * 0.085 + frame + index) * 3))
    draw.polygon(points_top + [tip] + list(reversed(points_bottom)), fill=color)


def _cut_notches(image: Image.Image, frame: int) -> None:
    draw = ImageDraw.Draw(image)
    # Deep notches break the shared fan boundary; positions walk between frames.
    top_x = 82 + (frame * 19) % 104
    bottom_x = 104 + (frame * 23) % 96
    draw.polygon([(top_x, 0), (top_x + 12, 0), (top_x + 6, 18 + (frame % 3) * 4)], fill=TRANSPARENT)
    draw.polygon([(bottom_x, 79), (bottom_x + 14, 79), (bottom_x + 8, 58 - (frame % 2) * 4)], fill=TRANSPARENT)
    if frame % 2 == 0:
        side_x = 188 + (frame * 7) % 32
        draw.polygon([(side_x, 0), (side_x + 9, 0), (side_x + 4, 13)], fill=TRANSPARENT)


def _embers(draw: ImageDraw.ImageDraw, frame: int) -> None:
    ember_specs = [
        (174 + (frame * 11) % 55, 7 + (frame * 9) % 16, 4),
        (196 + (frame * 7) % 45, 61 + (frame * 5) % 12, 3),
        (226 + (frame * 5) % 22, 15 + (frame * 13) % 49, 2),
    ]
    for index, (x, y, radius) in enumerate(ember_specs):
        color = OUTER_ORANGE if index else MID_ORANGE
        draw.rectangle((x, y, min(x + radius + 1, 253), min(y + radius, 77)), fill=color)
        if radius >= 4:
            draw.point((x + 1, y + 1), fill=HOT_YELLOW)


def build_frame(frame: int) -> Image.Image:
    image = Image.new("RGBA", SIZE, TRANSPARENT)
    draw = ImageDraw.Draw(image)
    for inset, color in ((0, OUTER_RED), (4, OUTER_ORANGE), (9, MID_ORANGE), (15, HOT_YELLOW), (22, CORE_CREAM)):
        top, bottom = _profile(frame, inset)
        _polygon(draw, top, bottom, color)

    # Broken internal streams prevent the palette from reading as concentric rings.
    _flow_streak(draw, frame, 0, CORE_CREAM)
    _flow_streak(draw, frame, 1, HOT_YELLOW)
    _flow_streak(draw, frame, 2, MID_ORANGE)
    _flow_streak(draw, frame, 3, HOT_YELLOW)
    _cut_notches(image, frame)
    _embers(ImageDraw.Draw(image), frame)
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for frame in range(8):
        build_frame(frame).save(args.output_dir / f"flame_spray_{frame:02d}.png", optimize=True)


if __name__ == "__main__":
    main()
