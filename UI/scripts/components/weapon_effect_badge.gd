extends Control
## A pictogram for an actionable passive or a resource restriction.
var symbol := ""
var count := 0
var tint := Color("f4bc53")

func configure(value: String, amount: int = 0, color: Color = Color("f4bc53")) -> void:
	if value == symbol and count == amount and color == tint:
		return
	symbol = value
	count = amount
	tint = color
	queue_redraw()

func _draw() -> void:
	if symbol != "ammo":
		draw_circle(Vector2(10,10), 11, Color(0.01,0.025,0.035,0.9))
		draw_arc(Vector2(10,10), 10, 0, TAU, 32, Color(tint.r,tint.g,tint.b,0.28), 1.0, true)
	match symbol:
		"ammo":
			draw_colored_polygon(PackedVector2Array([Vector2(7, 17), Vector2(7, 6), Vector2(10, 2), Vector2(13, 6), Vector2(13, 17)]), tint)
			draw_line(Vector2(6, 19), Vector2(14, 19), tint, 2.0)
		"heat":
			draw_polyline(PackedVector2Array([Vector2(10, 2), Vector2(5, 9), Vector2(4, 14), Vector2(8, 18), Vector2(14, 17), Vector2(17, 11), Vector2(12, 13), Vector2(10, 2)]), tint, 2.0)
		"cold":
			for i in range(3):
				var delta := Vector2.from_angle(i * PI / 3) * 8
				draw_line(Vector2(10, 10) - delta, Vector2(10, 10) + delta, tint, 2.0)
		"pierce":
			draw_line(Vector2(2, 10), Vector2(18, 10), tint, 2.0)
			draw_line(Vector2(10, 3), Vector2(10, 17), tint, 2.0)
			draw_polyline(PackedVector2Array([Vector2(13, 5), Vector2(18, 10), Vector2(13, 15)]), tint, 2.0)
		"blast":
			for i in range(8):
				var delta := Vector2.from_angle(i * TAU / 8)
				draw_line(Vector2(10, 10) + delta * 3, Vector2(10, 10) + delta * 8, tint, 2.0)
		"range":
			draw_arc(Vector2(10, 10), 5, 0, TAU, 16, tint, 1.0)
			draw_line(Vector2(10, 1), Vector2(10, 19), tint, 1.0)
			draw_line(Vector2(1, 10), Vector2(19, 10), tint, 1.0)
		"energy":
			draw_colored_polygon(PackedVector2Array([Vector2(11, 1), Vector2(4, 11), Vector2(9, 11), Vector2(7, 19), Vector2(17, 7), Vector2(11, 7)]), tint)
		_:
			draw_arc(Vector2(10, 10), 7, -PI, PI / 2, 20, tint, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(6, 14), Vector2(10, 14), Vector2(10, 19)]), tint)
	if count > 1:
		draw_string(ThemeDB.fallback_font, Vector2(22, 16), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
