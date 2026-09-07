extends Label


func set_data(label_text: String, color: Color, filled: bool) -> void:
	text = label_text
	add_theme_color_override("font_color", color)
	var style := (get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = Color(color.r, color.g, color.b, 0.22 if filled else 0.07)
	style.border_color = color
	style.set_border_width_all(2 if filled else 1)
	add_theme_stylebox_override("normal", style)
