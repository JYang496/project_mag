extends PanelContainer

@onready var key_label: Label = %Key
@onready var value_label: Label = %Value


func set_data(label_text: String, value_text: String, accent: Color) -> void:
	key_label.text = label_text
	value_label.text = value_text
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	add_theme_stylebox_override("panel", style)
