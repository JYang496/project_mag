extends HBoxContainer

@onready var level_label: Label = %Level
@onready var state_label: Label = %State


func set_data(level_text: String, state_text: String, ready: bool, state_style: StyleBox) -> void:
	level_label.text = level_text
	state_label.text = state_text
	state_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.65) if ready else Color(1.0, 0.36, 0.3))
	state_label.add_theme_stylebox_override("normal", state_style)
