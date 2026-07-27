extends Skills
class_name HeavyAssaultHeatLock

@export_range(0.0, 1.0, 0.01) var lock_heat_ratio: float = 1.0
@export var lock_duration_sec: float = 3.0
@export var base_cooldown: float = 8.0

func on_skill_ready() -> void:
	cooldown = maxf(base_cooldown, 0.1)

func can_activate() -> bool:
	return _has_heat_weapon()

func activate_skill() -> void:
	var pool := _get_shared_heat_pool()
	if pool == null:
		return
	var max_heat: float = float(pool.max_heat)
	pool.lock_to_value(max_heat * clampf(lock_heat_ratio, 0.0, 1.0), lock_duration_sec)

func _has_heat_weapon() -> bool:
	var pool := _get_shared_heat_pool()
	if pool == null:
		return false
	if pool.has_method("has_contributors"):
		return bool(pool.call("has_contributors"))
	return float(pool.max_heat) > 0.0

func _get_shared_heat_pool() -> Object:
	if _player == null or not is_instance_valid(_player):
		return null
	if not _player.has_method("get_shared_heat_pool"):
		return null
	return _player.call("get_shared_heat_pool")
