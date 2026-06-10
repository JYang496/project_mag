extends RefCounted
class_name EnemyMovementRuntime

var enemy
var stun_remaining: float = 0.0
var slow_remaining: float = 0.0
var slow_multiplier: float = 1.0
var body_push_velocity: Vector2 = Vector2.ZERO
var body_push_collision_velocity: Vector2 = Vector2.ZERO
var crowd_breakthrough_active: bool = false
var crowd_breakthrough_is_overlapping_enemies: bool = false
var knockback_overlap_mode: bool = false

func setup(source_enemy) -> void:
	enemy = source_enemy

func update_statuses(delta: float) -> void:
	if stun_remaining > 0.0:
		stun_remaining = maxf(0.0, stun_remaining - delta)
	if slow_remaining > 0.0:
		slow_remaining = maxf(0.0, slow_remaining - delta)
		if slow_remaining <= 0.0:
			slow_multiplier = 1.0
	update_knockback_overlap_mode()

func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	var adjusted_duration := duration
	if enemy is EliteEnemy or enemy.is_boss or enemy.is_in_group("boss"):
		adjusted_duration *= 0.5
	stun_remaining = maxf(stun_remaining, adjusted_duration)

func apply_slow(multiplier: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var clamped_multiplier := clampf(multiplier, 0.05, 1.0)
	slow_multiplier = minf(slow_multiplier, clamped_multiplier) if slow_remaining > 0.0 else clamped_multiplier
	slow_remaining = maxf(slow_remaining, duration)

func move_with_body_push(desired_velocity: Vector2, delta: float) -> void:
	var knockback_velocity: Vector2 = enemy.knockback.amount * enemy.knockback.angle
	var safe_push_velocity := body_push_velocity if enemy.body_push_enabled else Vector2.ZERO
	body_push_collision_velocity = desired_velocity + safe_push_velocity
	var previous_position: Vector2 = enemy.global_position
	_update_crowd_breakthrough_collision_mask(body_push_collision_velocity)
	enemy.velocity = body_push_collision_velocity + knockback_velocity
	enemy.move_and_slide()
	_apply_crowd_breakthrough_path_push(previous_position, enemy.global_position, body_push_collision_velocity)
	_apply_body_push_from_slide_collisions()
	_decay_body_push_velocity(delta)

func apply_body_push(push_velocity: Vector2) -> void:
	if not enemy.body_push_enabled or push_velocity.length_squared() <= 0.01:
		return
	body_push_velocity += push_velocity
	var max_speed := maxf(enemy.body_push_max_speed, 0.0)
	if max_speed > 0.0 and body_push_velocity.length() > max_speed:
		body_push_velocity = body_push_velocity.normalized() * max_speed

func set_crowd_breakthrough_active(active: bool) -> void:
	if crowd_breakthrough_active == active:
		return
	crowd_breakthrough_active = active
	if not active:
		_set_crowd_breakthrough_enemy_overlap(false)

func _apply_body_push_from_slide_collisions() -> void:
	if not enemy.body_push_enabled:
		return
	var own_speed := body_push_collision_velocity.length()
	if own_speed <= maxf(enemy.body_push_min_speed_delta, 0.0):
		return
	for collision_index in range(enemy.get_slide_collision_count()):
		var collision: KinematicCollision2D = enemy.get_slide_collision(collision_index)
		if collision == null:
			continue
		var other = collision.get_collider()
		if other == null or other == enemy or not is_instance_valid(other) or not other is BaseEnemy or not other.body_push_enabled:
			continue
		var push_dir: Vector2 = -collision.get_normal()
		if push_dir.length_squared() <= 0.001:
			push_dir = enemy.global_position.direction_to(other.global_position)
		if push_dir.length_squared() <= 0.001:
			continue
		push_dir = push_dir.normalized()
		var incoming_speed := body_push_collision_velocity.dot(push_dir)
		if incoming_speed <= 0.0:
			continue
		var other_forward_speed := maxf(other.get_body_push_collision_velocity().dot(push_dir), 0.0)
		var speed_delta := incoming_speed - other_forward_speed
		if speed_delta > maxf(enemy.body_push_min_speed_delta, 0.0):
			other.apply_body_push(push_dir * speed_delta * maxf(enemy.body_push_strength, 0.0))

func _decay_body_push_velocity(delta: float) -> void:
	if body_push_velocity.length_squared() <= 0.01:
		body_push_velocity = Vector2.ZERO
		return
	body_push_velocity = body_push_velocity.move_toward(Vector2.ZERO, maxf(enemy.body_push_decay, 0.0) * maxf(delta, 0.0))

func _update_crowd_breakthrough_collision_mask(move_velocity: Vector2) -> void:
	if not crowd_breakthrough_active or move_velocity.length_squared() <= 1.0:
		_set_crowd_breakthrough_enemy_overlap(false)
		return
	_set_crowd_breakthrough_enemy_overlap(not _has_crowd_breakthrough_blocker(move_velocity))

func _set_crowd_breakthrough_enemy_overlap(enabled: bool) -> void:
	if crowd_breakthrough_is_overlapping_enemies == enabled:
		return
	enemy.set_collision_mask_value(3, not enabled)
	crowd_breakthrough_is_overlapping_enemies = enabled

func _has_crowd_breakthrough_blocker(move_velocity: Vector2) -> bool:
	var move_dir := move_velocity.normalized()
	var half_width := _get_crowd_breakthrough_half_width()
	var lookahead := maxf(half_width * 2.0, move_velocity.length() * 0.18)
	for other in _get_crowd_breakthrough_candidates(lookahead + half_width):
		if other == enemy or not _is_crowd_breakthrough_blocker(other):
			continue
		var to_enemy: Vector2 = other.global_position - enemy.global_position
		var forward_distance := to_enemy.dot(move_dir)
		if forward_distance < 0.0 or forward_distance > lookahead:
			continue
		if absf(to_enemy.dot(Vector2(-move_dir.y, move_dir.x))) <= half_width:
			return true
	return false

func _apply_crowd_breakthrough_path_push(start_position: Vector2, end_position: Vector2, move_velocity: Vector2) -> void:
	if not crowd_breakthrough_active or move_velocity.length_squared() <= 1.0:
		return
	var segment := end_position - start_position
	if segment.length_squared() <= 1.0:
		segment = move_velocity.normalized() * maxf(_get_crowd_breakthrough_half_width(), 1.0)
	var segment_length := segment.length()
	var move_dir := segment / segment_length
	var side_dir := Vector2(-move_dir.y, move_dir.x)
	var half_width := _get_crowd_breakthrough_half_width()
	var base_push_speed := move_velocity.length() * maxf(enemy.crowd_breakthrough_side_push_strength, 0.0)
	if base_push_speed <= 0.0:
		return
	for other in _get_crowd_breakthrough_candidates(segment_length + half_width * 2.0):
		if other == enemy or not _is_crowd_breakthrough_push_target(other):
			continue
		var to_enemy: Vector2 = other.global_position - start_position
		var closest_point := start_position + move_dir * clampf(to_enemy.dot(move_dir), 0.0, segment_length)
		var offset: Vector2 = other.global_position - closest_point
		if offset.length() > half_width:
			continue
		var lateral := offset.dot(side_dir)
		var side_sign := signf(lateral) if absf(lateral) > 0.001 else (-1.0 if other.get_instance_id() % 2 == 0 else 1.0)
		other.apply_body_push(side_dir * side_sign * base_push_speed)

func _get_crowd_breakthrough_candidates(radius: float) -> Array:
	var output: Array = []
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return output
	var registry := tree.root.get_node_or_null("EnemyRegistry")
	if registry != null and registry.has_method("get_enemies_in_radius"):
		for enemy_ref in registry.call("get_enemies_in_radius", enemy.global_position, maxf(radius, 1.0), enemy):
			if enemy_ref is BaseEnemy and is_instance_valid(enemy_ref):
				output.append(enemy_ref)
		return output
	for enemy_ref in tree.get_nodes_in_group("enemies"):
		if enemy_ref is BaseEnemy and enemy_ref != enemy and is_instance_valid(enemy_ref) and enemy_ref.global_position.distance_to(enemy.global_position) <= radius:
			output.append(enemy_ref)
	return output

func _is_crowd_breakthrough_push_target(other) -> bool:
	return other != null and is_instance_valid(other) and other.body_push_enabled and not _is_crowd_breakthrough_blocker(other)

func _is_crowd_breakthrough_blocker(other) -> bool:
	return other != null and is_instance_valid(other) and (
		other.is_boss
		or other.is_in_group("boss")
		or other is EliteEnemy
		or other.is_quest_movement_locked()
	)

func _get_crowd_breakthrough_half_width() -> float:
	var radius := 16.0
	var collision_shape := enemy.get_node_or_null("NPCCollision") as CollisionShape2D
	if collision_shape != null and collision_shape.shape != null:
		var shape := collision_shape.shape
		if shape is CircleShape2D:
			radius = (shape as CircleShape2D).radius
		elif shape is RectangleShape2D:
			var size := (shape as RectangleShape2D).size
			radius = maxf(size.x, size.y) * 0.5
		elif shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			radius = maxf(capsule.radius, capsule.height * 0.5)
	return maxf(radius * maxf(enemy.crowd_breakthrough_width_multiplier, 0.1), 1.0)

func update_knockback_overlap_mode() -> void:
	if crowd_breakthrough_is_overlapping_enemies:
		return
	var is_being_knocked_back := float(enemy.knockback.get("amount", 0.0)) > 0.01
	if is_being_knocked_back:
		if not knockback_overlap_mode:
			enemy.set_collision_mask_value(3, false)
			knockback_overlap_mode = true
		return
	if knockback_overlap_mode:
		enemy.set_collision_mask_value(3, true)
		knockback_overlap_mode = false
