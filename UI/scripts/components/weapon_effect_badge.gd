extends Control
## A pictogram describing the player action that advances or consumes a passive.
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
	draw_circle(Vector2(10,10), 11, Color(0.01,0.025,0.035,0.9))
	draw_arc(Vector2(10,10), 10, 0, TAU, 32, Color(tint.r,tint.g,tint.b,0.28), 1.0, true)
	match symbol:
		# Legacy resource-state symbols remain available because resource indicators
		# share this lightweight drawing component. Passive badges no longer use them.
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
			draw_line(Vector2(10, 3), Vector2(10, 17), tint, 1.0)
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
		"fire":
			# Trigger pull plus a projectile leaving the muzzle: "next attack".
			draw_line(Vector2(3, 12), Vector2(12, 12), tint, 3.0, true)
			draw_polyline(PackedVector2Array([Vector2(9, 7), Vector2(15, 12), Vector2(9, 17)]), tint, 2.0, true)
			draw_line(Vector2(16, 12), Vector2(19, 12), tint, 2.0, true)
		"reload":
			# Circular arrow: the stored effect is consumed when reload starts.
			draw_arc(Vector2(10, 10), 7, -PI, PI / 2, 20, tint, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(6, 14), Vector2(10, 14), Vector2(10, 19)]), tint)
		"swap":
			# Opposed arrows: move this weapon into the main-hand slot.
			draw_line(Vector2(3, 7), Vector2(16, 7), tint, 2.0, true)
			draw_polyline(PackedVector2Array([Vector2(13, 3), Vector2(17, 7), Vector2(13, 11)]), tint, 2.0, true)
			draw_line(Vector2(17, 15), Vector2(4, 15), tint, 2.0, true)
			draw_polyline(PackedVector2Array([Vector2(7, 11), Vector2(3, 15), Vector2(7, 19)]), tint, 2.0, true)
		"timer":
			# Clock face: the number alongside it is the rounded-up wait time.
			draw_arc(Vector2(10, 11), 7, 0, TAU, 24, tint, 2.0, true)
			draw_line(Vector2(10, 11), Vector2(10, 6), tint, 2.0, true)
			draw_line(Vector2(10, 11), Vector2(14, 13), tint, 2.0, true)
			draw_line(Vector2(7, 2), Vector2(13, 2), tint, 2.0, true)
		"skill":
			# Four-point spark: release the weapon skill.
			draw_colored_polygon(PackedVector2Array([Vector2(10, 1), Vector2(13, 7), Vector2(19, 10), Vector2(13, 13), Vector2(10, 19), Vector2(7, 13), Vector2(1, 10), Vector2(7, 7)]), tint)
		_:
			draw_line(Vector2(4, 10), Vector2(16, 10), tint, 2.0, true)
	if count > 0:
		draw_string(ThemeDB.fallback_font, Vector2(22, 16), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
