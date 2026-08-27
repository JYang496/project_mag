extends Control
class_name EnhancedContractFrame

## Presentation-only frame for opt-in enhanced contracts. Protocol logic owns when
## this is enabled; this component owns only the protocol-colored armor silhouette.

var enhanced := false:
	set(value):
		enhanced = value
		visible = value
		queue_redraw()

var frame_color := Color.WHITE:
	set(value):
		frame_color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	visible = enhanced


func set_enhanced(value: bool, protocol_color: Color = frame_color) -> void:
	frame_color = protocol_color
	enhanced = value


func _draw() -> void:
	if not enhanced:
		return
	var right := floorf(size.x) - 3.0
	var bottom := floorf(size.y) - 3.0
	var center_x := floorf(size.x * 0.5)
	var outer := frame_color.lightened(0.18)
	var glow := Color(frame_color.r, frame_color.g, frame_color.b, 0.16)
	var inner := Color(frame_color.r, frame_color.g, frame_color.b, 0.62)
	# A restrained inner tint makes enhanced mode read as a state, while the
	# brighter armor silhouette remains its primary identifier.
	draw_rect(Rect2(7, 7, maxf(size.x - 14, 0), maxf(size.y - 14, 0)), Color(frame_color.r, frame_color.g, frame_color.b, 0.035), true)
	draw_polyline(PackedVector2Array([Vector2(34, 3), Vector2(3, 3), Vector2(3, 34)]), glow, 12.0, false)
	draw_polyline(PackedVector2Array([Vector2(right - 31, 3), Vector2(right, 3), Vector2(right, 34)]), glow, 12.0, false)
	draw_polyline(PackedVector2Array([Vector2(3, bottom - 31), Vector2(3, bottom), Vector2(34, bottom)]), glow, 12.0, false)
	draw_polyline(PackedVector2Array([Vector2(right - 31, bottom), Vector2(right, bottom), Vector2(right, bottom - 31)]), glow, 12.0, false)
	_draw_corner(PackedVector2Array([Vector2(3, 39), Vector2(3, 12), Vector2(12, 3), Vector2(39, 3)]), outer)
	_draw_corner(PackedVector2Array([Vector2(right - 36, 3), Vector2(right - 9, 3), Vector2(right, 12), Vector2(right, 39)]), outer)
	_draw_corner(PackedVector2Array([Vector2(3, bottom - 36), Vector2(3, bottom - 9), Vector2(12, bottom), Vector2(39, bottom)]), outer)
	_draw_corner(PackedVector2Array([Vector2(right - 36, bottom), Vector2(right - 9, bottom), Vector2(right, bottom - 9), Vector2(right, bottom - 36)]), outer)
	draw_line(Vector2(43, 3), Vector2(center_x - 76, 3), outer, 5.0, false)
	draw_line(Vector2(center_x + 76, 3), Vector2(right - 40, 3), outer, 5.0, false)
	draw_line(Vector2(43, bottom), Vector2(center_x - 58, bottom), outer, 5.0, false)
	draw_line(Vector2(center_x + 58, bottom), Vector2(right - 40, bottom), outer, 5.0, false)
	var plate := PackedVector2Array([
		Vector2(center_x - 68, 1), Vector2(center_x + 68, 1),
		Vector2(center_x + 56, 12), Vector2(center_x - 56, 12),
	])
	draw_colored_polygon(plate, Color(frame_color.r, frame_color.g, frame_color.b, 0.34))
	draw_polyline(PackedVector2Array([plate[0], plate[1], plate[2], plate[3], plate[0]]), outer, 2.0, false)
	for index in range(3):
		var node_x := center_x - 16.0 + float(index * 13)
		draw_rect(Rect2(node_x, 4, 7, 5), outer, true)
	var inset := Rect2(10, 10, maxf(size.x - 20, 0), maxf(size.y - 20, 0))
	_draw_dashed_edge(Vector2(inset.position.x, inset.position.y + 34), Vector2(inset.position.x, inset.end.y - 34), inner)
	_draw_dashed_edge(Vector2(inset.end.x, inset.position.y + 34), Vector2(inset.end.x, inset.end.y - 34), inner)
	_draw_dashed_edge(Vector2(inset.position.x + 34, inset.end.y), Vector2(inset.end.x - 34, inset.end.y), inner)


func _draw_corner(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, Color(color.r, color.g, color.b, 0.22), 11.0, false)
	draw_polyline(points, color, 5.0, false)


func _draw_dashed_edge(from: Vector2, to: Vector2, color: Color) -> void:
	var distance := from.distance_to(to)
	if distance <= 0.0:
		return
	var direction := from.direction_to(to)
	var cursor := 0.0
	while cursor < distance:
		var segment_end := minf(cursor + 16.0, distance)
		draw_line(from + direction * cursor, from + direction * segment_end, color, 2.0, false)
		cursor += 25.0
