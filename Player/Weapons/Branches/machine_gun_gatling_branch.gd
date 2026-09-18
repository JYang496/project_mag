extends WeaponBranchBehavior
class_name MachineGunGatlingBranch

# Gatling branch: higher fire cadence, split lanes, and heat-based fire conversion.
const GATLING_TEXTURE: Texture2D = preload("res://asset/images/weapons/mg2.png")

@export var projectile_count: int = 2
@export var spread_deg: float = 7.0
@export_range(0.05, 2.0, 0.01) var base_damage_multiplier: float = 0.65

func on_weapon_ready() -> void:
	_apply_gatling_visual()

func on_level_applied(_level: int) -> void:
	_apply_gatling_visual()

func on_removed() -> void:
	super.on_removed()
	if weapon != null and is_instance_valid(weapon):
		weapon.call("_apply_fuse_sprite")

func _apply_gatling_visual() -> void:
	if weapon == null or not is_instance_valid(weapon) or weapon.sprite == null:
		return
	weapon.sprite.texture = GATLING_TEXTURE

func get_added_weapon_traits() -> Array[StringName]:
	return []

func get_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var count := projectile_count if shot_count < 0 else shot_count
	count = clampi(count, 1, 16)
	var spread_step := deg_to_rad(spread_deg)
	return build_centered_spread_directions(base_direction, count, spread_step)

func get_cooldown_multiplier() -> float:
	# Remove branch-only cooldown bonus; keep base weapon cadence.
	return 1.0

func get_extra_heat_shot_multiplier() -> float:
	return 0.0

func get_projectile_damage_multiplier() -> float:
	return maxf(base_damage_multiplier, 0.05)

func get_damage_type_override() -> StringName:
	return Attack.TYPE_PHYSICAL
