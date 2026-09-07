extends Label


func set_data(value: String, font_size: int, color: Color) -> void:
	text = value
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
