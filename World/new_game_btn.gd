extends Button

signal erase_button_pressed

const WORLD_SCENE_PATH := "res://World/world.tscn"
const WORLD_ENTRY_PREPARE_GATE_SCRIPT := preload("res://World/world_entry_prepare_gate.gd")
const WORLD_SCENE_LOADER_SCRIPT := preload("res://World/world_scene_loader.gd")

var _scene_change_committed := false
var _loading_started := false

func _exit_tree() -> void:
	if _loading_started and not _scene_change_committed:
		LoadingPerformance.cancel_world_preview_handoff()

func _on_pressed() -> void:
	if disabled or LoadingPerformance.is_world_input_locked():
		return
	disabled = true
	_loading_started = true
	var original_text := text
	text = LocalizationManager.tr_key("ui.loading")
	LoadingPerformance.begin_flow("new_game")
	LoadingPerformance.begin_world_preview_handoff()
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
	LoadingPerformance.update_world_preview_loading_progress(0.18)
	var prepare_result: Dictionary = WORLD_ENTRY_PREPARE_GATE_SCRIPT.prepare_initial_battle_entry()
	if not bool(prepare_result.get("ok", false)):
		push_error("World entry prepare failed: %s" % WORLD_ENTRY_PREPARE_GATE_SCRIPT.format_errors(prepare_result))
		LoadingPerformance.cancel_world_preview_handoff()
		_loading_started = false
		text = original_text
		disabled = false
		return
	LoadingPerformance.update_world_preview_loading_progress(0.24)
	var loader := WORLD_SCENE_LOADER_SCRIPT.new()
	add_child(loader)
	loader.progress_changed.connect(func(ratio: float):
		LoadingPerformance.update_world_preview_loading_progress(0.24 + clampf(ratio, 0.0, 1.0) * 0.48)
	)
	var load_result: Dictionary = await loader.load_world(WORLD_SCENE_PATH)
	loader.queue_free()
	if not bool(load_result.get("ok", false)):
		push_error(str(load_result.get("error", "World load failed")))
		LoadingPerformance.cancel_world_preview_handoff()
		_loading_started = false
		text = original_text
		disabled = false
		return
	LoadingPerformance.update_world_preview_loading_progress(0.78)
	await LoadingPerformance.wait_for_world_preview_safe_scene_change()
	LoadingPerformance.update_world_preview_loading_progress(0.84)
	LoadingPerformance.show_world_build_overlay()
	GlobalVariables.request_new_game_battle()
	LoadingPerformance.mark("world_scene_changed")
	_scene_change_committed = true
	var change_error := get_tree().change_scene_to_packed(load_result.get("scene") as PackedScene)
	if change_error != OK:
		_scene_change_committed = false
		GlobalVariables.consume_new_game_battle_request()
		LoadingPerformance.cancel_world_preview_handoff()
		_loading_started = false
		text = original_text
		disabled = false
		push_error("World scene change failed: %s" % error_string(change_error))
