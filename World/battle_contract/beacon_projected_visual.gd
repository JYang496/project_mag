extends Control

const ProjectedUi := preload("res://Visual/Oblique/projected_world_ui_service.gd")
const PROTOCOL_SQUARE_TEXTURE: Texture2D = preload("res://asset/images/effects/protocol/protocol_square_topdown.png")

const OPERATION := &"operation"
const CONTAINMENT := &"containment"
const EXTRACTION := &"extraction"
const TAU_F := TAU
const PLAYER_OCCLUSION_PADDING := Vector2(4.0, 3.0)

var target: Node2D
var visual_kind: StringName = OPERATION
var beacon_id := 0
var footprint_size := Vector2(140.0, 140.0)
var progress := 0.0
var player_inside := false
var enemy_count := 0
var completed := false
var removing := false
var _elapsed := 0.0
var _completion_elapsed := 0.0
var _active_player_occlusion_rect := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func configure(owner_target: Node2D, kind: StringName, id: int, world_footprint_size: Vector2) -> void:
	target = owner_target
	visual_kind = kind
	beacon_id = id
	footprint_size = world_footprint_size.abs()
	queue_redraw()

func set_presence(inside: bool, enemies: int) -> void:
	player_inside = inside
	enemy_count = maxi(enemies, 0)
	queue_redraw()

func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if progress >= 1.0 and visual_kind != EXTRACTION:
		play_completion()
	queue_redraw()

func play_completion() -> void:
	if completed:
		return
	completed = true
	_completion_elapsed = 0.0
	queue_redraw()

func play_completion_and_remove() -> void:
	play_completion()
	removing = true

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	_elapsed += delta
	if completed:
		_completion_elapsed += delta
	if removing and _completion_elapsed >= 0.72:
		queue_free()
		return
	var viewport_size := get_viewport_rect().size
	if size != viewport_size:
		position = Vector2.ZERO
		size = viewport_size
	queue_redraw()

func _draw() -> void:
	if target == null or not is_instance_valid(target) or size.x <= 1.0 or size.y <= 1.0:
		return
	_active_player_occlusion_rect = _player_occlusion_rect()
	var center := _project(target.global_position)
	var safe_rect := Rect2(Vector2(54.0, 54.0), size - Vector2(108.0, 108.0))
	if safe_rect.has_point(center):
		_draw_world_marker(center)
	else:
		_draw_offscreen_arrow(center, safe_rect)

func _draw_world_marker(center: Vector2) -> void:
	var color := _primary_color()
	var danger := Color(1.0, 0.25, 0.20, 0.95)
	var pulse := 0.5 + 0.5 * sin(_elapsed * (5.6 if player_inside else 2.4))
	var footprint := _projected_footprint_points()
	if footprint.size() != 4:
		return

	var state_alpha := 0.78 + pulse * 0.18 if player_inside else 0.58 + pulse * 0.10
	_draw_protocol_texture(footprint, Color(color.r, color.g, color.b, state_alpha))
	_draw_protocol_perimeter(footprint, Color(0.03, 0.08, 0.12, 0.72), 5.0)
	if progress > 0.001:
		_draw_protocol_perimeter(footprint, color, 4.0, progress)

	if player_inside and not completed:
		var wave_scale := 0.55 + fmod(_elapsed * 0.9, 1.0) * 0.34
		var wave_alpha := (1.0 - fmod(_elapsed * 0.9, 1.0)) * 0.28
		_draw_protocol_perimeter(_scale_footprint(footprint, wave_scale), Color(color.r, color.g, color.b, wave_alpha), 2.0)

	if enemy_count > 0 and not completed:
		_draw_protocol_danger_corners(footprint, danger)

	_draw_center_icon(center, color, pulse)
	if completed:
		var completion_ratio := clampf(_completion_elapsed / 0.72, 0.0, 1.0)
		var flash_alpha := (1.0 - completion_ratio) * 0.7
		_draw_protocol_perimeter(_scale_footprint(footprint, 0.72 + completion_ratio * 0.58), Color(color.r, color.g, color.b, flash_alpha), 4.0)
		_draw_check(center, Color(0.86, 1.0, 0.80, 0.98))

func _projected_footprint_points() -> PackedVector2Array:
	if target == null or not is_instance_valid(target):
		return PackedVector2Array()
	var half := footprint_size * 0.5
	var local_corners := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	var projected := PackedVector2Array()
	for corner in local_corners:
		projected.append(_project(target.global_transform * corner))
	return projected


func _draw_protocol_texture(footprint: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray([color, color, color, color])
	var uvs := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	draw_polygon(footprint, colors, uvs, PROTOCOL_SQUARE_TEXTURE)


func _draw_protocol_perimeter(
	footprint: PackedVector2Array,
	color: Color,
	width: float,
	ratio: float = 1.0,
) -> void:
	var points := _closed_footprint(footprint)
	var visible_points := _polyline_prefix(points, clampf(ratio, 0.0, 1.0))
	_draw_occlusion_safe_polyline(visible_points, color, width)


func _closed_footprint(footprint: PackedVector2Array) -> PackedVector2Array:
	var points := footprint.duplicate()
	if not points.is_empty():
		points.append(points[0])
	return points


func _scale_footprint(footprint: PackedVector2Array, scale_value: float) -> PackedVector2Array:
	if footprint.size() != 4:
		return footprint
	var center := Vector2.ZERO
	for point in footprint:
		center += point
	center /= float(footprint.size())
	var scaled := PackedVector2Array()
	for point in footprint:
		scaled.append(center + (point - center) * scale_value)
	return scaled


func _polyline_prefix(points: PackedVector2Array, ratio: float) -> PackedVector2Array:
	if points.size() < 2 or ratio <= 0.0:
		return PackedVector2Array()
	if ratio >= 1.0:
		return points
	var total_length := 0.0
	for index in range(points.size() - 1):
		total_length += points[index].distance_to(points[index + 1])
	var remaining := total_length * ratio
	var result := PackedVector2Array([points[0]])
	for index in range(points.size() - 1):
		var segment_length := points[index].distance_to(points[index + 1])
		if remaining >= segment_length:
			result.append(points[index + 1])
			remaining -= segment_length
			continue
		if segment_length > 0.0:
			result.append(points[index].lerp(points[index + 1], remaining / segment_length))
		break
	return result


func _draw_protocol_danger_corners(footprint: PackedVector2Array, color: Color) -> void:
	if footprint.size() != 4:
		return
	for corner_index in range(4):
		var previous_index := (corner_index + 3) % 4
		var next_index := (corner_index + 1) % 4
		var previous := footprint[corner_index].lerp(footprint[previous_index], 0.20)
		var next := footprint[corner_index].lerp(footprint[next_index], 0.20)
		_draw_occlusion_safe_polyline(PackedVector2Array([previous, footprint[corner_index], next]), color, 4.0)

func _draw_center_icon(center: Vector2, color: Color, pulse: float) -> void:
	var icon_radius := 14.0 + pulse * 1.5
	if _active_player_occlusion_rect.intersects(Rect2(center - Vector2.ONE * icon_radius, Vector2.ONE * icon_radius * 2.0)):
		return
	draw_circle(center, icon_radius, Color(0.025, 0.07, 0.10, 0.88))
	draw_arc(center, icon_radius, 0.0, TAU_F, 28, Color(color.r, color.g, color.b, 0.92), 2.0, true)
	match visual_kind:
		CONTAINMENT:
			var rift := PackedVector2Array([
				center + Vector2(0.0, -9.0),
				center + Vector2(5.0, -3.0),
				center + Vector2(-2.0, 1.0),
				center + Vector2(4.0, 8.0),
				center + Vector2(-5.0, 3.0),
				center + Vector2(0.0, -9.0),
			])
			draw_polyline(rift, color, 3.0, true)
		EXTRACTION:
			for offset_x in [-5.0, 0.0, 5.0]:
				var tip := center + Vector2(offset_x, -7.0)
				draw_line(tip, tip + Vector2(0.0, 11.0), color, 2.0, true)
				draw_line(tip, tip + Vector2(-3.0, 4.0), color, 2.0, true)
				draw_line(tip, tip + Vector2(3.0, 4.0), color, 2.0, true)
		_:
			draw_line(center + Vector2(0.0, 7.0), center + Vector2(0.0, -5.0), color, 2.5, true)
			draw_circle(center + Vector2(0.0, -7.0), 2.8, color)
			draw_arc(center + Vector2(0.0, -5.0), 7.0, -PI * 0.86, -PI * 0.14, 12, color, 2.0, true)
			draw_string(ThemeDB.fallback_font, center + Vector2(8.0, -7.0), str(beacon_id), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, color)

func _draw_offscreen_arrow(target_screen: Vector2, safe_rect: Rect2) -> void:
	var screen_center := size * 0.5
	var direction := (target_screen - screen_center).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var edge := _ray_rect_intersection(screen_center, direction, safe_rect)
	var color := _primary_color()
	var angle := direction.angle()
	var tip := edge + direction * 7.0
	var left := edge - direction * 13.0 + direction.rotated(PI * 0.5) * 10.0
	var right := edge - direction * 13.0 - direction.rotated(PI * 0.5) * 10.0
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(color.r, color.g, color.b, 0.96))
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color(0.02, 0.06, 0.09, 0.95), 2.0, true)
	var icon_center := edge - direction * 25.0
	draw_circle(icon_center, 11.0, Color(0.02, 0.06, 0.09, 0.90))
	draw_arc(icon_center, 11.0, 0.0, TAU_F, 20, color, 2.0, true)
	_draw_small_protocol_glyph(icon_center, color, angle)

func _draw_small_protocol_glyph(center: Vector2, color: Color, _angle: float) -> void:
	match visual_kind:
		CONTAINMENT:
			draw_polyline(PackedVector2Array([center + Vector2(0, -6), center + Vector2(3, -1), center + Vector2(-2, 2), center + Vector2(2, 6)]), color, 2.0, true)
		EXTRACTION:
			draw_line(center + Vector2(0, 5), center + Vector2(0, -5), color, 2.0, true)
			draw_line(center + Vector2(0, -5), center + Vector2(-4, 0), color, 2.0, true)
			draw_line(center + Vector2(0, -5), center + Vector2(4, 0), color, 2.0, true)
		_:
			draw_line(center + Vector2(0, 5), center + Vector2(0, -4), color, 2.0, true)
			draw_circle(center + Vector2(0, -5), 2.0, color)

func _draw_check(center: Vector2, color: Color) -> void:
	if _active_player_occlusion_rect.intersects(Rect2(center - Vector2(10.0, 8.0), Vector2(20.0, 16.0))):
		return
	draw_line(center + Vector2(-7.0, 0.0), center + Vector2(-2.0, 6.0), color, 3.0, true)
	draw_line(center + Vector2(-2.0, 6.0), center + Vector2(8.0, -6.0), color, 3.0, true)

func _draw_occlusion_safe_polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	for visible_run in _split_polyline_around_rect(points, _active_player_occlusion_rect):
		draw_polyline(visible_run, color, width, true)

func _split_polyline_around_rect(points: PackedVector2Array, _occlusion_rect: Rect2) -> Array[PackedVector2Array]:
	var visible_runs: Array[PackedVector2Array] = []
	if points.size() < 2:
		return visible_runs
	# Protocol perimeter and progress lines are gameplay state, so they remain
	# complete even when the player overlaps them. The occlusion rectangle is
	# still used by center glyphs, but must not remove any perimeter segment.
	visible_runs.append(points)
	return visible_runs

func _player_occlusion_rect() -> Rect2:
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player) or not player.visible:
		return Rect2()
	var visual_source: Node2D
	for node_name in [&"MechaMoveSprite", &"MechaSprite"]:
		var candidate := player.get_node_or_null(NodePath(str(node_name))) as Node2D
		if candidate != null and candidate.visible and candidate.has_method("get_unit_billboard_config"):
			visual_source = candidate
			break
	if visual_source == null:
		return Rect2()
	var config := visual_source.call("get_unit_billboard_config") as Dictionary
	if not bool(config.get("visible", true)):
		return Rect2()
	var visual_size := config.get("visual_size_px", Vector2.ZERO) as Vector2
	if visual_size.x <= 0.0 or visual_size.y <= 0.0:
		return Rect2()
	var bottom_padding := clampf(float(config.get("bottom_padding_px", 0.0)), 0.0, visual_size.y * 0.49)
	var local_ground_anchor := config.get("local_ground_anchor", Vector2.ZERO) as Vector2
	var anchor_screen := _project(player.global_transform * local_ground_anchor)
	var top_left := anchor_screen - Vector2(visual_size.x * 0.5, visual_size.y - bottom_padding) - PLAYER_OCCLUSION_PADDING
	return Rect2(top_left, visual_size + PLAYER_OCCLUSION_PADDING * 2.0)

func _ray_rect_intersection(origin: Vector2, direction: Vector2, rect: Rect2) -> Vector2:
	var distances: Array[float] = []
	if absf(direction.x) > 0.0001:
		distances.append((rect.position.x - origin.x) / direction.x)
		distances.append((rect.end.x - origin.x) / direction.x)
	if absf(direction.y) > 0.0001:
		distances.append((rect.position.y - origin.y) / direction.y)
		distances.append((rect.end.y - origin.y) / direction.y)
	var best := INF
	for distance in distances:
		if distance <= 0.0:
			continue
		var point := origin + direction * distance
		if rect.grow(0.5).has_point(point):
			best = minf(best, distance)
	return origin + direction * best if best < INF else rect.get_center()

func _project(world_position: Vector2) -> Vector2:
	var view := ProjectedUi.get_hybrid_view(get_tree())
	if view != null:
		return view.call("project_world_to_screen", world_position) as Vector2
	return get_viewport().get_canvas_transform() * world_position

func _primary_color() -> Color:
	match visual_kind:
		CONTAINMENT:
			return Color(0.92, 0.32, 0.96, 0.98)
		EXTRACTION:
			return Color(0.72, 1.0, 0.36, 0.98)
		_:
			return Color(0.30, 0.86, 1.0, 0.98)
