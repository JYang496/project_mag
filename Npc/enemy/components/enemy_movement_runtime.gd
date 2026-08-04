extends RefCounted
class_name EnemyMovementRuntime

var enemy
var stun_end_msec := 0
var slow_end_msec := 0
var slow_multiplier: float = 1.0
var last_desired_velocity := Vector2.ZERO
var cached_separation := Vector2.ZERO
var separation_time_left := 0.0
var cached_separation_neighbor_count := 0
var cached_separation_coherence := 0.0
var cached_separation_nearest_distance := INF
var cached_separation_total_strength := 0.0

const SEPARATION_RATE_SPARSE := 0.22
const SEPARATION_RATE_LIGHT := 0.36
const SEPARATION_RATE_DENSE := 0.55
const SEPARATION_RATE_CROWDED := 0.72
const SEPARATION_STACK_GAIN := 0.40
const SEPARATION_STACK_MAX := 1.85
const SEPARATION_NORMAL_RATE_CAP := 0.90
const SEPARATION_EMERGENCY_RATE_CAP := 1.25
const SEPARATION_COMPRESSION_START_DISTANCE := 20.0
const SEPARATION_COMPRESSION_FULL_DISTANCE := 12.0

func setup(source_enemy) -> void:
	enemy = source_enemy
	separation_time_left = float(source_enemy.get_instance_id() % 5) * 0.01

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
	if desired_velocity.length_squared() > 0.01:
		cached_separation = _get_cached_separation(desired_velocity, maxf(_delta, 0.0))
		crowd_drift += cached_separation
	if desired_velocity.length_squared() > 0.01 and enemy.crowd_lateral_speed > 0.0:
		var direction := desired_velocity.normalized()
		var tangent := Vector2(-direction.y, direction.x)
		var lateral_sign := -1.0 if enemy.get_instance_id() % 2 == 0 else 1.0
		crowd_drift += tangent * lateral_sign * enemy.crowd_lateral_speed
	enemy.velocity = desired_velocity + crowd_drift + knockback_velocity
	if enemy.velocity.length_squared() <= 0.0001:
		return
	var previous_position: Vector2 = enemy.global_position
	if enemy.uses_simplified_far_movement():
		enemy.global_position += enemy.velocity * maxf(_delta, 0.0)
	else:
		enemy.move_and_slide()
	var registry := _get_registry()
	if registry != null and registry.has_method("can_accept_position") and not registry.call("can_accept_position", enemy.global_position, enemy):
		enemy.global_position = previous_position
		enemy.velocity = Vector2.ZERO
	if enemy.global_position != previous_position:
		_sync_spatial_position()

func continue_cached_movement(delta: float) -> void:
	move_enemy(last_desired_velocity, delta)

func _sync_spatial_position() -> void:
	var registry := _get_registry()
	if registry != null and registry.has_method("update_enemy_position"):
		registry.call("update_enemy_position", enemy)

func _get_cached_separation(desired_velocity: Vector2, delta: float) -> Vector2:
	separation_time_left -= delta
	if separation_time_left > 0.0:
		return cached_separation
	var interval := maxf(enemy.separation_update_interval, 0.02)
	if cached_separation_neighbor_count <= 3:
		interval = maxf(interval, 0.10)
	elif cached_separation_neighbor_count <= 6:
		interval = maxf(interval, 0.075)
	if enemy.uses_simplified_far_movement():
		interval = maxf(interval, 0.1)
	separation_time_left = interval
	var registry := _get_registry()
	if registry == null:
		return Vector2.ZERO
	if not registry.has_method("get_separation_sample"):
		if not registry.has_method("get_separation_vector"):
			return Vector2.ZERO
		return (registry.call(
			"get_separation_vector",
			enemy,
			enemy.separation_radius,
			enemy.separation_max_neighbors
		) as Vector2) * enemy.separation_speed
	var sample := registry.call(
		"get_separation_sample",
		enemy,
		enemy.separation_radius,
		enemy.separation_max_neighbors
	) as Dictionary
	cached_separation_neighbor_count = maxi(int(sample.get("neighbor_count", 0)), 0)
	cached_separation_coherence = clampf(float(sample.get("coherence", 0.0)), 0.0, 1.0)
	cached_separation_nearest_distance = float(sample.get("nearest_distance", enemy.separation_radius))
	cached_separation_total_strength = maxf(float(sample.get("total_strength", 0.0)), 0.0)
	return _build_dynamic_separation_velocity(sample, desired_velocity)

func _build_dynamic_separation_velocity(sample: Dictionary, desired_velocity: Vector2) -> Vector2:
	var neighbor_count := cached_separation_neighbor_count
	if neighbor_count <= 0:
		return Vector2.ZERO
	var direction := sample.get("direction", Vector2.ZERO) as Vector2
	if direction.length_squared() <= 0.0001 and neighbor_count >= 10 and desired_velocity.length_squared() > 0.0001:
		var desired_direction := desired_velocity.normalized()
		direction = Vector2(-desired_direction.y, desired_direction.x)
		if enemy.get_instance_id() % 2 == 0:
			direction = -direction
	if direction.length_squared() <= 0.0001:
		return Vector2.ZERO

	var density_rate := _get_density_separation_rate(neighbor_count)
	var stack_multiplier := clampf(
		1.0 + SEPARATION_STACK_GAIN * cached_separation_coherence * (sqrt(float(neighbor_count)) - 1.0),
		1.0,
		SEPARATION_STACK_MAX
	)
	var compression_span := maxf(SEPARATION_COMPRESSION_START_DISTANCE - SEPARATION_COMPRESSION_FULL_DISTANCE, 0.01)
	var compression := clampf(
		(SEPARATION_COMPRESSION_START_DISTANCE - cached_separation_nearest_distance) / compression_span,
		0.0,
		1.0
	)
	var reference_speed := maxf(desired_velocity.length(), maxf(enemy.get_current_movement_speed(), 1.0))
	var density_ratio := clampf(float(neighbor_count - 1) / float(maxi(enemy.separation_max_neighbors - 1, 1)), 0.0, 1.0)
	var configured_floor := maxf(enemy.separation_speed, 0.0) * lerpf(0.48, 1.05, density_ratio)
	var dynamic_rate := density_rate * stack_multiplier + 0.32 * compression
	var mean_proximity_strength := cached_separation_total_strength / float(maxi(neighbor_count, 1))
	var proximity_scale := lerpf(0.15, 1.0, clampf(mean_proximity_strength / 0.5, 0.0, 1.0))
	proximity_scale = maxf(proximity_scale, compression)
	var requested_speed := maxf(configured_floor, reference_speed * dynamic_rate) * proximity_scale
	var allowed_rate := lerpf(SEPARATION_NORMAL_RATE_CAP, SEPARATION_EMERGENCY_RATE_CAP, compression)
	return direction.normalized() * minf(requested_speed, reference_speed * allowed_rate)

func _get_density_separation_rate(neighbor_count: int) -> float:
	if neighbor_count <= 3:
		return SEPARATION_RATE_SPARSE
	if neighbor_count <= 6:
		return lerpf(SEPARATION_RATE_SPARSE, SEPARATION_RATE_LIGHT, float(neighbor_count - 3) / 3.0)
	if neighbor_count <= 9:
		return lerpf(SEPARATION_RATE_LIGHT, SEPARATION_RATE_DENSE, float(neighbor_count - 6) / 3.0)
	return lerpf(SEPARATION_RATE_DENSE, SEPARATION_RATE_CROWDED, clampf(float(neighbor_count - 9) / 3.0, 0.0, 1.0))

func get_separation_debug_metrics() -> Dictionary:
	return {
		"neighbor_count": cached_separation_neighbor_count,
		"coherence": cached_separation_coherence,
		"nearest_distance": cached_separation_nearest_distance,
		"total_strength": cached_separation_total_strength,
		"velocity": cached_separation,
	}

func _get_registry() -> Node:
	var tree: SceneTree = enemy.get_tree()
	return tree.root.get_node_or_null("EnemyRegistry") if tree != null else null
