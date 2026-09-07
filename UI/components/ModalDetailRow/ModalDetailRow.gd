extends PanelContainer

@onready var key_label: Label = %Key
@onready var value_label: Label = %Value


func set_data(label_text: String, value_text: String, accent: Color) -> void:
	key_label.text = label_text
	value_label.text = value_text
	var style := (get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.38)
	add_theme_stylebox_override("panel", style)
