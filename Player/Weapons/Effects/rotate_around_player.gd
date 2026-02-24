extends Effect
class_name RotateAroundPlayer

var radius : float = 40.0
var angle : float = 0.0
var spin_speed : float = 3.0
var angle_offset :float = 0.0
var oc_mode = false
var max_radius : float = 200.0
var radius_hit_max : bool = false

func projectile_effect_ready() -> void:
	projectile.base_displacement = Vector2.ZERO
	max_radius = radius * 5

func _physics_process(delta: float) -> void:
	if not projectile:
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
	projectile.global_position = Vector2(x_pos,y_pos) + PlayerData.player.global_position
	if radius < 10:
		projectile.queue_free()
