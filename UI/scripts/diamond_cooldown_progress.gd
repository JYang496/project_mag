extends Control
class_name DiamondCooldownProgress

@export_range(0.0, 1.0, 0.001) var progress: float = 1.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

@export var line_width: float = 3.0
@export var padding: float = 6.0
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.18)
@export var fill_color: Color = Color(0.95, 0.85, 0.35, 0.95)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var points := _build_diamond_points()
	if points.size() < 4:
		return
	var closed_points: PackedVector2Array = PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	draw_polyline(closed_points, base_color, maxf(line_width, 0.5), true)

	if progress <= 0.0:
		return
	var fill_points := _build_progress_polyline(points, progress)
	if fill_points.size() >= 2:
		draw_polyline(fill_points, fill_color, maxf(line_width, 0.5), true)

func _build_diamond_points() -> PackedVector2Array:
	var rect := Rect2(Vector2.ZERO, size)
	var inset := maxf(padding, 0.0)
	var inner := rect.grow(-inset)
	if inner.size.x <= 1.0 or inner.size.y <= 1.0:
		return PackedVector2Array()
	var center := inner.get_center()
	var top := Vector2(center.x, inner.position.y)
	var right := Vector2(inner.position.x + inner.size.x, center.y)
	var bottom := Vector2(center.x, inner.position.y + inner.size.y)
	var left := Vector2(inner.position.x, center.y)
	return PackedVector2Array([top, right, bottom, left])

func _build_progress_polyline(points: PackedVector2Array, value: float) -> PackedVector2Array:
	var target_len := _diamond_perimeter(points) * clampf(value, 0.0, 1.0)
	if target_len <= 0.0:
		return PackedVector2Array()

	var output: PackedVector2Array = PackedVector2Array([points[0]])
	var remain := target_len
	for i in range(points.size()):
		var start := points[i]
		var next := points[(i + 1) % points.size()]
		var segment := start.distance_to(next)
		if segment <= 0.0001:
			continue
		if remain >= segment:
			output.append(next)
			remain -= segment
			continue
		var t := remain / segment
		output.append(start.lerp(next, t))
		break
	return output

func _diamond_perimeter(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size()):
		total += points[i].distance_to(points[(i + 1) % points.size()])
	return total
