extends WeaponBranchBehavior
class_name ShotgunDoubleBreachBranch

@export var wave_damage_multiplier: float = 0.65
@export var cooldown_multiplier: float = 1.25
@export var second_wave_delay_sec: float = 0.12
@export var second_spread_multiplier: float = 0.65
@export var ammo_cost: int = 2
@export var breach_vulnerability_multiplier: float = 1.15
@export var breach_vulnerability_duration_sec: float = 2.5
var _breached_targets_by_volley: Dictionary = {}

func get_projectile_damage_multiplier() -> float:
	return maxf(wave_damage_multiplier, 0.05)

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_shotgun_double_volley_config() -> Dictionary:
	return {
		"second_wave_delay_sec": maxf(second_wave_delay_sec, 0.01),
		"second_spread_multiplier": clampf(second_spread_multiplier, 0.05, 1.0),
		"ammo_cost": maxi(ammo_cost, 1),
	}

func apply_double_breach_vulnerability(target: Node, volley_id: int) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("apply_damage_taken_multiplier_status"):
		return false
	var target_key := "%d:%d" % [volley_id, target.get_instance_id()]
	if _breached_targets_by_volley.has(target_key):
		return false
	_breached_targets_by_volley[target_key] = true
	target.call(
		"apply_damage_taken_multiplier_status",
		StringName("shotgun_double_breach_%d" % volley_id),
		maxf(breach_vulnerability_multiplier, 1.0),
		maxf(breach_vulnerability_duration_sec, 0.1)
	)
	if weapon != null and is_instance_valid(weapon):
		weapon.emit_passive_trigger(&"shotgun_double_breach", {
			"target": target,
			"volley_id": volley_id,
			"vulnerability_multiplier": maxf(breach_vulnerability_multiplier, 1.0),
			"duration": maxf(breach_vulnerability_duration_sec, 0.1),
		}, Weapon.PASSIVE_SCOPE_GLOBAL)
	_prune_volley_records(volley_id)
	return true

func on_removed() -> void:
	_breached_targets_by_volley.clear()
	super.on_removed()

func _prune_volley_records(current_volley_id: int) -> void:
	for key in _breached_targets_by_volley.keys():
		var parts := str(key).split(":", false, 1)
		if not parts.is_empty() and int(parts[0]) < current_volley_id - 6:
			_breached_targets_by_volley.erase(key)
