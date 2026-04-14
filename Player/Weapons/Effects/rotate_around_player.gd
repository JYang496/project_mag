extends Effect
class_name RotateAroundPlayer

var radius : float = 40.0
var angle : float = 0.0
var spin_speed : float = 3.0
var angle_offset :float = 0.0
var oc_mode = false
var max_radius : float = 200.0
var radius_hit_max : bool = false
var _fallback_center: Vector2 = Vector2.ZERO
var _fallback_center_initialized: bool = false

func projectile_effect_ready() -> void:
	claim_projectile_movement_control()
	projectile.base_displacement = Vector2.ZERO
	max_radius = radius * 5

func _physics_process(delta: float) -> void:
	if not projectile:
		return
	if not has_projectile_movement_control():
		return
	if oc_mode:
		if radius > max_radius:
			radius_hit_max = true
		if radius_hit_max:
			radius -= 2
		else:
			radius += 2
		spin_speed = clampf(spin_speed + 0.1, 0.1, 20)
	angle += spin_speed * delta
	var x_pos = radius * cos(angle + angle_offset)
	var y_pos = radius * sin(angle + angle_offset)
	projectile.global_position = Vector2(x_pos, y_pos) + _resolve_orbit_center()
	if radius < 10:
		projectile.queue_free()

func _resolve_orbit_center() -> Vector2:
	var player_node := PlayerData.player
	if player_node is Node2D and is_instance_valid(player_node):
		return (player_node as Node2D).global_position
	if projectile and is_instance_valid(projectile):
		var source_weapon := projectile.source_weapon
		if source_weapon is Node2D and is_instance_valid(source_weapon):
			return (source_weapon as Node2D).global_position
		if not _fallback_center_initialized:
			_fallback_center = projectile.global_position
			_fallback_center_initialized = true
	return _fallback_center
