extends MarginContainer

@onready var title_label: Label = %Title
@onready var terrain_texture: TextureRect = %TerrainTexture
@onready var status_label: Label = %Status


func set_data(cell_label: String, texture: Texture2D, status: String, status_color: Color) -> void:
	_resolve_nodes()
	title_label.text = cell_label
	terrain_texture.texture = texture
	status_label.text = status
	status_label.add_theme_color_override("font_color", status_color)


func _resolve_nodes() -> void:
	if title_label != null:
		return
	title_label = get_node("Content/Title") as Label
	terrain_texture = get_node("Content/TerrainTexture") as TextureRect
	status_label = get_node("Content/Status") as Label
