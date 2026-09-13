extends Node2D

var weapon: Node2D

func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	z_index = -1

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(weapon) or not weapon.is_visible_in_tree():
		return
	var holder := weapon.get_parent() as Node2D
	var mech := holder.get_parent() as Node2D if holder != null else null
	if mech == null or not mech.is_in_group(&"player"):
		return
	var origin := mech.global_position
	var end := weapon.global_position
	var view := get_tree().get_first_node_in_group(&"hybrid_ground_view_3d")
	if view != null:
		if not bool(view.call("can_project_world_point", end)):
			return
		origin = view.call("project_world_to_canvas", origin, get_viewport()) as Vector2
		end = view.call("project_world_to_canvas", end, get_viewport()) as Vector2
	var module_sprite := weapon.get_node_or_null("Sprite") as Node2D
	var blade := weapon.get_node_or_null("BladeAnchor/BladeSprite") as Node2D
	if blade != null:
		module_sprite = blade
	if module_sprite != null and module_sprite.has_method("get_visual_dock_canvas_position"):
		end = module_sprite.call("get_visual_dock_canvas_position") as Vector2
	var distance := origin.distance_to(end)
	if distance < 42.0:
		return
	var direction := origin.direction_to(end)
	var start := origin + direction * 32.0
	var pulse := 0.13 + 0.04 * sin(float(Time.get_ticks_msec()) * 0.003)
	draw_line(to_local(start).round(), to_local(end).round(), Color(0.18, 0.65, 0.72, pulse), 1.0)
