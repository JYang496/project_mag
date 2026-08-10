extends Control
class_name PlayerAmmoHud

const EMPTY_SLOT_COLOR := Color(0.05, 0.08, 0.09, 0.88)
const AMMO_FILL_COLOR := Color(0.36, 0.76, 1.0, 0.96)
const FRAME_COLOR := Color(0.62, 0.90, 1.0, 1.0)
const CONTAINER_SCREEN_OFFSET := Vector2(72.0, -34.0)
const VERTICAL_SLOT_SIZE := Vector2(10.0, 9.0)

@export var hud_size := Vector2(128.0, 64.0)
@export_range(1.0, 1.5, 0.01) var ring_radius_scale := 1.30
@export_range(2, 8, 1) var segment_count := 4

var _player: Node2D
var _ammo_visible := false
var _ammo_ratio := 0.0
var _arc_points := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = hud_size
	_player = get_parent().get_parent() as Node2D
	queue_redraw()


func _process(_delta: float) -> void:
	_sync_ammo_status()
	_sync_screen_position()


func set_ammo_status(current_ammo: int, capacity: int, enabled: bool) -> void:
	var next_visible := enabled and capacity > 0
	var next_ratio := clampf(float(current_ammo) / float(maxi(capacity, 1)), 0.0, 1.0) if next_visible else 0.0
	if next_visible == _ammo_visible and is_equal_approx(next_ratio, _ammo_ratio):
		return
	_ammo_visible = next_visible
	_ammo_ratio = next_ratio
	visible = next_visible
	queue_redraw()


func get_ammo_ratio() -> float:
	return _ammo_ratio


func _sync_ammo_status() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.has_method("get_main_weapon"):
		set_ammo_status(0, 0, false)
		return
	var weapon := _player.call("get_main_weapon") as Node
	if weapon == null or not is_instance_valid(weapon):
		set_ammo_status(0, 0, false)
		return
	var uses_ammo := weapon.has_method("uses_ammo_system") and bool(weapon.call("uses_ammo_system"))
	var capacity := int(weapon.call("get_effective_magazine_capacity")) if weapon.has_method("get_effective_magazine_capacity") else int(weapon.get("magazine_capacity"))
	var current_value: Variant = weapon.get("current_ammo")
	set_ammo_status(int(current_value) if current_value != null else 0, capacity, uses_ammo)


func _sync_screen_position() -> void:
	if _player == null or not is_instance_valid(_player):
		visible = false
		return
	var ground_anchor := Vector2.ZERO
	var shadow := _player.get_node_or_null("GroundShadow") as Node2D
	if shadow != null:
		ground_anchor = shadow.position
	var logical_anchor := _player.global_transform * ground_anchor
	var screen_position := _player.get_global_transform_with_canvas() * ground_anchor
	var footprint := Vector2(46.0, 46.0)
	var marker := _player.get_node_or_null("AffiliationMarker")
	if marker != null and marker.has_method("get_hybrid_ground_marker_config"):
		var marker_config := marker.call("get_hybrid_ground_marker_config") as Dictionary
		footprint = marker_config.get("footprint_size", footprint) as Vector2
	var views := get_tree().get_nodes_in_group(&"hybrid_ground_view_3d")
	var view: Node = null
	if not views.is_empty():
		view = views[0] as Node
		if view != null and view.has_method("project_world_to_screen"):
			screen_position = view.call("project_world_to_screen", logical_anchor) as Vector2
	position = (screen_position - size * 0.5).round()
	var next_points := PackedVector2Array()
	for index in range(17):
		var weight := float(index) / 16.0
		var angle := lerpf(0.0, PI * 0.5, weight)
		var local_point := ground_anchor + Vector2(
			cos(angle) * footprint.x * 0.5 * ring_radius_scale,
			sin(angle) * footprint.y * 0.5 * ring_radius_scale
		)
		var projected := _player.get_global_transform_with_canvas() * local_point
		if view != null and view.has_method("project_world_to_screen"):
			projected = view.call("project_world_to_screen", _player.global_transform * local_point) as Vector2
		next_points.append(projected - position)
	if next_points != _arc_points:
		_arc_points = next_points
		queue_redraw()
	visible = _ammo_visible and _player.visible


func _draw() -> void:
	if not _ammo_visible:
		return
	var track := _arc_points
	if track.size() < 2:
		return
	var geometry := _get_vertical_geometry(track)
	var slot_polygons := _get_vertical_slot_polygons(geometry)
	for polygon in slot_polygons:
		draw_colored_polygon(polygon, EMPTY_SLOT_COLOR)
	if _ammo_ratio > 0.001:
		var fill_levels := _get_slot_fill_levels(_ammo_ratio, slot_polygons.size())
		for index in range(slot_polygons.size()):
			var level := fill_levels[index]
			if level <= 0.001:
				continue
			var fill_color := AMMO_FILL_COLOR
			fill_color.a = lerpf(0.48, AMMO_FILL_COLOR.a, level)
			draw_colored_polygon(slot_polygons[index], fill_color)
	_draw_vertical_frame(geometry)


func _get_vertical_geometry(track: PackedVector2Array) -> Dictionary:
	if track.size() < 2:
		return {}
	var anchor := Vector2(track[-1].x, track[0].y) + CONTAINER_SCREEN_OFFSET
	var frame_size := Vector2(VERTICAL_SLOT_SIZE.x, VERTICAL_SLOT_SIZE.y * float(segment_count))
	return {
		"rect": Rect2(anchor - frame_size * 0.5, frame_size),
		"slot_size": VERTICAL_SLOT_SIZE,
	}


func _get_vertical_slot_polygons(geometry: Dictionary) -> Array[PackedVector2Array]:
	var slots: Array[PackedVector2Array] = []
	if geometry.is_empty():
		return slots
	var frame_rect := geometry.get("rect", Rect2()) as Rect2
	var slot_height := frame_rect.size.y / float(maxi(segment_count, 1))
	for slot_index in range(segment_count):
		var top_left := frame_rect.position + Vector2(0.0, slot_height * float(slot_index))
		var bottom_right := top_left + Vector2(frame_rect.size.x, slot_height)
		slots.append(PackedVector2Array([
			top_left,
			Vector2(bottom_right.x, top_left.y),
			bottom_right,
			Vector2(top_left.x, bottom_right.y),
		]))
	return slots


func _draw_vertical_frame(geometry: Dictionary) -> void:
	if geometry.is_empty():
		return
	var frame_rect := geometry.get("rect", Rect2()) as Rect2
	draw_rect(frame_rect, FRAME_COLOR, false, 1.5, false)
	var slot_height := frame_rect.size.y / float(maxi(segment_count, 1))
	for divider_index in range(1, segment_count):
		var y := frame_rect.position.y + slot_height * float(divider_index)
		draw_line(Vector2(frame_rect.position.x, y), Vector2(frame_rect.end.x, y), FRAME_COLOR, 1.5, false)


func _get_slot_fill_levels(ratio: float, slots: int) -> PackedFloat32Array:
	var levels := PackedFloat32Array()
	var remaining := clampf(ratio, 0.0, 1.0) * float(maxi(slots, 0))
	for index in range(maxi(slots, 0)):
		var distance_from_vertical_start := float(maxi(slots, 0) - 1 - index)
		levels.append(clampf(remaining - distance_from_vertical_start, 0.0, 1.0))
	return levels


func _build_fill_points(track: PackedVector2Array, ratio: float) -> PackedVector2Array:
	var fill := PackedVector2Array()
	if track.size() < 2 or ratio <= 0.0:
		return fill
	if ratio >= 1.0:
		return track.duplicate()
	var start_position := float(track.size() - 1) * (1.0 - clampf(ratio, 0.0, 1.0))
	var start_index := clampi(int(floor(start_position)), 0, track.size() - 2)
	var start_weight := start_position - float(start_index)
	fill.append(track[start_index].lerp(track[start_index + 1], start_weight))
	for index in range(start_index + 1, track.size()):
		fill.append(track[index])
	return fill


func _draw_square_path(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var polygon := _build_ribbon_polygon(points, width)
	if _is_drawable_polygon(polygon):
		draw_colored_polygon(polygon, color)


func _is_drawable_polygon(polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var twice_area := 0.0
	for point in polygon:
		if not is_finite(point.x) or not is_finite(point.y):
			return false
	for index in range(polygon.size()):
		var next_index := (index + 1) % polygon.size()
		twice_area += polygon[index].cross(polygon[next_index])
	if absf(twice_area) <= 0.001:
		return false
	return not Geometry2D.triangulate_polygon(polygon).is_empty()


func _build_ribbon_polygon(points: PackedVector2Array, width: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if points.size() < 2:
		return polygon
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var half_width := maxf(width, 0.0) * 0.5
	for index in range(points.size()):
		var normal := _get_path_normal(points, index) * half_width
		upper.append(points[index] + normal)
		lower.append(points[index] - normal)
	polygon.append_array(upper)
	for index in range(lower.size() - 1, -1, -1):
		polygon.append(lower[index])
	return polygon


func _get_path_normal(points: PackedVector2Array, index: int) -> Vector2:
	if points.size() < 2:
		return Vector2.UP
	var previous := points[maxi(index - 1, 0)]
	var next := points[mini(index + 1, points.size() - 1)]
	var tangent := (next - previous).normalized()
	if tangent == Vector2.ZERO:
		return Vector2.UP
	return Vector2(-tangent.y, tangent.x)
