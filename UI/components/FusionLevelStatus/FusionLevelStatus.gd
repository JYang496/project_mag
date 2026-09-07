extends HBoxContainer

@onready var level_label: Label = %Level
@onready var state_label: Label = %State


func set_data(level_text: String, state_text: String, ready: bool) -> void:
	level_label.text = level_text
	state_label.text = state_text
	state_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.65) if ready else Color(1.0, 0.36, 0.3))
	var color := Color(0.16, 0.72, 0.28) if ready else Color(0.9, 0.18, 0.14)
	var style := (state_label.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = Color(color.r, color.g, color.b, 0.1)
	style.border_color = Color(color.r, color.g, color.b, 0.9)
	state_label.add_theme_stylebox_override("normal", style)
