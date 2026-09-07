extends Label

const CURRENT_COLOR := Color(0.95, 0.78, 0.30, 1.0)
const DEFAULT_COLOR := Color(0.68, 0.88, 1.0, 1.0)


func set_data(value: String, current: bool) -> void:
	text = value
	add_theme_color_override("font_color", CURRENT_COLOR if current else DEFAULT_COLOR)
