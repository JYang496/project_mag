from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parent


def trim(path: Path, padding: int = 8) -> None:
    image = Image.open(path).convert("RGBA")
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"No opaque pixels in {path.name}")
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(image.width, right + padding)
    bottom = min(image.height, bottom + padding)
    image.crop((left, top, right, bottom)).save(path)


def rebuild_energy(path: Path, gap: int = 16, padding: int = 8) -> None:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("No energy pixels found")

    # Detect the transparent gaps separating the generated modules.
    x0, y0, x1, y1 = bbox
    occupied = []
    for x in range(x0, x1):
        occupied.append(alpha.crop((x, y0, x + 1, y1)).getbbox() is not None)

    runs = []
    start = None
    for offset, value in enumerate(occupied + [False]):
        if value and start is None:
            start = offset
        elif not value and start is not None:
            runs.append((x0 + start, x0 + offset))
            start = None
    if len(runs) < 2:
        raise RuntimeError("Could not detect separate energy cells")

    full_width = min(runs[0][1] - runs[0][0], runs[1][1] - runs[1][0])
    full = image.crop((runs[0][0], y0, runs[0][0] + full_width, y1))
    half_width = full_width // 2
    half = full.crop((0, 0, half_width, full.height))
    canvas = Image.new(
        "RGBA",
        (padding * 2 + full_width * 2 + half_width + gap * 2, padding * 2 + full.height),
        (0, 0, 0, 0),
    )
    x = padding
    canvas.alpha_composite(full, (x, padding))
    x += full_width + gap
    canvas.alpha_composite(full, (x, padding))
    x += full_width + gap
    canvas.alpha_composite(half, (x, padding))
    canvas.save(path)


for filename in ("ui_frame.png", "hp_fill.png", "shield_fill.png", "ammo_icon.png"):
    trim(ROOT / filename)

rebuild_energy(ROOT / "energy_125_fill.png")

