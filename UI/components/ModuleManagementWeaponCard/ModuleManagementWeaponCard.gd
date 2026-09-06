extends PanelContainer

@onready var icon_frame: PanelContainer = %WeaponIconFrame
@onready var icon: TextureRect = %WeaponIcon
@onready var name_label: Label = %WeaponName
@onready var level_label: Label = %WeaponLevel
@onready var socket_row: HBoxContainer = %ModuleSlots


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	icon.texture = data.get("icon") as Texture2D
	name_label.text = str(data.get("name", ""))
	level_label.text = str(data.get("level", ""))
	var accent := data.get("accent", Color.WHITE) as Color
	name_label.add_theme_color_override("font_color", accent)
	var icon_style := icon_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	icon_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	icon_frame.add_theme_stylebox_override("panel", icon_style)


func get_socket_container() -> HBoxContainer:
	_resolve_nodes()
	return socket_row


func set_highlight(accent: Color, state: StringName = &"") -> void:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = accent
	style.set_border_width_all(1 if state == &"" else 3)
	if state == &"compatible":
		style.bg_color = Color(0.1, 0.12, 0.13, 0.98)
	elif state == &"blocked":
		style.bg_color = Color(0.16, 0.065, 0.06, 0.98)
	add_theme_stylebox_override("panel", style)
	set_meta("drag_highlight", String(state))


func _resolve_nodes() -> void:
	if icon != null:
		return
	icon_frame = get_node("Margin/Row/WeaponIconFrame") as PanelContainer
	icon = get_node("Margin/Row/WeaponIconFrame/WeaponIcon") as TextureRect
	name_label = get_node("Margin/Row/Content/WeaponName") as Label
	level_label = get_node("Margin/Row/Content/WeaponLevel") as Label
	socket_row = get_node("Margin/Row/Content/ModuleSlots") as HBoxContainer
