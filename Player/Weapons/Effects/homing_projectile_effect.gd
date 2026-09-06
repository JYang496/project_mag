extends Node
class_name HomingProjectileEffect

@export var turn_speed_radians_per_sec := 5.5
@export var acquire_radius := 420.0
var projectile: Projectile

func setup(projectile_value: Projectile, turn_speed: float = 5.5, radius: float = 420.0) -> HomingProjectileEffect:
	projectile = projectile_value
	turn_speed_radians_per_sec = maxf(turn_speed, 0.1)
	acquire_radius = maxf(radius, 1.0)
	return self

func _physics_process(delta: float) -> void:
	if projectile == null or not is_instance_valid(projectile) or not projectile.is_inside_tree():
		queue_free()
		return
	var target := _find_target()
	if target == null:
		return
	var speed: float = projectile.base_displacement.length()
	if speed <= 0.01:
		return
	var current: float = projectile.base_displacement.angle()
	var desired := projectile.global_position.direction_to(target.global_position).angle()
	var next_angle := rotate_toward(current, desired, turn_speed_radians_per_sec * maxf(delta, 0.0))
	projectile.base_displacement = Vector2.RIGHT.rotated(next_angle) * speed

func _find_target() -> Node2D:
	var best: Node2D
	var best_distance := INF
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(projectile.get_tree(), projectile.global_position, acquire_radius):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := projectile.global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best
