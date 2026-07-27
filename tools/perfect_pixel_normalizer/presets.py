from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Literal


AlphaMode = Literal["hard", "stepped", "preserve"]


@dataclass(frozen=True)
class AssetPreset:
    id: str
    label: str
    width: int | None
    height: int | None
    alpha_mode: AlphaMode
    palette_limit: int | None
    preserve_aspect: bool = False
    prohibited: bool = False

    @property
    def fixed_size(self) -> tuple[int, int] | None:
        if self.width is None or self.height is None:
            return None
        return self.width, self.height

    def target_for_source(self, source_size: tuple[int, int]) -> tuple[int, int] | None:
        if self.prohibited:
            return None
        if self.preserve_aspect and self.height is not None:
            source_width, source_height = source_size
            if source_height <= 0:
                raise ValueError("输入图片高度无效。")
            width = max(1, round(source_width * self.height / source_height))
            return width, self.height
        return self.fixed_size

    def size_matches(self, source_size: tuple[int, int]) -> bool:
        if self.preserve_aspect and self.height is not None:
            return source_size[1] == self.height
        return self.fixed_size == source_size


PRESETS: dict[str, AssetPreset] = {
    "custom": AssetPreset("custom", "自定义/自动检测", None, None, "preserve", None),
    "player": AssetPreset("player", "玩家动画帧 128×128", 128, 128, "hard", 64),
    "player_support": AssetPreset(
        "player_support", "支援单位 64×64", 64, 64, "hard", 48
    ),
    "enemy_standard": AssetPreset(
        "enemy_standard", "普通敌人 32×32", 32, 32, "hard", 64
    ),
    "enemy_large": AssetPreset(
        "enemy_large", "大型敌人 48×48", 48, 48, "hard", 96
    ),
    "weapon": AssetPreset(
        "weapon", "装备武器（固定高 40px）", None, 40, "hard", 32, preserve_aspect=True
    ),
    "projectile_standard": AssetPreset(
        "projectile_standard", "普通投射物 10×10", 10, 10, "hard", 24
    ),
    "projectile_cannon": AssetPreset(
        "projectile_cannon", "炮弹 12×12", 12, 12, "hard", 24
    ),
    "projectile_large": AssetPreset(
        "projectile_large", "大型投射物 32×32", 32, 32, "hard", 32
    ),
    "effect_small": AssetPreset(
        "effect_small", "小型特效 32×32", 32, 32, "stepped", 48
    ),
    "effect_medium": AssetPreset(
        "effect_medium", "中型特效/爆炸 64×64", 64, 64, "stepped", 64
    ),
    "effect_large": AssetPreset(
        "effect_large", "大型特效 128×128", 128, 128, "stepped", 96
    ),
    "effect_flame_spray": AssetPreset(
        "effect_flame_spray", "火焰喷射帧 256×80", 256, 80, "stepped", 64
    ),
    "effect_glacier_spray": AssetPreset(
        "effect_glacier_spray", "冰霜喷射帧 256×90", 256, 90, "stepped", 64
    ),
    "module": AssetPreset("module", "模块图标 32×32", 32, 32, "hard", 20),
    "board_cell": AssetPreset(
        "board_cell", "地图格 256×256", 256, 256, "preserve", None
    ),
    "scene_prop_large": AssetPreset(
        "scene_prop_large", "大型场景物件 256×256", 256, 256, "hard", 128
    ),
    "modern_ui": AssetPreset(
        "modern_ui", "现代 UI（禁止像素规范化）", None, None, "preserve", None,
        prohibited=True,
    ),
}


def get_preset(preset_id: str) -> AssetPreset:
    try:
        return PRESETS[preset_id]
    except KeyError as exc:
        choices = ", ".join(PRESETS)
        raise ValueError(f"未知资产预设：{preset_id}。可用值：{choices}") from exc


def infer_preset_from_path(path: str | Path) -> str:
    normalized = Path(path).as_posix().lower()
    name = Path(path).name.lower()

    if "/ui/themes/modern/" in f"/{normalized}" or "/asset/images/ui/heat_gauge/" in f"/{normalized}":
        return "modern_ui"
    if "/asset/images/modules/pixel/" in f"/{normalized}":
        return "module"
    if "/asset/images/cells/" in f"/{normalized}":
        return "board_cell"
    if "/asset/images/ui/rest_area/" in f"/{normalized}":
        return "scene_prop_large"
    if "/asset/images/effects/flame_spray/" in f"/{normalized}":
        return "effect_flame_spray"
    if "/asset/images/effects/glacier_spray/" in f"/{normalized}":
        return "effect_glacier_spray"
    if "/asset/images/effects/explosion/" in f"/{normalized}":
        return "effect_medium"
    if "/asset/images/weapons/projectiles/" in f"/{normalized}":
        if "cannon" in name:
            return "projectile_cannon"
        if "large" in name or "chainsaw" in name:
            return "projectile_large"
        return "projectile_standard"
    if "/asset/images/weapons/" in f"/{normalized}":
        return "weapon"
    if "/asset/images/enemies/" in f"/{normalized}":
        if name in {"interceptor.png", "rolling_ball_elite.png"}:
            return "enemy_large"
        if name == "enemy_spike_projectile.png":
            return "projectile_standard"
        return "enemy_standard"
    if "/asset/images/characters/" in f"/{normalized}":
        if "drone" in name or "support" in name:
            return "player_support"
        return "player"
    return "custom"
