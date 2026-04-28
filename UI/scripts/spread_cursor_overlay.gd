extends Control

@export var ring_color: Color = Color(0.33, 0.66, 1.0, 0.22)
@export var ammo_color: Color = Color(0.33, 0.66, 1.0, 0.95)
@export var center_dot_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var ring_width: float = 1.6
@export var ammo_width: float = 2.2
@export var center_dot_radius: float = 1.8
@export var min_offset_px: float = 8.0
@export var max_offset_px: float = 220.0

var _screen_center: Vector2 = Vector2.ZERO
var _screen_offset_px: float = 10.0
var _ammo_visible: bool = false
var _ammo_progress: float = 1.0
var _ammo_clockwise: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 300

func set_world_anchor_and_radius(world_pos: Vector2, world_radius: float) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var canvas_transform := viewport.get_canvas_transform()
	var center := canvas_transform * world_pos
	var edge_world := world_pos + Vector2(maxf(world_radius, 0.0), 0.0)
	var edge := canvas_transform * edge_world
	var offset_px := center.distance_to(edge)
	_screen_center = center
	_screen_offset_px = clampf(offset_px, min_offset_px, max_offset_px)
	queue_redraw()

func set_fallback_screen_radius(radius_px: float) -> void:
	var viewport := get_viewport()
	if viewport != null:
		_screen_center = viewport.get_mouse_position()
	_screen_offset_px = clampf(radius_px, min_offset_px, max_offset_px)
	queue_redraw()

func set_cursor_screen_position(screen_pos: Vector2) -> void:
	_screen_center = screen_pos
	queue_redraw()

func set_ammo_progress(progress: float, clockwise: bool = false, visible: bool = true) -> void:
	_ammo_visible = visible
	_ammo_clockwise = clockwise
	_ammo_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()

func clear_ammo_progress() -> void:
	_ammo_visible = false
	_ammo_progress = 0.0
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var points := _build_diamond_points()
	var top := points[0]
	var right := points[1]
	var bottom := points[2]
	var left := points[3]
	draw_line(top, right, ring_color, ring_width, true)
	draw_line(right, bottom, ring_color, ring_width, true)
	draw_line(bottom, left, ring_color, ring_width, true)
	draw_line(left, top, ring_color, ring_width, true)
	if _ammo_visible and _ammo_progress > 0.0:
		_draw_diamond_progress(_ammo_progress, _ammo_clockwise)
	draw_circle(_screen_center, center_dot_radius, center_dot_color)

func _build_diamond_points() -> Array[Vector2]:
	return [
		_screen_center + Vector2(0.0, -_screen_offset_px),
		_screen_center + Vector2(_screen_offset_px, 0.0),
		_screen_center + Vector2(0.0, _screen_offset_px),
		_screen_center + Vector2(-_screen_offset_px, 0.0),
	]

func _draw_diamond_progress(progress: float, clockwise: bool) -> void:
	var points := _build_diamond_points()
	var ordered := points.duplicate()
	if not clockwise:
		ordered = [points[0], points[3], points[2], points[1]]
	ordered.append(ordered[0])
	var total_len := 0.0
	for i in range(ordered.size() - 1):
		total_len += ordered[i].distance_to(ordered[i + 1])
	var target_len := total_len * clampf(progress, 0.0, 1.0)
	var remaining := target_len
	for i in range(ordered.size() - 1):
		if remaining <= 0.0:
			break
		var from_pt: Vector2 = ordered[i]
		var to_pt: Vector2 = ordered[i + 1]
		var seg_len := from_pt.distance_to(to_pt)
		if remaining >= seg_len:
			draw_line(from_pt, to_pt, ammo_color, ammo_width, true)
			remaining -= seg_len
			continue
		var t := remaining / maxf(seg_len, 0.0001)
		var partial_to := from_pt.lerp(to_pt, t)
		draw_line(from_pt, partial_to, ammo_color, ammo_width, true)
		remaining = 0.0
