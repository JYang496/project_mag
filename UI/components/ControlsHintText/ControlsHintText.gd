extends Label


func set_data(value: String, styled: bool = false, style: StyleBox = null) -> void:
	text = value
	if styled and style != null:
		add_theme_stylebox_override("normal", style)
