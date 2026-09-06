extends HBoxContainer

@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %Name


func set_data(display_name: String, texture: Texture2D) -> void:
	name_label.text = display_name
	icon.texture = texture
	icon.visible = texture != null
