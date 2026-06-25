extends RefCounted

var _owner: Node

func setup(owner_node: Node) -> void:
	_owner = owner_node

func on_start_battle_button_activated() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	if TaskRewardManager.is_reward_blocking_interactions():
		return
	if _is_route_selection_pending():
		return
	_owner.call("_clear_zone4_hold_move_boost")
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_temporary_module_settlement"):
		ui.call(
			"request_temporary_module_settlement",
			Callable(_owner, "_continue_start_battle"),
			Callable(_owner, "_on_battle_start_cancelled")
		)
		return
	continue_start_battle()

func on_battle_start_cancelled() -> void:
	_owner.call("_clear_zone4_hold_move_boost")
	_owner.call("_reset_zone4_hold")
	_owner.call("_reset_start_battle_button")

func continue_start_battle() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE or _is_route_selection_pending():
		return
	commit_board_edits_and_continue_start_battle()

func commit_board_edits_and_continue_start_battle() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE or _is_route_selection_pending():
		return
	if CellTaskModuleRuntime.has_unassigned_modules():
		var unassigned_count := CellTaskModuleRuntime.get_inventory_size()
		var ui = GlobalVariables.ui
		if ui and is_instance_valid(ui) and ui.has_method("request_task_module_unassigned_confirmation"):
			var opened := bool(ui.call(
				"request_task_module_unassigned_confirmation",
				unassigned_count,
				Callable(_owner, "_discard_unassigned_task_modules_and_continue_start_battle"),
				Callable(_owner, "_on_battle_start_cancelled")
			))
			if opened:
				return
		CellTaskModuleRuntime.clear_unassigned_modules()
	var board := _get_board()
	if CellEffectRuntime.has_pending_edits():
		CellEffectRuntime.commit_pending(board)
	CellTaskModuleRuntime.commit_deployments_for_battle(board, true)
	_set_route_selection_pending(true)
	on_route_confirmed("normal")

func discard_unassigned_task_modules_and_continue_start_battle() -> void:
	CellTaskModuleRuntime.clear_unassigned_modules()
	commit_board_edits_and_continue_start_battle()

func on_route_selection_cancelled() -> void:
	_set_route_selection_pending(false)
	_owner.call("_reset_start_battle_button")

func on_route_confirmed(route_id: String) -> void:
	_set_route_selection_pending(false)
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	var route_def := RunRouteManager.select_route_for_current_level(route_id)
	if route_def == null:
		route_def = RunRouteManager.select_route_for_current_level(RunRouteManager.get_default_route_id())
	if route_def.battle_enabled:
		if not TaskRewardManager.begin_battle_snapshot():
			_owner.call("_reset_start_battle_button")
			return
		if PlayerData.player != null and is_instance_valid(PlayerData.player):
			if PlayerData.player.has_method("set_restarea_camera_control_enabled"):
				PlayerData.player.call("set_restarea_camera_control_enabled", false)
		if GlobalVariables.enemy_spawner:
			GlobalVariables.enemy_spawner.start_timer()
		PhaseManager.enter_battle()
		if PlayerData.player != null and is_instance_valid(PlayerData.player):
			if PlayerData.player.has_method("_update_vision_effect"):
				PlayerData.player.call_deferred("_update_vision_effect")
			if PlayerData.player.has_method("force_recover_battle_camera_zoom"):
				PlayerData.player.call_deferred("force_recover_battle_camera_zoom")
		_owner.call("_clear_zone4_hold_move_boost")
		return
	start_bonus_route_flow(route_def)

func start_bonus_route_flow(route_def: RunRouteDefinition) -> void:
	var level_index: int = max(PhaseManager.current_level, 0)
	var reward_options: Array[RewardInfo] = []
	var reward_manager := _get_reward_manager()
	if reward_manager:
		reward_options = reward_manager.build_reward_selection_options(level_index, route_def)
	if reward_options.is_empty():
		var fallback_reward := RewardInfo.new()
		fallback_reward.total_chip_value = max(route_def.fallback_reward_chip_value, 1)
		reward_options = [fallback_reward]
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("request_reward_selection"):
		if ui.has_method("is_branch_selection_blocking_interactions") and bool(ui.call("is_branch_selection_blocking_interactions")):
			_set_route_selection_pending(false)
			_owner.call("_reset_start_battle_button")
			return
		var opened: bool = bool(ui.request_reward_selection(
			route_def.display_name,
			reward_options,
			Callable(_owner, "_on_bonus_reward_selected"),
			Callable(_owner, "_on_bonus_reward_selection_cancelled")
		))
		if opened:
			return
	on_bonus_reward_selected(reward_options[0])

func on_bonus_reward_selection_cancelled() -> void:
	_owner.call("_reset_start_battle_button")

func on_bonus_reward_selected(reward: RewardInfo) -> void:
	var reward_manager := _get_reward_manager()
	if reward_manager and reward:
		reward_manager.grant_reward_immediately(reward)
	PhaseManager.enter_prepare()

func _is_route_selection_pending() -> bool:
	return bool(_owner.call("_is_route_selection_pending")) if _is_owner_valid() else false

func _set_route_selection_pending(pending: bool) -> void:
	if _is_owner_valid():
		_owner.call("_set_route_selection_pending", pending)

func _get_board() -> BoardCellGenerator:
	return _owner.call("_get_rest_area_board") as BoardCellGenerator if _is_owner_valid() else null

func _get_reward_manager() -> BonusManager:
	return _owner.call("_get_reward_manager") as BonusManager if _is_owner_valid() else null

func _is_owner_valid() -> bool:
	return _owner != null and is_instance_valid(_owner)
