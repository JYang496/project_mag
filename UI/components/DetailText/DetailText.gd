extends Label


func set_data(value: String, color: Color, font_size: int) -> void:
	text = value
	add_theme_color_override("font_color", color)
	add_theme_font_size_override("font_size", font_size)
