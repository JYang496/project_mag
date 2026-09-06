extends PanelContainer

@onready var label: Label = %Label


func set_data(text: String, color: Color) -> void:
	if label == null:
		label = get_node("Label") as Label
	label.text = text
	label.add_theme_color_override("font_color", color)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = Color(color.r, color.g, color.b, 0.08)
	style.border_color = Color(color.r, color.g, color.b, 0.42)
	add_theme_stylebox_override("panel", style)
