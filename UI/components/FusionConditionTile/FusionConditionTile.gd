extends Label


func set_data(label_text: String, satisfied: bool, style: StyleBox) -> void:
	text = label_text
	add_theme_color_override("font_color", Color(0.42, 0.94, 0.52) if satisfied else Color(1.0, 0.36, 0.3))
	add_theme_stylebox_override("normal", style)
