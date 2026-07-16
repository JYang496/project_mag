extends Node

func _ready() -> void:
	for frame in range(120):
		if _is_world_ready():
			LoadingPerformance.mark("world_ready")
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
	var ground_ready: bool = ground != null and ground.get_child_count() > 0
	return player_ready and camera_ready and hud_ready and board_ready and ground_ready
