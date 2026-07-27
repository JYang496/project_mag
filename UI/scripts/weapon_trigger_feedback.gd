extends Control
class_name WeaponTriggerFeedback

@export var feedback_color := Color(1.0, 0.88, 0.38, 1.0):
	set(value):
		feedback_color = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var intensity := 0.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if intensity <= 0.001 or size.x <= 4.0 or size.y <= 4.0:
		return
	var outer := Rect2(Vector2(1.5, 1.5), size - Vector2(3.0, 3.0))
	var color := Color(
		feedback_color.r,
		feedback_color.g,
		feedback_color.b,
		feedback_color.a * intensity
	)
	draw_rect(outer, color, false, 2.0 + intensity * 1.5)
	var corner_length := minf(10.0, minf(size.x, size.y) * 0.22)
	var corner_color := Color(color.r, color.g, color.b, color.a * 0.86)
	for corner in [
		outer.position,
		Vector2(outer.end.x, outer.position.y),
		outer.end,
		Vector2(outer.position.x, outer.end.y),
	]:
		var x_dir := 1.0 if is_equal_approx(corner.x, outer.position.x) else -1.0
		var y_dir := 1.0 if is_equal_approx(corner.y, outer.position.y) else -1.0
		draw_line(corner, corner + Vector2(x_dir * corner_length, 0.0), corner_color, 2.0)
		draw_line(corner, corner + Vector2(0.0, y_dir * corner_length), corner_color, 2.0)
