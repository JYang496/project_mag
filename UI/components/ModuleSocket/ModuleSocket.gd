extends PanelContainer

@onready var icon: TextureRect = %Icon
@onready var index_label: Label = %Index


func set_data(index: int, texture: Texture2D, tooltip: String, occupied: bool, occupied_color: Color, empty_color: Color) -> void:
	icon.texture = texture
	index_label.text = "%02d" % (index + 1)
	tooltip_text = tooltip
	mouse_default_cursor_shape = Control.CURSOR_HELP if occupied else Control.CURSOR_ARROW
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.12, 0.14, 1.0) if occupied else Color(0.025, 0.03, 0.035, 1.0)
	style.border_color = occupied_color if occupied else empty_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
