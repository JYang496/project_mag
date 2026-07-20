extends BaseEnemy
class_name EnemyInterceptor

@export var guard_distance_from_support: float = 95.0
@export var guard_arrival_radius: float = 22.0
@export_range(0.05, 2.0, 0.05) var guard_target_refresh_interval: float = 0.35
@export var guard_support_search_radius: float = 1024.0

var _guard_target: BaseEnemy = null
var _guard_target_refresh_remaining: float = 0.0
var _guard_target_refresh_initialized := false

func _physics_process(delta: float) -> void:
	var ai_delta := consume_ai_update_delta(delta)
	if ai_delta <= 0.0:
		continue_lod_movement(delta)
		return
	delta = ai_delta
	_update_guard_target(delta)
	if is_stunned():
		decay_knockback()
		move_enemy(Vector2.ZERO, delta)
		return
	var desired_velocity := _resolve_guard_velocity()
	decay_knockback()
	move_enemy(desired_velocity, delta)

func _resolve_guard_velocity() -> Vector2:
	if PlayerData.player == null:
		return Vector2.ZERO
	if _guard_target == null:
		return global_position.direction_to(PlayerData.player.global_position) * get_current_movement_speed()
	var support_to_player := _guard_target.global_position.direction_to(PlayerData.player.global_position)
	var guard_position := _guard_target.global_position + support_to_player * guard_distance_from_support
	var distance := global_position.distance_to(guard_position)
	if distance <= guard_arrival_radius:
		return Vector2.ZERO
	return global_position.direction_to(guard_position) * get_current_movement_speed()

func _update_guard_target(delta: float) -> void:
	var refresh_interval := maxf(guard_target_refresh_interval, 0.05)
	var next_refresh_interval := refresh_interval
	if not _guard_target_refresh_initialized:
		_guard_target_refresh_initialized = true
		# Preserve the original first-frame acquisition, then spread later scans.
		var refresh_phase := fmod(float(get_instance_id()), 17.0) / 17.0
		next_refresh_interval = refresh_interval * (0.5 + refresh_phase)
	if _is_valid_guard_target(_guard_target):
		_guard_target_refresh_remaining -= delta
		if _guard_target_refresh_remaining > 0.0:
			return
	elif _guard_target != null:
		# A removed or repurposed support target should be replaced immediately.
		_guard_target_refresh_remaining = 0.0
	elif _guard_target_refresh_remaining > 0.0:
		_guard_target_refresh_remaining -= delta
		return
	_guard_target = _find_nearest_support()
	_guard_target_refresh_remaining = next_refresh_interval

func _is_valid_guard_target(target: BaseEnemy) -> bool:
	return (
		is_instance_valid(target)
		and target.is_inside_tree()
		and target != self
		and target.is_support_unit()
	)

func _find_nearest_support() -> BaseEnemy:
	var registry := get_node_or_null("/root/EnemyRegistry")
	if registry == null or not registry.has_method("get_nearest_support"):
		return null
	var target := registry.call(
		"get_nearest_support",
		self,
		maxf(guard_support_search_radius, 1.0)
	) as BaseEnemy
	return target if _is_valid_guard_target(target) else null
