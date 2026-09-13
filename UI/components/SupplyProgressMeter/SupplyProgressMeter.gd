extends Control
class_name SupplyProgressMeter

const TRACK_COLOR := Color(0.018, 0.075, 0.070, 0.96)
const TRACK_EDGE := Color(0.10, 0.38, 0.30, 0.95)
const FILL_COLOR := Color("f4c542")
const READY_FILL_COLOR := Color("ffe36a")
const FILL_EDGE := Color(1.0, 0.91, 0.48, 0.88)
const FILL_HIGHLIGHT := Color(1.0, 0.96, 0.72, 0.42)
const CUT_SIZE := 3.0
const INNER_PADDING := 2.0

@export_range(1.0, 40.0, 0.5) var smoothing_speed := 12.0

var _display_ratio := 0.0
var _target_ratio := 0.0
var _is_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	queue_redraw()


func set_target_value(value: float, immediate: bool = false) -> void:
	_target_ratio = clampf(value, 0.0, 1.0)
	if immediate or not is_inside_tree():
		_display_ratio = _target_ratio
		set_process(false)
		queue_redraw()
		return
	set_process(not is_equal_approx(_display_ratio, _target_ratio))


func set_ready(ready: bool) -> void:
	if _is_ready == ready:
		return
	_is_ready = ready
	queue_redraw()


func get_display_ratio() -> float:
	return _display_ratio


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-smoothing_speed * maxf(delta, 0.0))
	_display_ratio = lerpf(_display_ratio, _target_ratio, weight)
	if absf(_display_ratio - _target_ratio) <= 0.0005:
		_display_ratio = _target_ratio
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var track_rect := Rect2(Vector2.ZERO, size)
	_draw_cut_panel(track_rect, TRACK_COLOR, TRACK_EDGE, CUT_SIZE, 1.0)
	if _display_ratio <= 0.0:
		return
	var inner_rect := track_rect.grow(-INNER_PADDING)
	var fill_rect := Rect2(inner_rect.position, Vector2(inner_rect.size.x * _display_ratio, inner_rect.size.y))
	if fill_rect.size.x < 1.0:
		return
	var fill_color := READY_FILL_COLOR if _is_ready else FILL_COLOR
	_draw_cut_panel(fill_rect, fill_color, FILL_EDGE, minf(2.0, fill_rect.size.x * 0.35), 1.0)
	if fill_rect.size.x >= 7.0:
		draw_line(
			fill_rect.position + Vector2(3.0, 1.0),
			Vector2(fill_rect.end.x - 2.0, fill_rect.position.y + 1.0),
			FILL_HIGHLIGHT,
			1.0,
			true
		)


func _draw_cut_panel(rect: Rect2, fill_color: Color, edge_color: Color, cut: float, line_width: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points := _cut_rect_points(rect, cut)
	draw_colored_polygon(points, fill_color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, edge_color, line_width, true)


func _cut_rect_points(rect: Rect2, requested_cut: float) -> PackedVector2Array:
	var cut := minf(requested_cut, minf(rect.size.x, rect.size.y) * 0.45)
	return PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		Vector2(rect.end.x - cut, rect.position.y),
		Vector2(rect.end.x, rect.position.y + cut),
		rect.end - Vector2(0.0, cut),
		rect.end - Vector2(cut, 0.0),
		Vector2(rect.position.x + cut, rect.end.y),
		Vector2(rect.position.x, rect.end.y - cut),
		rect.position + Vector2(0.0, cut),
	])
