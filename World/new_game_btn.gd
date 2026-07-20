extends Button

signal erase_button_pressed

const WORLD_SCENE_PATH := "res://World/world.tscn"
const WORLD_ENTRY_PREPARE_GATE_SCRIPT := preload("res://World/world_entry_prepare_gate.gd")
const WORLD_SCENE_LOADER_SCRIPT := preload("res://World/world_scene_loader.gd")

func _on_pressed() -> void:
	if disabled:
		return
	disabled = true
	var original_text := text
	text = "Loading 0%"
	LoadingPerformance.begin_flow("new_game")
	var keep_hp_safety = PlayerData.testing_keep_hp_above_zero
	var selected_mecha_id = PlayerData.select_mecha_id
	DataHandler.new_save()
	PhaseManager.reset_runtime_state()
	GlobalVariables.reset_run_state()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	TaskRewardManager.reset_runtime_state(false)
	RewardDraftRuntime.reset_runtime_state(false)
	CellEffectRuntime.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	PlayerData.select_mecha_id = selected_mecha_id
	PlayerData.set_hp_safety_for_testing(keep_hp_safety)
	DataHandler.save_data.last_mecha_selected = str(PlayerData.select_mecha_id)
	# A run becomes continuable only after the first victory returns to prepare.
	SaveManager.clear_run()
	erase_button_pressed.emit()
	var prepare_result: Dictionary = WORLD_ENTRY_PREPARE_GATE_SCRIPT.prepare_world_entry()
	if not bool(prepare_result.get("ok", false)):
		push_error("World entry prepare failed: %s" % WORLD_ENTRY_PREPARE_GATE_SCRIPT.format_errors(prepare_result))
		text = original_text
		disabled = false
		return
	CellTaskModuleRuntime.grant_starting_cell_loadout(0)
	var loader := WORLD_SCENE_LOADER_SCRIPT.new()
	add_child(loader)
	loader.progress_changed.connect(func(ratio: float): text = "Loading %d%%" % int(round(10.0 + ratio * 70.0)))
	var load_result: Dictionary = await loader.load_world(WORLD_SCENE_PATH)
	loader.queue_free()
	if not bool(load_result.get("ok", false)):
		push_error(str(load_result.get("error", "World load failed")))
		text = original_text
		disabled = false
		return
	LoadingPerformance.show_world_build_overlay()
	LoadingPerformance.mark("world_scene_changed")
	get_tree().change_scene_to_packed(load_result.get("scene") as PackedScene)
