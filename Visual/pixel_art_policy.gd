extends RefCounted
class_name PixelArtPolicy

## Runtime source of truth for MagArena's pixel-art presentation scale.
##
## Source textures may be normalized with fractional Node2D scales. The final
## authored target size must be an integer number of logical pixels; the window
## then enlarges the 1280x720 logical canvas by an integer factor.

const LOGICAL_VIEWPORT_SIZE := Vector2i(1280, 720)

const PLAYER_FRAME_SIZE := Vector2i(128, 128)
const PLAYER_SUPPORT_FRAME_SIZE := Vector2i(64, 64)
const PLAYER_REFERENCE_HEIGHT_PX := 128.0
const WEAPON_TARGET_HEIGHT_PX := 64.0
const WEAPON_SOURCE_HEIGHT_PX := 64

const PROJECTILE_STANDARD_SIZE := Vector2(10.0, 10.0)
const PROJECTILE_CANNON_SIZE := Vector2(12.0, 12.0)
const PROJECTILE_LARGE_SIZE := Vector2(32.0, 32.0)

const ENEMY_STANDARD_FRAME_SIZE := Vector2i(32, 32)
const ENEMY_ELITE_FRAME_SIZE := Vector2i(48, 48)
# Hybrid ground rendering needs explicit billboard compensation. These tiers
# keep visible silhouettes close to their authored 18-42px HurtBox sizes.
const ENEMY_STANDARD_VISUAL_SCALE := Vector2.ONE
const ENEMY_LARGE_SOURCE_VISUAL_SCALE := Vector2(1.125, 1.125)
const LOOT_STANDARD_FRAME_SIZE := Vector2i(32, 32)
const LOOT_LARGE_FRAME_SIZE := Vector2i(64, 64)
const BOARD_CELL_FRAME_SIZE := Vector2i(256, 256)
const SCENE_PROP_LARGE_FRAME_SIZE := Vector2i(256, 256)

const EFFECT_SMALL_FRAME_SIZE := Vector2i(32, 32)
const EFFECT_MEDIUM_FRAME_SIZE := Vector2i(64, 64)
const EFFECT_LARGE_FRAME_SIZE := Vector2i(128, 128)
const EFFECT_FLAME_SPRAY_FRAME_SIZE := Vector2i(256, 80)
const EFFECT_GLACIER_SPRAY_FRAME_SIZE := Vector2i(256, 90)
const MODULE_ICON_SIZE := Vector2i(32, 32)


static func snap_logical_position(value: Vector2) -> Vector2:
	return value.round()


static func is_integer_target_size(value: Vector2) -> bool:
	return value.x > 0.0 and value.y > 0.0 and value == value.round()
