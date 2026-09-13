extends Node

func _ready() -> void:
	await get_tree().process_frame
	var world := get_parent()
	var board := world.get_node_or_null("Board") as BoardCellGenerator
	var ui := world.get_node_or_null("UI") as UI
	var ground := world.get_node_or_null("HybridGroundView3D") as HybridGroundView3D
	var rest_area := world.get_node_or_null("RestArea") as RestArea
	if rest_area == null or not _is_world_ready(board, ui, ground):
		push_error("WorldShell completed without satisfying its world-entry contract.")
		await _recover_failed_entry()
		return
	var start_new_game_battle := GlobalVariables.consume_new_game_battle_request()
	if start_new_game_battle:
		LoadingPerformance.update_world_preview_loading_progress(0.94)
		LoadingPerformance.mark("world_ready")
		if not await rest_area.start_initial_battle() or PhaseManager.current_state() != PhaseManager.BATTLE:
			push_error("New-run automatic battle start failed; returning to the menu.")
			await _recover_failed_entry()
			return
		LoadingPerformance.begin_world_build_handoff()
		await _finish_loading_flow()
		return
	var initial_rest_entry_prepared := ui.prepare_initial_rest_area_entry()
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	LoadingPerformance.update_world_preview_loading_progress(0.94)
	LoadingPerformance.mark("world_ready")
	if initial_rest_entry_prepared:
		LoadingPerformance.begin_world_build_handoff()
		await ui.play_initial_rest_area_entry()
	else:
		LoadingPerformance.hide_world_build_overlay()
	await _finish_loading_flow()

func _is_world_ready(board: BoardCellGenerator, ui: UI, ground: HybridGroundView3D) -> bool:
	if board == null or ui == null or ground == null:
		return false
	var player := PlayerData.player as Node
	return player != null and is_instance_valid(player) and player.is_inside_tree() \
		and (get_viewport().get_camera_2d() != null or get_viewport().get_camera_3d() != null) \
		and board.is_ready_for_world_entry() \
		and ui.is_ready_for_world_entry() \
		and ground.is_ready_for_world_entry()


func _finish_loading_flow() -> void:
	await LoadingPerformance.wait_for_world_build_handoff()
	await get_tree().process_frame
	LoadingPerformance.mark("first_stable_frame")
	await LoadingPerformance.finish_flow()


func _recover_failed_entry() -> void:
	LoadingPerformance.cancel_world_preview_handoff()
	GlobalVariables.consume_new_game_battle_request()
	var loader := preload("res://World/world_scene_loader.gd").new()
	add_child(loader)
	var result: Dictionary = await loader.load_world("res://World/Start.tscn")
	loader.queue_free()
	if bool(result.get("ok", false)):
		var error := get_tree().change_scene_to_packed(result.get("scene") as PackedScene)
		if error != OK:
			push_error("Unable to return to the menu: %s" % error_string(error))
	else:
		push_error("Unable to load the menu: %s" % result.get("error", ""))
