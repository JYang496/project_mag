extends RefCounted
class_name EnemyMovementRuntime

var enemy
var stun_end_msec := 0
var slow_end_msec := 0
var slow_multiplier: float = 1.0
var last_desired_velocity := Vector2.ZERO

func setup(source_enemy) -> void:
	enemy = source_enemy

func get_stun_remaining() -> float:
	return maxf(float(stun_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0)

func set_stun_remaining(value: float) -> void:
	stun_end_msec = Time.get_ticks_msec() + int(maxf(value, 0.0) * 1000.0)

func get_slow_remaining() -> float:
	var remaining := maxf(float(slow_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	if remaining <= 0.0:
		slow_multiplier = 1.0
	return remaining

func get_current_slow_multiplier() -> float:
	get_slow_remaining()
	return slow_multiplier

func set_slow_remaining(value: float) -> void:
	slow_end_msec = Time.get_ticks_msec() + int(maxf(value, 0.0) * 1000.0)

func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	var adjusted_duration := duration
	if enemy is EliteEnemy or enemy.is_boss or enemy.is_in_group("boss"):
		adjusted_duration *= 0.5
	set_stun_remaining(maxf(get_stun_remaining(), adjusted_duration))

func apply_slow(multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var clamped_multiplier := clampf(multiplier, 0.05, 1.0)
	slow_multiplier = minf(slow_multiplier, clamped_multiplier) if get_slow_remaining() > 0.0 else clamped_multiplier
	set_slow_remaining(maxf(get_slow_remaining(), duration))

func move_enemy(desired_velocity: Vector2, _delta: float) -> void:
	last_desired_velocity = desired_velocity
	var knockback_velocity: Vector2 = enemy.knockback.amount * enemy.knockback.angle
	var crowd_drift := Vector2.ZERO
	if desired_velocity.length_squared() > 0.01 and enemy.crowd_lateral_speed > 0.0:
		var direction := desired_velocity.normalized()
		var tangent := Vector2(-direction.y, direction.x)
		var lateral_sign := -1.0 if enemy.get_instance_id() % 2 == 0 else 1.0
		crowd_drift = tangent * lateral_sign * enemy.crowd_lateral_speed
	enemy.velocity = desired_velocity + crowd_drift + knockback_velocity
	if enemy.velocity.length_squared() <= 0.0001:
		return
	var previous_position: Vector2 = enemy.global_position
	if enemy.uses_simplified_far_movement():
		enemy.global_position += enemy.velocity * maxf(_delta, 0.0)
	else:
		enemy.move_and_slide()
	if enemy.global_position != previous_position:
		_sync_spatial_position()

func continue_cached_movement(delta: float) -> void:
	move_enemy(last_desired_velocity, delta)

func _sync_spatial_position() -> void:
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return
	var registry := tree.root.get_node_or_null("EnemyRegistry")
	if registry != null and registry.has_method("update_enemy_position"):
		registry.call("update_enemy_position", enemy)
