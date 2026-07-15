extends RefCounted

var _owner: Node
var _battle_start_pending := false

func setup(owner_node: Node) -> void:
	_owner = owner_node

func on_start_battle_button_activated() -> void:
	if _battle_start_pending:
		return
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	if TaskRewardManager.is_reward_blocking_interactions():
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
	_battle_start_pending = false
	BattleContractManager.cancel_offer()
	_owner.call("_clear_zone4_hold_move_boost")
	_owner.call("_reset_zone4_hold")
	_owner.call("_reset_start_battle_button")

func continue_start_battle() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	commit_board_edits_and_continue_start_battle()

func commit_board_edits_and_continue_start_battle() -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
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
	request_battle_contract()

func discard_unassigned_task_modules_and_continue_start_battle() -> void:
	CellTaskModuleRuntime.clear_unassigned_modules()
	commit_board_edits_and_continue_start_battle()

func request_battle_contract() -> void:
	if _battle_start_pending or PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	if BattleContractManager.is_boss_battle():
		start_battle(false)
		return
	if BattleContractManager.restored_selection_pending and BattleContractManager.selected_contract != null:
		_battle_start_pending = true
		_on_contract_confirmed()
		return
	var options := BattleContractManager.request_offer()
	if options.size() != 2:
		_owner.call("_reset_start_battle_button")
		return
	var ui = GlobalVariables.ui
	if ui == null or not is_instance_valid(ui) or not ui.has_method("request_battle_contract_selection"):
		BattleContractManager.cancel_offer()
		_owner.call("_reset_start_battle_button")
		return
	_battle_start_pending = true
	ui.call(
		"request_battle_contract_selection",
		options,
		Callable(self, "_on_contract_confirmed"),
		Callable(self, "on_battle_start_cancelled")
	)

func _on_contract_confirmed() -> void:
	if not _battle_start_pending or not BattleContractManager.confirm_selection():
		return
	start_battle(true)

func start_battle(has_contract: bool = false) -> void:
	if PhaseManager.current_state() != PhaseManager.PREPARE:
		return
	if has_contract and BattleContractManager.selected_contract == null:
		return
	if not TaskRewardManager.begin_battle_snapshot():
		_battle_start_pending = false
		BattleContractManager.rollback_confirmed_selection()
		var failed_ui = GlobalVariables.ui
		if failed_ui != null and is_instance_valid(failed_ui) and failed_ui.has_method("close_battle_contract_selection"):
			failed_ui.call("close_battle_contract_selection")
		_owner.call("_reset_start_battle_button")
		return
	if has_contract:
		BattleContractManager.activate_contract()
		var ui = GlobalVariables.ui
		if ui != null and is_instance_valid(ui) and ui.has_method("close_battle_contract_selection"):
			ui.call("close_battle_contract_selection")
	if PlayerData.player != null and is_instance_valid(PlayerData.player):
		if PlayerData.player.has_method("set_restarea_camera_control_enabled"):
			PlayerData.player.call("set_restarea_camera_control_enabled", false)
	PhaseManager.enter_battle()
	BattleContractManager.start_current_battle()
	if PlayerData.player != null and is_instance_valid(PlayerData.player):
		if PlayerData.player.has_method("_update_vision_effect"):
			PlayerData.player.call_deferred("_update_vision_effect")
		if PlayerData.player.has_method("force_recover_battle_camera_zoom"):
			PlayerData.player.call_deferred("force_recover_battle_camera_zoom")
	_owner.call("_clear_zone4_hold_move_boost")
	_battle_start_pending = false

func _get_board() -> BoardCellGenerator:
	return _owner.call("_get_rest_area_board") as BoardCellGenerator if _is_owner_valid() else null

func _is_owner_valid() -> bool:
	return _owner != null and is_instance_valid(_owner)
