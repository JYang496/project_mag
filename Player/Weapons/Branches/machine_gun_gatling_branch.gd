extends WeaponBranchBehavior
class_name MachineGunGatlingBranch

# Gatling branch: higher fire cadence, split lanes, and heat-based fire conversion.
@export var projectile_count: int = 2
@export var spread_deg: float = 7.0
@export_range(0.0, 1.0, 0.05) var extra_heat_shot_multiplier: float = 0.45
@export_range(0.05, 2.0, 0.01) var base_damage_multiplier: float = 0.80
@export_range(0.0, 1.0, 0.01) var fire_mode_heat_ratio: float = 0.50
const BRANCH_RUNTIME_TRAIT_FIRE: StringName = CombatTrait.FIRE

func on_weapon_ready() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.has_method("add_runtime_weapon_trait"):
		weapon.call("add_runtime_weapon_trait", BRANCH_RUNTIME_TRAIT_FIRE)

func on_removed() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if weapon.has_method("remove_runtime_weapon_trait"):
		weapon.call("remove_runtime_weapon_trait", BRANCH_RUNTIME_TRAIT_FIRE)

func get_shot_directions(base_direction: Vector2, shot_count: int = -1) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var count := projectile_count if shot_count < 0 else shot_count
	count = clampi(count, 1, 16)
	var normalized_base := base_direction.normalized()
	if count == 1:
		return [normalized_base]
	var spread_step := deg_to_rad(spread_deg)
	var center_offset := float(count - 1) * 0.5
	for i in range(count):
		var angle := (float(i) - center_offset) * spread_step
		dirs.append(normalized_base.rotated(angle))
	return dirs

func get_cooldown_multiplier() -> float:
	# Remove branch-only cooldown bonus; keep base weapon cadence.
	return 1.0

func get_extra_heat_shot_multiplier() -> float:
	return clampf(extra_heat_shot_multiplier, 0.0, 1.0)

func get_projectile_damage_multiplier() -> float:
	if weapon == null or not is_instance_valid(weapon):
		return maxf(base_damage_multiplier, 0.05)
	if not weapon.has_method("get_heat_ratio"):
		return maxf(base_damage_multiplier, 0.05)
	var base_mul := maxf(base_damage_multiplier, 0.05)
	# Remove high-heat damage scaling: gatling keeps a fixed base multiplier.
	return base_mul

func get_damage_type_override() -> StringName:
	if weapon == null or not is_instance_valid(weapon):
		return Attack.TYPE_PHYSICAL
	if not weapon.has_method("get_heat_ratio"):
		return Attack.TYPE_PHYSICAL
	var heat_ratio: float = float(weapon.call("get_heat_ratio"))
	if heat_ratio >= fire_mode_heat_ratio:
		return Attack.TYPE_FIRE
	return Attack.TYPE_PHYSICAL
