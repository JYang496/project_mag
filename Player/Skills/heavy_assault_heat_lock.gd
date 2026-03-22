extends Skills
class_name HeavyAssaultHeatLock

@export_range(0.0, 1.0, 0.01) var lock_heat_ratio: float = 0.5
@export var lock_duration_sec: float = 3.0
@export var base_cooldown: float = 8.0
@export var passive_peak_mul: float = 1.2
@export_range(0.0, 1.0, 0.01) var passive_center_ratio: float = 0.5
@export_range(0.01, 1.0, 0.01) var passive_falloff_ratio: float = 0.5

var _move_mul_source_id: StringName

func on_skill_ready() -> void:
	cooldown = maxf(base_cooldown, 0.1)
	if _player and is_instance_valid(_player):
		_move_mul_source_id = StringName("heavy_assault_heat_passive_%s" % str(_player.get_instance_id()))

func _exit_tree() -> void:
	if _player and is_instance_valid(_player):
		_player.remove_move_speed_mul(_move_mul_source_id)

func can_activate() -> bool:
	return _has_heat_weapon()

func activate_skill() -> void:
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not weapon.has_method("has_heat_system"):
			continue
		if not bool(weapon.call("has_heat_system")):
			continue
		var max_heat: float = 0.0
		if weapon.has_method("get_heat_max_value"):
			max_heat = float(weapon.call("get_heat_max_value"))
		weapon.call("lock_heat_value", max_heat * clampf(lock_heat_ratio, 0.0, 1.0), lock_duration_sec)

func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var best_mul: float = 1.0
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not weapon.has_method("has_heat_system"):
			continue
		if not bool(weapon.call("has_heat_system")):
			continue
		var heat_ratio: float = 0.0
		if weapon.has_method("get_heat_ratio"):
			heat_ratio = float(weapon.call("get_heat_ratio"))
		var diff: float = absf(heat_ratio - passive_center_ratio)
		var proximity: float = 1.0 - clampf(diff / maxf(passive_falloff_ratio, 0.01), 0.0, 1.0)
		var mul: float = lerpf(1.0, maxf(passive_peak_mul, 1.0), proximity)
		if mul > best_mul:
			best_mul = mul
	_player.apply_move_speed_mul(_move_mul_source_id, best_mul)

func _has_heat_weapon() -> bool:
	for weapon in PlayerData.player_weapon_list:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not weapon.has_method("has_heat_system"):
			continue
		if bool(weapon.call("has_heat_system")):
			return true
	return false
