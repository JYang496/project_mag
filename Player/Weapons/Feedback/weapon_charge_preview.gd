extends Node2D

var weapon: Weapon
var radial := false
var _age := 0.0
var _was_ready := false
var _ready_now := false

func _process(delta: float) -> void:
	_ready_now = is_instance_valid(weapon) and weapon.is_inside_tree() and weapon.can_run_active_behavior()
	if _ready_now:
		# Blade Dance consumes its own charge on reload, independently of the
		# active weapon skill. Never advertise a ring from skill unlock alone.
		_ready_now = bool(weapon.get_passive_status().get("ready", false)) if radial else bool(weapon.get_energy_full_fire_status().get("ready", false))
	if _ready_now and not _was_ready:
		_age = 0.0
	_was_ready = _ready_now
	_age += delta
	queue_redraw()

func _draw() -> void:
	if not _ready_now:
		return
	var origin := weapon.get_muzzle_global_position()
	var direction := weapon.get_aim_forward()
	var view := get_tree().get_first_node_in_group(&"hybrid_ground_view_3d")
	if view != null:
		if not view.call("can_project_world_point", origin):
			return
		direction = view.call("world_vector_to_screen", direction, origin)
		origin = view.call("project_world_to_canvas", origin, get_viewport())
	var center := to_local(origin).round()
	var t := clampf(_age / 0.12, 0, 1)
	var color := Color(0.55,0.94,1,0.65 if _age < 0.2 else 0.28)
	if radial:
		for index in range(8):
			var point := center + Vector2.RIGHT.rotated(index*TAU/8) * lerpf(18,8,t)
			draw_rect(Rect2(point.round(),Vector2(2,2)),color)
	else:
		var side := direction.normalized().orthogonal()
		for sign_value in [-1,1]:
			var end: Vector2 = center + side * sign_value * lerpf(3,18,t)
			draw_line(center,end.round(),color,1)
			draw_rect(Rect2(end.round()-Vector2(1,2),Vector2(2,4)),color)
		draw_rect(Rect2(center-Vector2(2,2),Vector2(4,4)),color)
