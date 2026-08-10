extends Control
class_name PlayerAmmoHud

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const AMMO_CONTAINER_TEXTURE: Texture2D = preload("res://UI/themes/player_ammo_hud/generated/ammo_container.png")

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


func has_container_texture() -> bool:
	return AMMO_CONTAINER_TEXTURE != null


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
	draw_texture_rect(AMMO_CONTAINER_TEXTURE, _get_container_rect(track), false)
	if _ammo_ratio > 0.001:
		var fill := _build_fill_points(track, _ammo_ratio)
		_draw_square_path(fill, PALETTE.PLAYER_PRIMARY, 2.6)


func _get_container_rect(track: PackedVector2Array) -> Rect2:
	if track.is_empty():
		return Rect2()
	var bounds := Rect2(track[0], Vector2.ZERO)
	for point in track:
		bounds = bounds.expand(point)
	return bounds.grow(6.0)


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
