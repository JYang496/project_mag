extends Node

func _ready() -> void:
	await get_tree().process_frame
	var world := get_parent()
	var board := world.get_node("Board") as BoardCellGenerator
	var ui := world.get_node("UI") as UI
	var ground := world.get_node("HybridGroundView3D") as HybridGroundView3D
	var rest_area := world.get_node("RestArea") as RestArea
	if not _is_world_ready(board, ui, ground):
		push_error("WorldShell completed without satisfying its world-entry contract.")
		LoadingPerformance.hide_world_build_overlay()
		return
	var start_new_game_battle := GlobalVariables.consume_new_game_battle_request()
	if start_new_game_battle:
		LoadingPerformance.update_world_preview_loading_progress(0.94)
		LoadingPerformance.mark("world_ready")
		LoadingPerformance.begin_world_build_handoff(0.38)
		if not await rest_area.start_initial_battle():
			GlobalVariables.request_new_game_battle()
			push_error("New-run automatic battle start failed; keeping the request pending.")
			LoadingPerformance.hide_world_build_overlay()
			return
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
		LoadingPerformance.begin_world_build_handoff(0.38)
		await ui.play_initial_rest_area_entry()
	else:
		LoadingPerformance.hide_world_build_overlay()
	await _finish_loading_flow()

func _is_world_ready(board: BoardCellGenerator, ui: UI, ground: HybridGroundView3D) -> bool:
	var player := PlayerData.player as Node
	return player != null and is_instance_valid(player) and player.is_inside_tree() \
		and (get_viewport().get_camera_2d() != null or get_viewport().get_camera_3d() != null) \
		and board.is_ready_for_world_entry() \
		and ui.is_ready_for_world_entry() \
		and ground.is_ready_for_world_entry()


func _finish_loading_flow() -> void:
	await get_tree().process_frame
	LoadingPerformance.mark("first_stable_frame")
	LoadingPerformance.finish_flow()
