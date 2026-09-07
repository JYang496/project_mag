extends Button

signal selected(branch_id: String)

var branch_id := ""

@onready var accent_bar: ColorRect = %Accent
@onready var name_label: Label = %Name
@onready var icon_frame: PanelContainer = %IconFrame
@onready var icon_rect: TextureRect = %Icon
@onready var description_label: Label = %Description
@onready var fuse_label: Label = %Fuse


func _ready() -> void:
	pressed.connect(func() -> void: selected.emit(branch_id))


func set_data(data: Dictionary) -> void:
	if accent_bar == null:
		accent_bar = get_node("Margin/Content/Header/Accent") as ColorRect
		name_label = get_node("Margin/Content/Header/Name") as Label
		icon_frame = get_node("Margin/Content/IconFrame") as PanelContainer
		icon_rect = get_node("Margin/Content/IconFrame/IconMargin/Icon") as TextureRect
		description_label = get_node("Margin/Content/Description") as Label
		fuse_label = get_node("Margin/Content/Fuse") as Label
	branch_id = str(data.get("id", ""))
	var accent := data.get("accent", Color.WHITE) as Color
	name_label.text = str(data.get("name", ""))
	icon_rect.texture = data.get("icon") as Texture2D
	description_label.text = str(data.get("description", ""))
	fuse_label.text = str(data.get("fuse", ""))
	fuse_label.add_theme_color_override("font_color", accent)
	accent_bar.color = accent
	tooltip_text = description_label.text
	_apply_styles(accent)


func _apply_styles(accent: Color) -> void:
	var icon_style := (icon_frame.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	icon_style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := (get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
		if state == "hover" or state == "focus":
			style.border_color = accent
		elif state == "pressed":
			style.border_color = Color(1, 1, 1, 0.92)
		add_theme_stylebox_override(state, style)
