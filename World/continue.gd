extends Button


func _on_pressed() -> void:
	DataHandler.save_data.last_mecha_selected = PlayerData.select_mecha_id
	get_tree().change_scene_to_file("res://World/world.tscn")
