extends Label


func set_data(label_text: String, color: Color, style: StyleBox) -> void:
	text = label_text
	add_theme_color_override("font_color", color)
	add_theme_stylebox_override("normal", style)
