extends PanelContainer

@onready var icon: TextureRect = %WeaponIcon
@onready var name_label: Label = %WeaponName
@onready var status_label: Label = %WeaponFitStatus


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	icon.texture = data.get("icon") as Texture2D
	name_label.text = str(data.get("name", "Weapon"))
	name_label.tooltip_text = name_label.text
	status_label.text = str(data.get("status", ""))
	status_label.tooltip_text = str(data.get("status_tooltip", status_label.text))
	var state_color := data.get("state_color", Color.WHITE) as Color
	status_label.add_theme_color_override("font_color", state_color)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.08)
	style.border_color = Color(state_color.r, state_color.g, state_color.b, 0.58)
	add_theme_stylebox_override("panel", style)


func _resolve_nodes() -> void:
	if icon != null:
		return
	icon = get_node("Row/WeaponIcon") as TextureRect
	name_label = get_node("Row/Text/WeaponName") as Label
	status_label = get_node("Row/Text/WeaponFitStatus") as Label
