extends PanelContainer

@onready var texture_view: TextureRect = %Texture
@onready var empty_label: Label = %EmptyLabel


func set_data(texture: Texture2D, accent: Color, display_size: Vector2, empty: bool = false) -> void:
	_resolve_nodes()
	custom_minimum_size = display_size
	texture_view.texture = texture
	texture_view.visible = not empty
	empty_label.visible = empty
	empty_label.add_theme_color_override("font_color", accent)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = accent
	add_theme_stylebox_override("panel", style)


func _resolve_nodes() -> void:
	if texture_view != null:
		return
	texture_view = get_node("Texture") as TextureRect
	empty_label = get_node("EmptyLabel") as Label
