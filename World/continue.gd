extends Button

const WORLD_SCENE_PATH := "res://World/world.tscn"

func _on_pressed() -> void:
	if disabled:
		return
	disabled = true
	var original_text := text
	text = "Loading 0%"
	var keep_hp_safety = PlayerData.testing_keep_hp_above_zero
	var selected_mecha_id = PlayerData.select_mecha_id
	PhaseManager.reset_runtime_state()
	RunRouteManager.reset_runtime_state()
	GlobalVariables.reset_runtime_state()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PlayerData.select_mecha_id = selected_mecha_id
	PlayerData.set_hp_safety_for_testing(keep_hp_safety)
	DataHandler.save_data.last_mecha_selected = PlayerData.select_mecha_id
	DataHandler.prepare_world_data()
	SpawnData.ensure_loaded()
	var request_error := ResourceLoader.load_threaded_request(WORLD_SCENE_PATH, "PackedScene", true)
	if request_error != OK:
		push_error("Failed to request threaded world load: %s" % request_error)
		text = original_text
		disabled = false
		return
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(WORLD_SCENE_PATH, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Threaded world load failed with status: %s" % status)
			text = original_text
			disabled = false
			return
		var ratio := float(progress[0]) if not progress.is_empty() else 0.0
		text = "Loading %d%%" % int(round(ratio * 100.0))
		await get_tree().process_frame
	var world_scene := ResourceLoader.load_threaded_get(WORLD_SCENE_PATH) as PackedScene
	if world_scene == null:
		push_error("Threaded world load returned an invalid PackedScene.")
		text = original_text
		disabled = false
		return
	get_tree().change_scene_to_packed(world_scene)
