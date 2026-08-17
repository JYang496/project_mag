#!/usr/bin/env python3
"""Migrate legacy high-resolution art to the MagArena pixel-art tiers.

The script uses Pillow's nearest-neighbour resampler only. It never asks Godot
to render or re-export an image. Original active images are copied into the
archive before replacement; unused legacy character sources are moved there.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "archive" / "deprecated_pixel_sources_20260724"
ORIGINALS = ARCHIVE / "originals"
DEPRECATED = ARCHIVE / "deprecated"

WEAPON_HEIGHT = 40

RESIZE_EXACT: dict[str, tuple[int, int]] = {
    # Board cells: one authored source tier.
    "asset/images/cells/dirt1.png": (256, 256),
    "asset/images/cells/dirt2.png": (256, 256),
    "asset/images/cells/fact1.png": (256, 256),
    "asset/images/cells/fact2.png": (256, 256),
    "asset/images/cells/glass.png": (256, 256),
    "asset/images/cells/gold1.png": (256, 256),
    "asset/images/cells/gold2.png": (256, 256),
    "asset/images/cells/ice.png": (256, 256),
    "asset/images/cells/lava.png": (256, 256),
    # Rest-area props: large scene-prop tier.
    "asset/images/ui/rest_area/board_tactical.png": (256, 256),
    "asset/images/ui/rest_area/purchase_shop.png": (256, 256),
    "asset/images/ui/rest_area/upgrade_gunsmith.png": (256, 256),
    "asset/images/ui/rest_area/warehouse_armory.png": (256, 256),
    # Effects: medium/large and directional tiers.
    **{
        f"asset/images/effects/explosion/explosion_{frame:02d}.png": (64, 64)
        for frame in range(1, 9)
    },
    **{
        f"asset/images/effects/flame_spray/flame_spray_{frame:02d}.png": (256, 80)
        for frame in range(8)
    },
    **{
        f"asset/images/effects/glacier_spray/glacier_spray_{frame:02d}.png": (256, 90)
        for frame in range(8)
    },
    **{
        f"asset/images/weapons/projectiles/chainsaw_spin_{frame:02d}.png": (32, 32)
        for frame in range(1, 7)
    },
}

ACTIVE_WEAPONS = [
    "blaster.png",
    "cannon2.png",
    "cannon3.png",
    "chainsaw_launcher.png",
    "dash_blade.png",
    "flamethrower.png",
    "glacier_projector.png",
    "laser.png",
    "machine_gun.png",
    "mg2.png",
    "orbit.png",
    "pistol.png",
    "plasma_lance.png",
    "rocket_launcher.png",
    "shotgun.png",
    "sniper.png",
    "spear_launcher.png",
]

DEPRECATED_CHARACTER_PATHS = [
    "asset/images/characters/2b.png",
    "asset/images/characters/2f.png",
    "asset/images/characters/f.png",
    "asset/images/characters/move_b",
    "asset/images/characters/move_f",
    "asset/images/characters/pixel_animation_grid_2048x1024_128.png",
    "asset/images/characters/侧身260719 - topb4_1024x1024_nearest_from_128.png",
    "asset/images/characters/侧身260719 - topb4_128x128.png",
]

DEPRECATED_ENEMY_PATHS = [
    "asset/images/enemies/elite.png",
]

RESTORED_SOURCES = [
    {
        "path": "asset/images/characters/ranger_drone.png",
        "git_source": "0bb6867",
        "reason": "Runtime reference existed while only the .import sidecar remained.",
    },
]

def _image_size(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        return image.size


def _archive_original(relative: str) -> Path:
    source = ROOT / relative
    archived = ORIGINALS / relative
    archived.parent.mkdir(parents=True, exist_ok=True)
    if not archived.exists():
        shutil.copy2(source, archived)
    return archived


def _restore_active_if_archived(relative: str) -> None:
    source = ROOT / relative
    archived_deprecated = DEPRECATED / relative
    if source.exists() or not archived_deprecated.exists():
        return
    source.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(archived_deprecated), str(source))
    archived_sidecar = archived_deprecated.with_name(archived_deprecated.name + ".import")
    if archived_sidecar.exists():
        shutil.move(str(archived_sidecar), str(source.with_name(source.name + ".import")))


def _resize_nearest(relative: str, target: tuple[int, int]) -> dict[str, object]:
    source = ROOT / relative
    if not source.is_file():
        raise FileNotFoundError(source)
    archived = _archive_original(relative)
    original_size = _image_size(archived)
    with Image.open(archived) as image:
        converted = image.convert("RGBA")
        resized = converted.resize(target, resample=Image.Resampling.NEAREST)
        resized.save(source, format="PNG", optimize=False)
    return {
        "path": relative,
        "operation": "nearest_resize",
        "original_size": list(original_size),
        "target_size": list(target),
    }


def _resize_weapon(relative: str) -> dict[str, object]:
    source = ROOT / relative
    archived = _archive_original(relative)
    width, height = _image_size(archived)
    if height <= 0:
        raise ValueError(f"Invalid weapon image height: {relative}")
    target_width = max(1, round(width * WEAPON_HEIGHT / height))
    return _resize_nearest(relative, (target_width, WEAPON_HEIGHT))


def _move_deprecated(relative: str) -> list[dict[str, object]]:
    source = ROOT / relative
    destination = DEPRECATED / relative
    if not source.exists():
        if destination.exists():
            archived_files = (
                sorted(path for path in destination.rglob("*") if path.is_file())
                if destination.is_dir()
                else [destination]
            )
            records: list[dict[str, object]] = []
            for path in archived_files:
                original_relative = Path(relative)
                if destination.is_dir():
                    original_relative = original_relative / path.relative_to(destination)
                record: dict[str, object] = {
                    "path": original_relative.as_posix(),
                    "operation": "archive_deprecated",
                }
                if path.suffix.lower() == ".png":
                    record["size"] = list(_image_size(path))
                records.append(record)
            return records
        raise FileNotFoundError(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        raise FileExistsError(destination)
    records: list[dict[str, object]] = []
    if source.is_dir():
        files = sorted(path for path in source.rglob("*") if path.is_file())
        for path in files:
            rel_file = path.relative_to(ROOT).as_posix()
            record: dict[str, object] = {
                "path": rel_file,
                "operation": "archive_deprecated",
            }
            if path.suffix.lower() == ".png":
                record["size"] = list(_image_size(path))
            records.append(record)
        shutil.move(str(source), str(destination))
        return records

    record = {
        "path": relative,
        "operation": "archive_deprecated",
    }
    if source.suffix.lower() == ".png":
        record["size"] = list(_image_size(source))
    records.append(record)
    shutil.move(str(source), str(destination))

    import_sidecar = source.with_name(source.name + ".import")
    if import_sidecar.exists():
        sidecar_destination = destination.with_name(destination.name + ".import")
        shutil.move(str(import_sidecar), str(sidecar_destination))
    return records


def main() -> None:
    records: list[dict[str, object]] = []
    for relative, target in sorted(RESIZE_EXACT.items()):
        records.append(_resize_nearest(relative, target))
    for filename in ACTIVE_WEAPONS:
        relative = f"asset/images/weapons/{filename}"
        _restore_active_if_archived(relative)
        records.append(_resize_weapon(relative))
    for relative in DEPRECATED_CHARACTER_PATHS + DEPRECATED_ENEMY_PATHS:
        records.extend(_move_deprecated(relative))

    manifest = {
        "schema_version": 1,
        "algorithm": "Pillow Image.Resampling.NEAREST",
        "engine_rendering_used": False,
        "restored_sources": [
            {
                **record,
                "size": list(_image_size(ROOT / str(record["path"]))),
            }
            for record in RESTORED_SOURCES
        ],
        "records": records,
    }
    manifest_path = ARCHIVE / "manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Migrated {len(records)} files; manifest: {manifest_path}")


if __name__ == "__main__":
    main()
