extends Control

var _accent_color := Color(0.45, 0.65, 0.85)
var _contract_id := ""

func setup(contract_id: String, accent_color: Color) -> void:
	_contract_id = contract_id
	_accent_color = accent_color
	queue_redraw()

func get_draw_center_local() -> Vector2:
	return size * 0.5

func _draw() -> void:
	var center := get_draw_center_local()
	match _contract_id:
		"survival":
			_draw_stopwatch(center)
		"elimination":
			_draw_crosshair(center)
		"reward":
			_draw_coin_stack(center)
		_:
			draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), _accent_color, false, 2.0)

func _draw_stopwatch(center: Vector2) -> void:
	draw_arc(center, 9.0, 0.0, TAU, 24, _accent_color, 2.0, true)
	draw_line(center + Vector2(0, -13), center + Vector2(0, -9), _accent_color, 2.0, true)
	draw_line(center + Vector2(-3, -13), center + Vector2(3, -13), _accent_color, 2.0, true)
	draw_line(center, center + Vector2(0, -5), _accent_color, 2.0, true)
	draw_line(center, center + Vector2(4, 2), _accent_color, 2.0, true)

func _draw_crosshair(center: Vector2) -> void:
	draw_arc(center, 8.0, 0.0, TAU, 24, _accent_color, 2.0, true)
	draw_arc(center, 2.0, 0.0, TAU, 12, _accent_color, 2.0, true)
	draw_line(center + Vector2(-13, 0), center + Vector2(-7, 0), _accent_color, 2.0, true)
	draw_line(center + Vector2(7, 0), center + Vector2(13, 0), _accent_color, 2.0, true)
	draw_line(center + Vector2(0, -13), center + Vector2(0, -7), _accent_color, 2.0, true)
	draw_line(center + Vector2(0, 7), center + Vector2(0, 13), _accent_color, 2.0, true)

func _draw_coin_stack(center: Vector2) -> void:
	draw_circle(center + Vector2(1, -2), 8.0, Color(0.13, 0.09, 0.02), true)
	draw_arc(center + Vector2(1, -2), 8.0, 0.0, TAU, 24, _accent_color, 2.0, true)
	draw_arc(center + Vector2(-3, 4), 7.0, 0.0, TAU, 24, _accent_color.darkened(0.15), 2.0, true)
	draw_line(center + Vector2(1, -6), center + Vector2(1, 2), _accent_color, 1.5, true)
