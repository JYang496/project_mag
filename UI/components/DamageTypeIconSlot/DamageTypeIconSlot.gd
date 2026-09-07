extends PanelContainer

var icon: TextureRect


func set_data(data: Dictionary) -> void:
	if icon == null:
		icon = get_child(0) as TextureRect
	var type_name := str(data.get("type", "physical"))
	name = "DamageTypeSlot%s" % type_name.capitalize()
	custom_minimum_size = Vector2.ONE * float(data.get("size", 20.0))
	icon.name = "DamageType%s" % type_name.capitalize()
	icon.texture = data.get("texture") as Texture2D
	icon.custom_minimum_size = Vector2.ONE * maxf(1.0, float(data.get("size", 20.0)) - 2.0)
	var color := data.get("color", Color.WHITE) as Color
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color(color.r, color.g, color.b, 0.82)
	add_theme_stylebox_override("panel", style)
