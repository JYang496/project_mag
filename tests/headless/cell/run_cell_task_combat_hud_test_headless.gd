extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")

var _board: BoardCellGenerator
var _ui: UI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_reset_runtime()
	if not CellTaskModuleRuntime.has_method("get_active_task_statuses"):
		_fail("CellTaskModuleRuntime is missing get_active_task_statuses")
		return

	_board = await _create_board()
	if _board == null:
		return
	_ui = UI_SCENE.instantiate() as UI
	if _ui == null:
		_fail("failed to instantiate UI scene")
		return
	add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var result := CellTaskModuleRuntime.grant_module("task_kill_common")
	if not bool(result.get("ok", false)):
		_fail("failed to grant first HUD task: %s" % str(result))
		return
	result = CellTaskModuleRuntime.grant_module("task_hold_common")
	if not bool(result.get("ok", false)):
		_fail("failed to grant second HUD task: %s" % str(result))
		return
	result = CellTaskModuleRuntime.deploy_inventory_module(0, 5, _board)
	if not bool(result.get("ok", false)):
		_fail("failed to deploy first HUD task: %s" % str(result))
		return
	result = CellTaskModuleRuntime.deploy_inventory_module(0, 6, _board)
	if not bool(result.get("ok", false)):
		_fail("failed to deploy second HUD task: %s" % str(result))
		return
	result = CellTaskModuleRuntime.commit_deployments_for_battle(_board, true)
	if not bool(result.get("ok", false)):
		_fail("failed to commit HUD tasks: %s" % str(result))
		return

	PhaseManager.enter_battle()
	_board.apply_task_module_runtime_state()
	_ui.call("_refresh_task_objective_hud", true)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel := _get_task_panel()
	if panel == null or not panel.visible:
		_fail("task objective HUD should be visible during battle")
		return
	var visible_cards := _get_visible_task_cards()
	if visible_cards.size() != 2:
		_fail("task objective HUD should show two cards, got %d" % visible_cards.size())
		return
	var first_card := visible_cards[0] as Control
	var first_size := first_card.size
	var first_minimum := first_card.custom_minimum_size
	if panel.custom_minimum_size.x > 248.0 or panel.custom_minimum_size.y > 144.0:
		_fail("task objective HUD panel should stay compact, got minimum %s" % str(panel.custom_minimum_size))
		return
	if first_minimum.x > 232.0 or first_minimum.y > 64.0:
		_fail("task card should stay compact, got minimum %s" % str(first_minimum))
		return
	if not _assert_visible_card_instruction(visible_cards[0], "Kill enemies"):
		return
	if not _assert_visible_card_instruction(visible_cards[1], "Stay inside the marked cell"):
		return

	var objective := _get_objective_module_for_cell(5)
	if objective == null or not objective.has_method("set_task_parameters"):
		_fail("missing objective module on HUD task cell 5")
		return
	objective.call("set_task_parameters", {"required_kill_count": 1000000})
	_ui.call("_refresh_task_objective_hud", true)
	await get_tree().process_frame
	if first_card.size != first_size:
		_fail("task card size changed after value_text update: %s -> %s" % [str(first_size), str(first_card.size)])
		return
	if first_card.custom_minimum_size != first_minimum:
		_fail("task card minimum size changed after value_text update")
		return
	if not await _assert_completed_feedback_contract():
		return
	if not await _assert_world_marker_anchor_contract():
		return

	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.phase_changed.emit(PhaseManager.PREPARE)
	_ui.call("_refresh_task_objective_hud", true)
	await get_tree().process_frame
	if panel.visible:
		_fail("task objective HUD should hide outside battle")
		return

	if not await _assert_legacy_long_text_contract():
		return
	if not await _assert_short_quest_hint_still_works():
		return
	if not await _assert_all_task_instruction_statuses():
		return

	_reset_runtime()
	_cleanup_scene_nodes()
	await get_tree().process_frame
	print("CellTaskCombatHudTest: PASS")
	get_tree().quit(0)

func _create_board() -> BoardCellGenerator:
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 9
	var board_script := load("res://World/board_cell_generator.gd") as Script
	var board := board_script.new() as BoardCellGenerator
	board.name = "Board"
	board.cell_scene = load("res://Board/Cells/cell.tscn") as PackedScene
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	if board.get_cell_by_logical_id(5) == null or board.get_cell_by_logical_id(6) == null:
		_fail("HUD test board did not create required cells")
		return null
	return board

func _get_task_panel() -> PanelContainer:
	if _ui == null or _ui.task_objective_hud_presenter == null:
		return null
	return _ui.task_objective_hud_presenter.panel as PanelContainer

func _get_visible_task_cards() -> Array[Control]:
	var output: Array[Control] = []
	if _ui == null or _ui.task_objective_hud_presenter == null:
		return output
	for row in _ui.task_objective_hud_presenter.rows:
		if not (row is Dictionary):
			continue
		var root := (row as Dictionary).get("root", null) as Control
		if root != null and root.visible:
			output.append(root)
	return output

func _assert_visible_card_instruction(card: Control, expected_text: String) -> bool:
	var instruction := card.get_node_or_null("CardMargin/Body/Instruction") as Label
	if instruction == null:
		_fail("task card is missing Instruction label")
		return false
	if not instruction.visible or instruction.text != expected_text:
		_fail("task card instruction mismatch: expected '%s', got '%s'" % [expected_text, instruction.text])
		return false
	return true

func _get_objective_module_for_cell(cell_id: int) -> CellObjectiveModule:
	if _board == null:
		return null
	var cell := _board.get_cell_by_logical_id(cell_id)
	if cell == null:
		return null
	var module_root := cell.get_node_or_null("Modules")
	if module_root == null:
		return null
	for child in module_root.get_children():
		if child is CellObjectiveModule:
			return child as CellObjectiveModule
	return null

func _assert_world_marker_anchor_contract() -> bool:
	var cell := _board.get_cell_by_logical_id(6)
	if cell == null:
		_fail("missing task marker contract cell")
		return false
	await get_tree().process_frame
	var marker := cell.get_node_or_null("TaskMarkerVisual")
	if marker == null:
		_fail("task marker visual should exist for deployed objective cell")
		return false
	if not marker.has_method("_resolve_marker_center"):
		_fail("task marker visual is missing marker anchor resolver")
		return false
	var marker_center: Vector2 = marker.call("_resolve_marker_center", Vector2(58.0, 58.0))
	var cell_rect: Rect2 = marker.cell_rect
	if marker_center.y >= cell_rect.position.y + cell_rect.size.y * 0.5:
		_fail("task marker should anchor in the upper half of the cell, got %s in %s" % [str(marker_center), str(cell_rect)])
		return false
	if not marker.has_method("_get_edge_hint_position"):
		_fail("task marker visual is missing edge hint resolver")
		return false
	var edge_hint: Variant = marker.call("_get_edge_hint_position", cell_rect.end + Vector2(100000.0, 100000.0))
	if not (edge_hint is Dictionary) or (edge_hint as Dictionary).is_empty():
		_fail("task marker should provide an edge hint when the target is outside the viewport safe area")
		return false
	return true

func _assert_completed_feedback_contract() -> bool:
	CellTaskModuleRuntime.record_objective_completed("5")
	_ui.call("_refresh_task_objective_hud", true)
	await get_tree().process_frame
	var statuses: Array = CellTaskModuleRuntime.get_active_task_statuses(_board)
	if statuses.is_empty() or not (statuses[0] is Dictionary):
		_fail("completed feedback check expected first task status")
		return false
	var status := statuses[0] as Dictionary
	var instruction := str(status.get("instruction", ""))
	var value_text := str(status.get("value_text", ""))
	if str(status.get("state", "")) != "complete":
		_fail("completed feedback check expected complete state, got %s" % str(status.get("state", "")))
		return false
	if value_text.strip_edges() == "" or value_text == instruction:
		_fail("completed task should keep short value feedback separate from instruction, value='%s' instruction='%s'" % [value_text, instruction])
		return false
	var visible_cards := _get_visible_task_cards()
	if visible_cards.is_empty():
		_fail("completed feedback check expected visible task card")
		return false
	var value_label := visible_cards[0].get_node_or_null("CardMargin/Body/Header/Value") as Label
	var instruction_label := visible_cards[0].get_node_or_null("CardMargin/Body/Instruction") as Label
	if value_label == null or instruction_label == null:
		_fail("completed feedback check missing card labels")
		return false
	if value_label.text.strip_edges() == "" or value_label.text == instruction_label.text:
		_fail("completed HUD value feedback should not be replaced by instruction")
		return false
	return true

func _assert_legacy_long_text_contract() -> bool:
	_reset_runtime()
	_board.apply_task_module_runtime_state()
	var result := CellTaskModuleRuntime.grant_module("task_clear_rare")
	if not bool(result.get("ok", false)):
		_fail("failed to grant clear task for legacy text check: %s" % str(result))
		return false
	result = CellTaskModuleRuntime.grant_module("task_dodge_epic")
	if not bool(result.get("ok", false)):
		_fail("failed to grant dodge task for legacy text check: %s" % str(result))
		return false
	result = CellTaskModuleRuntime.deploy_inventory_module(0, 5, _board)
	if not bool(result.get("ok", false)):
		_fail("failed to deploy clear task for legacy text check: %s" % str(result))
		return false
	result = CellTaskModuleRuntime.deploy_inventory_module(0, 6, _board)
	if not bool(result.get("ok", false)):
		_fail("failed to deploy dodge task for legacy text check: %s" % str(result))
		return false
	result = CellTaskModuleRuntime.commit_deployments_for_battle(_board, true)
	if not bool(result.get("ok", false)):
		_fail("failed to commit legacy text check tasks: %s" % str(result))
		return false
	PhaseManager.enter_battle()
	_board.apply_task_module_runtime_state()
	await get_tree().process_frame
	await get_tree().process_frame
	var statuses: Array = CellTaskModuleRuntime.get_active_task_statuses(_board)
	if statuses.size() != 2:
		_fail("legacy text check expected two statuses, got %d" % statuses.size())
		return false
	for status in statuses:
		if not (status is Dictionary):
			_fail("legacy text check status is not a Dictionary")
			return false
		var status_dict := status as Dictionary
		var type_text := str(status_dict.get("type", ""))
		if type_text != "clear" and type_text != "dodge":
			_fail("legacy text check expected clear/dodge status, got %s" % type_text)
			return false
		var value_text := str(status_dict.get("value_text", ""))
		var lower_value := value_text.to_lower()
		if value_text.strip_edges() == "" or lower_value.contains("quest:") or lower_value.contains("remaining"):
			_fail("clear/dodge HUD value_text should not use legacy quest hint text, got '%s'" % value_text)
			return false
	return true

func _assert_all_task_instruction_statuses() -> bool:
	var cases := [
		{"module": "task_kill_common", "type": "kill", "key": "ui.task_objective.instruction.kill", "text": "Kill enemies"},
		{"module": "task_hold_common", "type": "hold", "key": "ui.task_objective.instruction.hold", "text": "Stay inside the marked cell"},
		{"module": "task_clear_rare", "type": "clear", "key": "ui.task_objective.instruction.clear", "text": "Clear enemies near this cell"},
		{"module": "task_hunt_rare", "type": "hunt", "key": "ui.task_objective.instruction.hunt", "text": "Defeat the marked elite"},
		{"module": "task_dodge_epic", "type": "dodge", "key": "ui.task_objective.instruction.dodge", "text": "Avoid damage until timer ends"},
	]
	for start in range(0, cases.size(), 2):
		_reset_runtime()
		_board.apply_task_module_runtime_state()
		var active_cases := cases.slice(start, mini(start + 2, cases.size()))
		for case_data in active_cases:
			var result := CellTaskModuleRuntime.grant_module(str(case_data.get("module", "")))
			if not bool(result.get("ok", false)):
				_fail("failed to grant instruction case task: %s" % str(result))
				return false
		for index in range(active_cases.size()):
			var cell_id := 5 + index
			var result := CellTaskModuleRuntime.deploy_inventory_module(0, cell_id, _board)
			if not bool(result.get("ok", false)):
				_fail("failed to deploy instruction case task: %s" % str(result))
				return false
		var commit_result := CellTaskModuleRuntime.commit_deployments_for_battle(_board, true)
		if not bool(commit_result.get("ok", false)):
			_fail("failed to commit instruction case tasks: %s" % str(commit_result))
			return false
		PhaseManager.enter_battle()
		_board.apply_task_module_runtime_state()
		_ui.call("_refresh_task_objective_hud", true)
		await get_tree().process_frame
		await get_tree().process_frame
		var statuses: Array = CellTaskModuleRuntime.get_active_task_statuses(_board)
		if statuses.size() != active_cases.size():
			_fail("instruction case expected %d statuses, got %d" % [active_cases.size(), statuses.size()])
			return false
		var visible_cards := _get_visible_task_cards()
		if visible_cards.size() != active_cases.size():
			_fail("instruction case expected %d visible cards, got %d" % [active_cases.size(), visible_cards.size()])
			return false
		for index in range(active_cases.size()):
			var expected := active_cases[index] as Dictionary
			if not (statuses[index] is Dictionary):
				_fail("instruction case status is not a Dictionary")
				return false
			var status := statuses[index] as Dictionary
			if str(status.get("type", "")) != str(expected.get("type", "")):
				_fail("instruction case type mismatch: expected %s got %s" % [str(expected.get("type", "")), str(status.get("type", ""))])
				return false
			if str(status.get("instruction_key", "")) != str(expected.get("key", "")):
				_fail("instruction key mismatch for %s: got %s" % [str(expected.get("type", "")), str(status.get("instruction_key", ""))])
				return false
			if str(status.get("instruction", "")) != str(expected.get("text", "")):
				_fail("instruction text mismatch for %s: got %s" % [str(expected.get("type", "")), str(status.get("instruction", ""))])
				return false
			if not _assert_visible_card_instruction(visible_cards[index], str(expected.get("text", ""))):
				return false
	return true

func _assert_short_quest_hint_still_works() -> bool:
	_ui.set_quest_hint("Short tip")
	await get_tree().process_frame
	var label := _ui.get_node_or_null("GUI/QuestHint") as Label
	if label == null:
		_fail("UI.set_quest_hint did not create QuestHint label")
		return false
	if label.text != "Short tip" or not label.visible:
		_fail("UI.set_quest_hint should still show short temporary messages")
		return false
	_ui.set_quest_hint("")
	await get_tree().process_frame
	if label.visible:
		_fail("UI.set_quest_hint empty text should hide the short message")
		return false
	return true

func _reset_runtime() -> void:
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 9
	LocalizationManager.set_locale("en", false)
	CellTaskModuleRuntime.reset_runtime_state()
	CellTaskModuleRuntime.load_definitions()
	CellEffectRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()

func _cleanup_scene_nodes() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()
	if _board != null and is_instance_valid(_board):
		_board.queue_free()

func _fail(message: String) -> void:
	push_error("CellTaskCombatHudTest: " + message)
	_reset_runtime()
	_cleanup_scene_nodes()
	get_tree().quit(1)
