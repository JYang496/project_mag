extends TextureRect


func set_data(prompt_texture: Texture2D, display_size: Vector2, accessible_name: String) -> void:
	texture = prompt_texture
	custom_minimum_size = display_size
	tooltip_text = accessible_name
