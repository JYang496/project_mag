extends PanelContainer

@onready var label: Label = %Label


func set_data(text: String, color: Color, minimum_width: float) -> void:
	if label == null:
		label = get_node("Margin/Label") as Label
	custom_minimum_size = Vector2(minimum_width, 22.0)
	tooltip_text = text
	label.text = text
	label.custom_minimum_size.x = maxf(0.0, minimum_width - 18.0)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = Color(color.r, color.g, color.b, 0.18)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	add_theme_stylebox_override("panel", style)
