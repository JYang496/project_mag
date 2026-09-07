extends Node
class_name HomingProjectileEffect

@export var turn_speed_radians_per_sec := 5.5
@export var acquire_radius := 420.0
@export_range(0.0, 180.0, 1.0) var acquire_half_angle_degrees := 180.0
@export var release_radius_multiplier := 1.35
var projectile: Projectile
var _target_ref: WeakRef

func setup(
	projectile_value: Projectile,
	turn_speed: float = 5.5,
	radius: float = 420.0,
	half_angle_degrees: float = 180.0,
	target_release_radius_multiplier: float = 1.35
) -> HomingProjectileEffect:
	projectile = projectile_value
	turn_speed_radians_per_sec = maxf(turn_speed, 0.1)
	acquire_radius = maxf(radius, 1.0)
	acquire_half_angle_degrees = clampf(half_angle_degrees, 0.0, 180.0)
	release_radius_multiplier = maxf(target_release_radius_multiplier, 1.0)
	_target_ref = null
	return self

func _physics_process(delta: float) -> void:
	if projectile == null or not is_instance_valid(projectile) or not projectile.is_inside_tree():
		queue_free()
		return
	var target: Node2D = _resolve_locked_target()
	if target == null:
		target = _find_target()
		if target != null:
			_target_ref = weakref(target)
	if target == null:
		return
	var speed: float = projectile.base_displacement.length()
	if speed <= 0.01:
		return
	var current: float = projectile.base_displacement.angle()
	var desired: float = projectile.global_position.direction_to(target.global_position).angle()
	var next_angle: float = rotate_toward(current, desired, turn_speed_radians_per_sec * maxf(delta, 0.0))
	projectile.base_displacement = Vector2.RIGHT.rotated(next_angle) * speed

func _find_target() -> Node2D:
	var best: Node2D
	var best_distance: float = INF
	var current_direction: Vector2 = projectile.base_displacement.normalized()
	var max_angle: float = deg_to_rad(acquire_half_angle_degrees)
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(projectile.get_tree(), projectile.global_position, acquire_radius):
		var enemy := enemy_ref as Node2D
		if not _is_target_alive(enemy):
			continue
		var to_enemy: Vector2 = projectile.global_position.direction_to(enemy.global_position)
		if current_direction != Vector2.ZERO and absf(current_direction.angle_to(to_enemy)) > max_angle:
			continue
		var distance: float = projectile.global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func _resolve_locked_target() -> Node2D:
	if _target_ref == null:
		return null
	var target := _target_ref.get_ref() as Node2D
	if not _is_target_alive(target):
		_target_ref = null
		return null
	var release_radius: float = acquire_radius * release_radius_multiplier
	if projectile.global_position.distance_squared_to(target.global_position) > release_radius * release_radius:
		_target_ref = null
		return null
	return target

func _is_target_alive(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var dead_value: Variant = target.get("is_dead")
	if dead_value != null and bool(dead_value):
		return false
	return target.is_in_group(&"enemies")
