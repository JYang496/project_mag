extends Control
class_name WeaponPassiveIcon

@export var icon_color := Color(1.0, 0.78, 0.22, 1.0):
	set(value):
		icon_color = value
		queue_redraw()

func _draw() -> void:
	# A compact, language-independent passive marker: circuit diamond + core.
	var center := Vector2(floorf(size.x * 0.5), floorf(size.y * 0.5))
	var radius := floorf(minf(size.x, size.y) * 0.42)
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
		center + Vector2(0.0, -radius),
	])
	draw_polyline(points, Color(0.03, 0.04, 0.05, 0.96), 4.0)
	draw_polyline(points, icon_color, 2.0)
	draw_rect(Rect2(center - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), icon_color)
