extends Label


func set_data(label_text: String, satisfied: bool) -> void:
	text = label_text
	var color := Color(0.16, 0.72, 0.28) if satisfied else Color(0.9, 0.18, 0.14)
	add_theme_color_override("font_color", Color(0.42, 0.94, 0.52) if satisfied else Color(1.0, 0.36, 0.3))
	var style := (get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = Color(color.r, color.g, color.b, 0.1)
	style.border_color = Color(color.r, color.g, color.b, 0.9)
	add_theme_stylebox_override("normal", style)
