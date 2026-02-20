extends Button


func _on_pressed() -> void:
	var keep_hp_safety = PlayerData.testing_keep_hp_above_zero
	var selected_mecha_id = PlayerData.select_mecha_id
	PhaseManager.reset_runtime_state()
	GlobalVariables.reset_runtime_state()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PlayerData.select_mecha_id = selected_mecha_id
	PlayerData.set_hp_safety_for_testing(keep_hp_safety)
	DataHandler.save_data.last_mecha_selected = PlayerData.select_mecha_id
	get_tree().change_scene_to_file("res://World/world.tscn")
