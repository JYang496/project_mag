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
	var pool := _get_shared_heat_pool()
	if pool == null:
		return
	var max_heat: float = float(pool.max_heat)
	pool.lock_to_value(max_heat * clampf(lock_heat_ratio, 0.0, 1.0), lock_duration_sec)

func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var heat_ratio: float = 0.0
	var pool := _get_shared_heat_pool()
	if pool != null:
		heat_ratio = float(pool.get_ratio())
	var diff: float = absf(heat_ratio - passive_center_ratio)
	var proximity: float = 1.0 - clampf(diff / maxf(passive_falloff_ratio, 0.01), 0.0, 1.0)
	var best_mul: float = lerpf(1.0, maxf(passive_peak_mul, 1.0), proximity)
	_player.apply_move_speed_mul(_move_mul_source_id, best_mul)

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
