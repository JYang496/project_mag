extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 0
	CellTaskModuleRuntime.reset_runtime_state()
	CellTaskModuleRuntime.load_definitions()
	CellEffectRuntime.reset_runtime_state()
	CellEffectRuntime.load_definitions()

	if CellTaskModuleRuntime.get_definition("task_kill_common") == null:
		_fail("missing task_kill_common definition")
		return
	if CellTaskModuleRuntime.get_definition("task_hold_common") == null:
		_fail("missing task_hold_common definition")
		return
	if not await _run_hunt_elite_spawn_contract_test():
		return
	if not await _run_status_contract_tests():
		return

	CellTaskModuleRuntime.grant_starting_cell_loadout(0)
	if _get_total_cell_effect_count() != 2:
		_fail("starting loadout should grant two cell effects")
		return
	if not CellEffectRuntime.get_pending_snapshot().has("5"):
		_fail("starting loadout should preinstall one cell effect on cell 5")
		return
	if CellTaskModuleRuntime.get_deployment_snapshot().has("5"):
		_fail("starting loadout should leave task modules in inventory for panel testing")
		return
	var starting_inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	if starting_inventory.size() != 3:
		_fail("starting loadout should leave three installable task modules in inventory")
		return
	if str(starting_inventory[0]) != "task_kill_common" or str(starting_inventory[1]) != "task_hold_common" or str(starting_inventory[2]) != "task_clear_rare":
		_fail("starting loadout should provide deterministic task modules for UI testing")
		return
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()

	var result: Dictionary = CellTaskModuleRuntime.grant_module("task_kill_common")
	if not bool(result.get("ok", false)):
		_fail("failed to grant replace source task module: %s" % str(result))
		return
	result = CellTaskModuleRuntime.grant_module("task_hold_common")
	if not bool(result.get("ok", false)):
		_fail("failed to grant replacement task module: %s" % str(result))
		return
	result = CellTaskModuleRuntime.deploy_inventory_module(0, 5, null)
	if not bool(result.get("ok", false)):
		_fail("failed to deploy task module before replacement: %s" % str(result))
		return
	result = CellTaskModuleRuntime.replace_deployment_with_inventory_module(0, 5, null)
	if not bool(result.get("ok", false)):
		_fail("failed to replace deployed task module: %s" % str(result))
		return
	var replacement_snapshot := CellTaskModuleRuntime.get_deployment_snapshot()
	if str(replacement_snapshot.get("5", "")) != "task_hold_common":
		_fail("deployment replacement did not overwrite the cell task")
		return
	if CellTaskModuleRuntime.get_inventory_size() != 0:
		_fail("deployment replacement should consume the replacement module")
		return
	result = CellTaskModuleRuntime.cancel_deployment(5)
	if bool(result.get("ok", false)):
		_fail("deployed task modules should not be removable")
		return
	replacement_snapshot = CellTaskModuleRuntime.get_deployment_snapshot()
	if str(replacement_snapshot.get("5", "")) != "task_hold_common":
		_fail("failed deployment removal should keep the cell task installed")
		return
	CellTaskModuleRuntime.reset_runtime_state()

	result = CellTaskModuleRuntime.grant_module("task_kill_common")
	if not bool(result.get("ok", false)):
		_fail("failed to grant first task module: %s" % str(result))
		return
	result = CellTaskModuleRuntime.grant_module("task_hold_common")
	if not bool(result.get("ok", false)):
		_fail("failed to grant second task module: %s" % str(result))
		return
	result = CellTaskModuleRuntime.grant_module("task_clear_rare")
	if not bool(result.get("ok", false)):
		_fail("failed to grant third task module: %s" % str(result))
		return
	result = CellTaskModuleRuntime.grant_module("task_dodge_epic")
	if not bool(result.get("ok", false)):
		_fail("failed to grant fourth task module without inventory limit: %s" % str(result))
		return
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	if inventory.size() != 4 or str(inventory[3]) != "task_dodge_epic":
		_fail("task module inventory should accept more than three modules")
		return

	var board_script := load("res://World/board_cell_generator.gd") as Script
	var board := board_script.new() as BoardCellGenerator
	board.name = "Board"
	board.cell_scene = load("res://Board/Cells/cell.tscn") as PackedScene
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame

	result = CellTaskModuleRuntime.deploy_inventory_module(0, 5, board)
	if not bool(result.get("ok", false)):
		_fail("failed to deploy task module to active cell 5: %s" % str(result))
		return
	if CellTaskModuleRuntime.get_inventory_size() != 3:
		_fail("deployment should remove one task module from inventory")
		return
	if not CellTaskModuleRuntime.has_unassigned_modules():
		_fail("undeployed task modules should remain before battle")
		return
	result = CellTaskModuleRuntime.commit_deployments_for_battle(board, true)
	if not bool(result.get("ok", false)):
		_fail("failed to commit deployments for battle: %s" % str(result))
		return
	if CellTaskModuleRuntime.has_unassigned_modules():
		_fail("battle commit should discard unassigned task modules")
		return
	var cell := board.get_cell_by_logical_id(5)
	if cell == null:
		_fail("missing board cell 5")
		return
	if int(cell.task_type) != Cell.TaskType.OFFENSE or not bool(cell.objective_enabled):
		_fail("runtime task module did not apply offense objective to cell 5")
		return
	if not CellTaskModuleRuntime.has_active_task_for_cell(5):
		_fail("runtime active task missing for cell 5")
		return

	PhaseManager.enter_battle()
	TaskRewardManager.notify_objective_completed("5")
	if CellTaskModuleRuntime.get_completed_cells_snapshot().size() != 1:
		_fail("completed runtime task was not recorded")
		return
	var rewards: Array[RewardInfo] = TaskRewardManager.get_pending_reward_options()
	if rewards.size() != 3:
		_fail("task reward should still build three options, got %d" % rewards.size())
		return
	var cell_effect_count := 0
	var task_module_count := 0
	for reward in rewards:
		if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
			cell_effect_count += 1
		if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
			task_module_count += 1
			if reward.task_module_id.strip_edges() == "":
				_fail("task module reward option missing module id")
				return
	if cell_effect_count < 2 or task_module_count > 1:
		_fail("reward mix should be at least two cell effects and at most one task module")
		return

	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.phase_changed.emit(PhaseManager.PREPARE)
	if not CellTaskModuleRuntime.get_active_tasks_snapshot().is_empty():
		_fail("active task modules should clear on prepare")
		return
	board.apply_task_module_runtime_state()
	if int(cell.task_type) != Cell.TaskType.NONE or bool(cell.objective_enabled):
		_fail("cell task state should restore after active task cleanup")
		return

	var offer_id := CellTaskModuleRuntime.prepare_special_shop_offer(true)
	if offer_id == "":
		_fail("forced special shop offer did not generate")
		return
	var offer_definition := CellTaskModuleRuntime.get_definition(offer_id)
	if offer_definition == null:
		_fail("special shop offer definition missing")
		return
	var cost := CellTaskModuleRuntime.get_special_shop_cost_count(offer_id)
	if cost <= 0:
		_fail("special shop offer cost should be positive")
		return
	var granted := 0
	for effect_definition in CellEffectRuntime.get_all_definitions():
		if effect_definition == null:
			continue
		if effect_definition.rarity != offer_definition.get_rarity():
			continue
		if CellEffectRuntime.grant_effect(effect_definition.effect_id):
			granted += 1
		if granted >= cost:
			break
	if granted < cost:
		_fail("test could not grant enough %s cell effects for special shop cost" % offer_definition.get_rarity())
		return
	var purchase_result := CellTaskModuleRuntime.purchase_special_shop_offer()
	if not bool(purchase_result.get("ok", false)):
		_fail("special shop purchase failed: %s" % str(purchase_result))
		return
	if CellTaskModuleRuntime.get_inventory_size() != 1:
		_fail("special shop purchase should grant one task module")
		return
	if CellTaskModuleRuntime.get_special_shop_offer_module_id() != "":
		_fail("special shop offer should clear after purchase")
		return

	CellTaskModuleRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	_cleanup_test_player("StatusContractPlayer")
	print("CellTaskModuleRuntimeTest: PASS")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("CellTaskModuleRuntimeTest: " + message)
	CellTaskModuleRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	_cleanup_test_player("StatusContractPlayer")
	get_tree().quit(1)

func _get_total_cell_effect_count() -> int:
	var total := 0
	for value in CellEffectRuntime.get_inventory_snapshot().values():
		total += int(value)
	return total

func _run_hunt_elite_spawn_contract_test() -> bool:
	_reset_status_contract_runtime()
	SpawnData.ensure_loaded()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 0
	var test_player := Node2D.new()
	test_player.name = "HuntEliteSpawnContractPlayer"
	test_player.global_position = Vector2(256.0, 256.0)
	get_tree().root.add_child(test_player)
	PlayerData.player = test_player
	var board := await _create_test_board_for_level(0, "HuntEliteSpawnContractBoard")
	if board == null:
		test_player.queue_free()
		PlayerData.player = null
		return false
	var result := CellTaskModuleRuntime.grant_module("task_hunt_rare")
	if not bool(result.get("ok", false)):
		_fail("failed to grant hunt elite task module: %s" % str(result))
		test_player.queue_free()
		PlayerData.player = null
		return false
	result = CellTaskModuleRuntime.deploy_inventory_module(0, 5, board)
	if not bool(result.get("ok", false)):
		_fail("failed to deploy hunt elite task module: %s" % str(result))
		test_player.queue_free()
		PlayerData.player = null
		return false
	result = CellTaskModuleRuntime.commit_deployments_for_battle(board, true)
	if not bool(result.get("ok", false)):
		_fail("failed to commit hunt elite task: %s" % str(result))
		test_player.queue_free()
		PlayerData.player = null
		return false
	PhaseManager.enter_battle()
	board.apply_task_module_runtime_state()
	await get_tree().process_frame
	await get_tree().process_frame
	var cell := board.get_cell_by_logical_id(5)
	var objective := _get_objective_module_for_cell(cell)
	if objective == null or not (objective is HuntEliteObjectiveModule):
		_fail("hunt elite task did not install HuntEliteObjectiveModule on cell 5")
		test_player.queue_free()
		PlayerData.player = null
		return false
	var quest_elites: Array = objective.get("_quest_elites")
	if quest_elites.is_empty():
		_fail("hunt elite task should spawn a quest elite even when level 1 has no elite spawn entry")
		test_player.queue_free()
		PlayerData.player = null
		return false
	var quest_elite := quest_elites[0] as BaseEnemy
	if quest_elite == null or not quest_elite.has_spawn_tag(BaseEnemy.SPAWN_TAG_ELITE):
		_fail("hunt elite task spawned a non-elite quest target")
		test_player.queue_free()
		PlayerData.player = null
		return false
	board.queue_free()
	for enemy in quest_elites:
		if enemy != null and is_instance_valid(enemy):
			(enemy as Node).queue_free()
	await get_tree().process_frame
	test_player.queue_free()
	PlayerData.player = null
	_reset_status_contract_runtime()
	return true

func _run_status_contract_tests() -> bool:
	if not CellTaskModuleRuntime.has_method("get_active_task_statuses"):
		_fail("CellTaskModuleRuntime is missing get_active_task_statuses")
		return false
	var test_player := Node2D.new()
	test_player.name = "StatusContractPlayer"
	test_player.global_position = Vector2(256.0, 256.0)
	get_tree().root.add_child(test_player)
	PlayerData.player = test_player
	var module_ids := [
		"task_kill_common",
		"task_hold_common",
		"task_clear_rare",
		"task_hunt_rare",
		"task_dodge_epic",
	]
	var expected_types := {
		"task_kill_common": "kill",
		"task_hold_common": "hold",
		"task_clear_rare": "clear",
		"task_hunt_rare": "hunt",
		"task_dodge_epic": "dodge",
	}
	var cell_ids := [5, 6, 4, 8, 2]
	for start_index in range(0, module_ids.size(), CellTaskModuleRuntime.ACTIVE_LIMIT):
		var board := await _create_test_board()
		if board == null:
			return false
		var batch_size: int = mini(CellTaskModuleRuntime.ACTIVE_LIMIT, module_ids.size() - start_index)
		for offset in range(batch_size):
			var module_id := str(module_ids[start_index + offset])
			var result := CellTaskModuleRuntime.grant_module(module_id)
			if not bool(result.get("ok", false)):
				_fail("failed to grant status contract task module %s: %s" % [module_id, str(result)])
				return false
			result = CellTaskModuleRuntime.deploy_inventory_module(0, int(cell_ids[start_index + offset]), board)
			if not bool(result.get("ok", false)):
				_fail("failed to deploy status contract task module %s: %s" % [module_id, str(result)])
				return false
		var commit_result := CellTaskModuleRuntime.commit_deployments_for_battle(board, true)
		if not bool(commit_result.get("ok", false)):
			_fail("failed to commit status contract tasks: %s" % str(commit_result))
			return false
		PhaseManager.enter_battle()
		board.apply_task_module_runtime_state()
		await get_tree().process_frame
		await get_tree().process_frame
		var statuses: Array = CellTaskModuleRuntime.get_active_task_statuses(board)
		if statuses.size() != batch_size:
			_fail("expected %d status dictionaries, got %d" % [batch_size, statuses.size()])
			return false
		for status in statuses:
			if not (status is Dictionary):
				_fail("active task status entry is not a Dictionary")
				return false
			var module_id := str((status as Dictionary).get("module_id", ""))
			if not _assert_status_contract(status as Dictionary, str(expected_types.get(module_id, "")), false):
				return false
		var completed_cell_id := int(cell_ids[start_index])
		CellTaskModuleRuntime.record_objective_completed(str(completed_cell_id))
		statuses = CellTaskModuleRuntime.get_active_task_statuses(board)
		var completed_status := _find_status_for_cell(statuses, completed_cell_id)
		if completed_status.is_empty():
			_fail("missing completed task status for cell %d" % completed_cell_id)
			return false
		if not _assert_status_contract(completed_status, str(expected_types.get(str(completed_status.get("module_id", "")), "")), true):
			return false
		board.queue_free()
		await get_tree().process_frame
		_reset_status_contract_runtime()
	return true

func _cleanup_test_player(player_name: String) -> void:
	var player_node := PlayerData.player as Node
	if player_node != null and is_instance_valid(player_node) and player_node.name == player_name:
		player_node.queue_free()
		PlayerData.player = null

func _create_test_board() -> BoardCellGenerator:
	return await _create_test_board_for_level(9, "StatusContractBoard")

func _create_test_board_for_level(level_index: int, board_name: String) -> BoardCellGenerator:
	_reset_status_contract_runtime()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = level_index
	var board_script := load("res://World/board_cell_generator.gd") as Script
	var board := board_script.new() as BoardCellGenerator
	board.name = board_name
	board.cell_scene = load("res://Board/Cells/cell.tscn") as PackedScene
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	if board.get_cell_by_logical_id(5) == null:
		_fail("status contract board did not create cell 5")
		return null
	return board

func _get_objective_module_for_cell(cell: Cell) -> CellObjectiveModule:
	if cell == null:
		return null
	var module_root := cell.get_node_or_null("Modules")
	if module_root == null:
		return null
	for child in module_root.get_children():
		if child is CellObjectiveModule:
			return child as CellObjectiveModule
	return null

func _assert_status_contract(status: Dictionary, expected_type: String, expect_complete: bool) -> bool:
	for key in ["type", "label", "progress", "value_text", "state"]:
		if not status.has(key):
			_fail("status missing required key '%s': %s" % [key, str(status)])
			return false
	var type_text := str(status.get("type", "")).strip_edges()
	if type_text == "":
		_fail("status type must be non-empty: %s" % str(status))
		return false
	if expected_type.strip_edges() != "" and type_text != expected_type:
		_fail("expected status type %s, got %s" % [expected_type, type_text])
		return false
	if str(status.get("label", "")).strip_edges() == "":
		_fail("status label must be non-empty: %s" % str(status))
		return false
	var progress := float(status.get("progress", -1.0))
	if progress < 0.0 or progress > 1.0:
		_fail("status progress out of range: %s" % str(status))
		return false
	var value_text := str(status.get("value_text", "")).strip_edges()
	var lower_value := value_text.to_lower()
	if value_text == "" or lower_value.contains("quest:") or lower_value.contains("remaining"):
		_fail("status value_text must be short HUD text, got '%s'" % value_text)
		return false
	var state := str(status.get("state", "")).strip_edges()
	if state == "":
		_fail("status state must be non-empty: %s" % str(status))
		return false
	if expect_complete and state != "complete":
		_fail("completed task status should be complete, got %s" % state)
		return false
	return true

func _find_status_for_cell(statuses: Array, cell_id: int) -> Dictionary:
	for status in statuses:
		if status is Dictionary and int((status as Dictionary).get("cell_id", 0)) == cell_id:
			return (status as Dictionary).duplicate(true)
	return {}

func _reset_status_contract_runtime() -> void:
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 0
	CellTaskModuleRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
