"""Prepare generated sources; final pixel normalization uses the project CLI.

No procedural artwork is generated here: only alpha compositing and atlas crops.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
SOURCE = ROOT / "source"
PREPARED = SOURCE / "prepared"
PREPARED.mkdir(exist_ok=True)
frame = Image.open(SOURCE / "frame.png").convert("RGBA")
backing = Image.new("RGBA", frame.size, (9, 17, 24, 255))
backing.alpha_composite(frame)
backing.save(PREPARED / "frame.png")
atlas = Image.open(SOURCE / "badges.png").convert("RGBA")
names = ["elimination_icon", "selected_badge", "enhanced_badge", "rare_badge",
         "disabled_badge", "focus_badge", "hover_badge", "fallback_icon"]
for i, name in enumerate(names):
    cell = atlas.crop((round(i * atlas.width / 8), 250,
                       round((i + 1) * atlas.width / 8), 530))
    bbox = cell.getbbox()
    if bbox:
        cell = cell.crop(bbox)
    edge = max(cell.size) + 16
    tile = Image.new("RGBA", (edge, edge))
    tile.alpha_composite(cell, ((edge-cell.width)//2, (edge-cell.height)//2))
    tile.save(PREPARED / (name + ".png"))

if (SOURCE / "icons.png").exists():
    atlas = Image.open(SOURCE / "icons.png").convert("RGBA")
    names = ["survival", "elimination", "reward", "operation",
             "containment", "extraction", "rest", "finale"]
    for i, name in enumerate(names):
        x, y = i % 4, i // 4
        cell = atlas.crop((round(x*atlas.width/4), round(y*atlas.height/2),
                           round((x+1)*atlas.width/4), round((y+1)*atlas.height/2)))
        bbox = cell.getbbox()
        if bbox:
            cell = cell.crop(bbox)
        edge = max(cell.size) + 32
        tile = Image.new("RGBA", (edge, edge))
        tile.alpha_composite(cell, ((edge-cell.width)//2, (edge-cell.height)//2))
        tile.save(PREPARED / (name + "_symbol.png"))
