extends Effect
class_name EnemySeekSteer

@export var turn_rate_deg_per_sec: float = 55.0
@export var search_radius: float = 260.0
@export var max_lock_angle_deg: float = 85.0
@export var retarget_interval_sec: float = 0.05
@export var min_speed_ratio: float = 1.0

var _linear_module: LinearMovement = null
var _retarget_elapsed_sec: float = 0.0
var _base_linear_speed: float = 0.0

func projectile_effect_ready() -> void:
	_linear_module = _find_linear_movement_module()
	if _linear_module == null or not is_instance_valid(_linear_module):
		set_physics_process(false)
		return
	_base_linear_speed = maxf(_linear_module.speed, 0.0)
	_retarget_elapsed_sec = 0.0
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if _linear_module == null or not is_instance_valid(_linear_module):
		return
	if projectile == null or not is_instance_valid(projectile):
		return
	_retarget_elapsed_sec -= maxf(delta, 0.0)
	if _retarget_elapsed_sec > 0.0:
		return
	_retarget_elapsed_sec = maxf(retarget_interval_sec, 0.01)
	var target := _find_closest_valid_enemy()
	if target == null:
		return
	var desired_dir: Vector2 = (target.global_position - projectile.global_position).normalized()
	if desired_dir == Vector2.ZERO:
		return
	_apply_steer(desired_dir, delta)

func _find_linear_movement_module() -> LinearMovement:
	if projectile == null or not is_instance_valid(projectile):
		return null
	for effect in projectile.effect_list:
		var linear := effect as LinearMovement
		if linear != null and is_instance_valid(linear):
			return linear
	return null

func _find_closest_valid_enemy() -> Node2D:
	var tree := projectile.get_tree()
	if tree == null:
		return null
	var current_dir: Vector2 = _resolve_current_direction()
	var has_dir: bool = current_dir != Vector2.ZERO
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	var max_dist_sq: float = maxf(search_radius, 1.0)
	max_dist_sq *= max_dist_sq
	var max_lock_angle_rad: float = deg_to_rad(maxf(max_lock_angle_deg, 0.0))
	for enemy_ref in tree.get_nodes_in_group("enemies"):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - projectile.global_position
		var dist_sq: float = to_enemy.length_squared()
		if dist_sq <= 0.0001 or dist_sq > max_dist_sq:
			continue
		var dir_to_enemy := to_enemy.normalized()
		if has_dir and absf(current_dir.angle_to(dir_to_enemy)) > max_lock_angle_rad:
			continue
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy
	return nearest

func _resolve_current_direction() -> Vector2:
	if _linear_module != null and is_instance_valid(_linear_module):
		var linear_dir := (_linear_module.direction as Vector2).normalized()
		if linear_dir != Vector2.ZERO:
			return linear_dir
	var displacement_dir := projectile.base_displacement.normalized()
	if displacement_dir != Vector2.ZERO:
		return displacement_dir
	return Vector2.ZERO

func _apply_steer(desired_dir: Vector2, delta: float) -> void:
	var current_dir: Vector2 = _resolve_current_direction()
	var next_dir: Vector2 = desired_dir
	if current_dir != Vector2.ZERO:
		var max_turn_rad: float = deg_to_rad(maxf(turn_rate_deg_per_sec, 0.0)) * maxf(delta, 0.0)
		var angle_to_target: float = current_dir.angle_to(desired_dir)
		if absf(angle_to_target) > max_turn_rad:
			next_dir = current_dir.rotated(signf(angle_to_target) * max_turn_rad).normalized()
	_linear_module.direction = next_dir
	var min_speed := _base_linear_speed * maxf(min_speed_ratio, 0.0)
	_linear_module.speed = maxf(_linear_module.speed, min_speed)
	_linear_module.set_base_displacement()

