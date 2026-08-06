extends Control
class_name BeaconPlayerForeground

const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	visible = _has_active_protocol_visual()
	if not visible:
		return
	var viewport_size := get_viewport_rect().size
	if size != viewport_size:
		position = Vector2.ZERO
		size = viewport_size
	queue_redraw()


func _has_active_protocol_visual() -> bool:
	var parent_node := get_parent()
	if parent_node == null:
		return false
	for sibling in parent_node.get_children():
		if sibling != self and str(sibling.name).begins_with("BeaconProjectedVisual_") and not sibling.is_queued_for_deletion():
			return true
	return false


func _draw() -> void:
	var draw_state := get_player_draw_state()
	if draw_state.is_empty():
		return
	draw_polygon(
		draw_state.get("points") as PackedVector2Array,
		draw_state.get("colors") as PackedColorArray,
		draw_state.get("uvs") as PackedVector2Array,
		draw_state.get("texture") as Texture2D,
	)


func get_player_draw_state() -> Dictionary:
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player) or not player.visible:
		return {}
	var visual_source := _active_player_visual_source(player)
	if visual_source == null:
		return {}
	var config := visual_source.call("get_unit_billboard_config") as Dictionary
	var texture := config.get("texture") as Texture2D
	var visual_size := config.get("visual_size_px", Vector2.ZERO) as Vector2
	if texture == null or visual_size.x <= 0.0 or visual_size.y <= 0.0 or not bool(config.get("visible", true)):
		return {}
	var bottom_padding := clampf(float(config.get("bottom_padding_px", 0.0)), 0.0, visual_size.y * 0.49)
	var local_ground_anchor := config.get("local_ground_anchor", Vector2.ZERO) as Vector2
	var anchor_screen := _project(player.global_transform * local_ground_anchor)
	var top_left := anchor_screen - Vector2(visual_size.x * 0.5, visual_size.y - bottom_padding)
	var rect := Rect2(top_left, visual_size)
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	var left_u := 1.0 if bool(config.get("flip_h", false)) else 0.0
	var right_u := 0.0 if bool(config.get("flip_h", false)) else 1.0
	var top_v := 1.0 if bool(config.get("flip_v", false)) else 0.0
	var bottom_v := 0.0 if bool(config.get("flip_v", false)) else 1.0
	var color := config.get("color", Color.WHITE) as Color
	color = _apply_feedback_color(color, config)
	return {
		"texture": texture,
		"points": points,
		"uvs": PackedVector2Array([
			Vector2(left_u, top_v),
			Vector2(right_u, top_v),
			Vector2(right_u, bottom_v),
			Vector2(left_u, bottom_v),
		]),
		"colors": PackedColorArray([color, color, color, color]),
		"anchor_screen": anchor_screen,
		"rect": rect,
	}


func _active_player_visual_source(player: Node2D) -> Node2D:
	for node_name in [&"MechaMoveSprite", &"MechaSprite"]:
		var candidate := player.get_node_or_null(NodePath(str(node_name))) as Node2D
		if candidate != null and candidate.visible and candidate.has_method("get_unit_billboard_config"):
			return candidate
	return null


func _apply_feedback_color(base_color: Color, config: Dictionary) -> Color:
	var result := base_color
	var flash_amount := clampf(float(config.get("flash_amount", 0.0)), 0.0, 1.0)
	var warning_amount := clampf(float(config.get("warning_amount", 0.0)), 0.0, 1.0)
	var flash_color := config.get("flash_color", Color.WHITE) as Color
	var warning_color := config.get("warning_color", Color.WHITE) as Color
	result.r = lerpf(result.r, flash_color.r, flash_amount)
	result.g = lerpf(result.g, flash_color.g, flash_amount)
	result.b = lerpf(result.b, flash_color.b, flash_amount)
	result.r = lerpf(result.r, warning_color.r, warning_amount)
	result.g = lerpf(result.g, warning_color.g, warning_amount)
	result.b = lerpf(result.b, warning_color.b, warning_amount)
	return result


func _project(world_position: Vector2) -> Vector2:
	var view := ProjectedUi.get_hybrid_view(get_tree())
	if view != null:
		return view.call("project_world_to_screen", world_position) as Vector2
	return get_viewport().get_canvas_transform() * world_position
