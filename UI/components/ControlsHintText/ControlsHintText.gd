extends Label


func set_data(value: String, styled: bool = false) -> void:
	text = value
	if not styled:
		remove_theme_stylebox_override("normal")
