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

	var result: Dictionary = CellTaskModuleRuntime.grant_module("task_kill_common")
	if not bool(result.get("ok", false)):
		_fail("failed to grant first task module: %s" % str(result))
		return
	result = CellTaskModuleRuntime.grant_module("task_hold_common")
	if not bool(result.get("ok", false)):
		_fail("failed to grant second task module: %s" % str(result))
		return
	result = CellTaskModuleRuntime.grant_module("task_clear_rare")
	if bool(result.get("ok", false)) or not bool(result.get("needs_replace", false)):
		_fail("third task module should require replacement")
		return
	result = CellTaskModuleRuntime.replace_inventory_module(1, "task_clear_rare")
	if not bool(result.get("ok", false)):
		_fail("failed to replace task module: %s" % str(result))
		return
	var inventory := CellTaskModuleRuntime.get_inventory_snapshot()
	if inventory.size() != 2 or str(inventory[1]) != "task_clear_rare":
		_fail("inventory replacement did not preserve the expected modules")
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
	if CellTaskModuleRuntime.get_inventory_size() != 1:
		_fail("deployment should remove one task module from inventory")
		return
	if not CellTaskModuleRuntime.has_unassigned_modules():
		_fail("one undeployed task module should remain before battle")
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
	print("CellTaskModuleRuntimeTest: PASS")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("CellTaskModuleRuntimeTest: " + message)
	CellTaskModuleRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	get_tree().quit(1)
