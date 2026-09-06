extends PanelContainer

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %Name
@onready var detail_label: Label = %Detail


func set_data(data: Dictionary) -> void:
	_resolve_nodes()
	icon.texture = data.get("icon") as Texture2D
	name_label.text = str(data.get("name", ""))
	name_label.add_theme_color_override("font_color", data.get("accent", Color.WHITE) as Color)
	detail_label.text = str(data.get("detail", ""))


func _resolve_nodes() -> void:
	if icon != null:
		return
	icon = get_node("Margin/Row/Icon") as TextureRect
	name_label = get_node("Margin/Row/Text/Name") as Label
	detail_label = get_node("Margin/Row/Text/Detail") as Label
