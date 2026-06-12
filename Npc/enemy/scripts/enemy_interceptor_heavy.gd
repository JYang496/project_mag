extends BaseEnemy
class_name EnemyInterceptorHeavy

@export var guard_distance_from_support: float = 95.0
@export var guard_arrival_radius: float = 22.0

var _guard_target: BaseEnemy = null

func _physics_process(delta: float) -> void:
	if is_stunned():
		set_crowd_breakthrough_active(false)
		decay_knockback()
		move_with_body_push(Vector2.ZERO, delta)
		return
	_guard_target = _find_nearest_support()
	var desired_velocity := _resolve_guard_velocity()
	set_crowd_breakthrough_active(desired_velocity.length_squared() > 0.01)
	decay_knockback()
	move_with_body_push(desired_velocity, delta)

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

func _find_nearest_support() -> BaseEnemy:
	var registry := get_node_or_null("/root/EnemyRegistry")
	if registry == null or not registry.has_method("get_enemies"):
		return null
	var nearest: BaseEnemy = null
	var nearest_distance := INF
	for enemy_ref in registry.call("get_enemies"):
		var enemy := enemy_ref as BaseEnemy
		if enemy == null or enemy == self or not enemy.is_support_unit():
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest
