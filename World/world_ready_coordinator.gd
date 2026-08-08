extends Node

func _ready() -> void:
	for frame in range(120):
		if _is_world_ready():
			var ui := get_parent().get_node_or_null("UI")
			var start_new_game_battle := GlobalVariables.consume_new_game_battle_request()
			var initial_rest_entry_prepared := false
			if not start_new_game_battle and ui != null and ui.has_method("prepare_initial_rest_area_entry"):
				initial_rest_entry_prepared = bool(ui.call("prepare_initial_rest_area_entry"))
			if DisplayServer.get_name() == "headless":
				await get_tree().process_frame
			else:
				await RenderingServer.frame_post_draw
			LoadingPerformance.update_world_preview_loading_progress(0.94)
			LoadingPerformance.mark("world_ready")
			if initial_rest_entry_prepared and ui != null and is_instance_valid(ui) \
					and ui.has_method("play_initial_rest_area_entry"):
				# Match the preview fade to the initial arrival cover release so the
				# lightweight menu projection resolves directly into the live world.
				LoadingPerformance.begin_world_build_handoff(0.38)
				await ui.call("play_initial_rest_area_entry")
			else:
				LoadingPerformance.hide_world_build_overlay()
			if start_new_game_battle:
				var rest_area := get_parent().get_node_or_null("RestArea")
				if rest_area != null and rest_area.has_method("start_initial_battle"):
					rest_area.call("start_initial_battle")
				else:
					push_error("New game could not start its initial battle: RestArea route is unavailable.")
			await get_tree().process_frame
			LoadingPerformance.mark("first_stable_frame")
			LoadingPerformance.finish_flow()
			return
		await get_tree().process_frame
	push_warning("World ready conditions were not satisfied within 120 frames.")
	LoadingPerformance.finish_flow()

func _is_world_ready() -> bool:
	var world: Node = get_parent()
	var board: Node = world.get_node_or_null("Board")
	var ui: Node = world.get_node_or_null("UI")
	var ground: Node = world.get_node_or_null("HybridGroundView3D")
	var player: Node = PlayerData.player as Node
	var player_ready: bool = player != null and is_instance_valid(player) and player.is_inside_tree()
	var camera_ready: bool = get_viewport().get_camera_2d() != null or get_viewport().get_camera_3d() != null
	var hud_ready: bool = ui != null and ui.get("battle_hud") != null
	var board_ready: bool = board != null and board.get_child_count() > 0
	var ground_ready: bool = ground != null and bool(ground.get("_ground_renderers_initialized"))
	return player_ready and camera_ready and hud_ready and board_ready and ground_ready
