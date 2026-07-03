extends Node

const CELL_SCENE := preload("res://Board/Cells/cell.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 0
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()

	var cell := CELL_SCENE.instantiate() as Cell
	if cell == null:
		_fail("cell scene did not instantiate a Cell")
		return
	add_child(cell)
	await get_tree().process_frame

	if not await _assert_cell_activation_contract(cell):
		return
	if not await _assert_board_initialization_contract():
		return

	cell.queue_free()
	await get_tree().process_frame
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	print("CellActivationVisualTest: PASS")
	get_tree().quit(0)

func _assert_cell_activation_contract(cell: Cell) -> bool:
	var area := cell.get_node_or_null("Area2D") as Area2D
	if area == null:
		_fail("cell scene is missing Area2D")
		return false
	var activation_visual := cell.get_node_or_null("ActivationVisual") as Node
	if activation_visual == null:
		_fail("cell scene is missing ActivationVisual")
		return false
	if not _assert_activation_visual_methods(activation_visual):
		return false

	cell.set_locked(false)
	await get_tree().process_frame
	if int(cell.state) == Cell.CellState.LOCKED:
		_fail("cell did not leave locked state before board disable check")
		return false

	cell.set_task_marker_status({
		"type": "kill",
		"icon_key": "kill",
		"label": "Kill Task",
		"progress": 0.5,
		"value_text": "1/2",
		"state": "active",
	})
	await get_tree().process_frame
	var task_marker := cell.get_node_or_null("TaskMarkerVisual") as Node2D
	if task_marker == null:
		_fail("task marker visual was not created for a valid task status")
		return false
	if not task_marker.visible:
		_fail("task marker visual was not visible for a valid task status")
		return false

	cell.set_board_enabled(false)
	await get_tree().process_frame
	await get_tree().process_frame
	if bool(cell.board_enabled):
		_fail("set_board_enabled(false) did not update board_enabled")
		return false
	if int(cell.state) != Cell.CellState.LOCKED:
		_fail("set_board_enabled(false) did not keep the cell locked/disabled")
		return false
	if area.monitoring or area.monitorable:
		_fail("set_board_enabled(false) did not disable Area2D monitoring/monitorable")
		return false
	if not cell.get_active_task_marker_status().is_empty():
		_fail("disabling the board should not leave an active task marker status")
		return false
	if task_marker.visible:
		_fail("disabling the board should hide the existing task marker visual")
		return false

	cell.set_board_enabled(true)
	await get_tree().process_frame
	await get_tree().process_frame
	if not bool(cell.board_enabled):
		_fail("set_board_enabled(true) did not restore board_enabled")
		return false
	if not area.monitoring or not area.monitorable:
		_fail("set_board_enabled(true) did not restore Area2D monitoring/monitorable")
		return false
	if activation_visual.has_method("configure"):
		activation_visual.call("configure", true, false, true, Rect2(Vector2.ZERO, Vector2(128.0, 128.0)))
	cell.set_task_marker_status({
		"type": "hold",
		"icon_key": "hold",
		"label": "Hold Task",
		"progress": 0.25,
		"value_text": "1s",
		"state": "active",
	})
	await get_tree().process_frame
	if not task_marker.visible:
		_fail("task marker visual did not recover after set_board_enabled(true)")
		return false
	return true

func _assert_activation_visual_methods(activation_visual: Node) -> bool:
	for method_name in [
		"configure",
		"set_active_visual",
		"set_player_highlighted",
		"set_task_or_objective_present",
		"set_active_boundary_edges",
	]:
		if not activation_visual.has_method(method_name):
			_fail("ActivationVisual is missing method %s" % method_name)
			return false
	activation_visual.call("set_active_visual", false)
	activation_visual.call("set_player_highlighted", true)
	activation_visual.call("set_task_or_objective_present", true)
	activation_visual.call("set_active_boundary_edges", PackedStringArray(["left", "top"]))
	activation_visual.call("configure", true, false, false, Rect2(Vector2.ZERO, Vector2(64.0, 64.0)))
	return true

func _assert_board_initialization_contract() -> bool:
	var board := BoardCellGenerator.new()
	board.name = "CellActivationVisualBoardSmoke"
	board.cell_scene = CELL_SCENE
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame

	var cells := board.get_cells()
	if cells.size() != 9:
		_fail("board initialization did not create 9 cells")
		board.queue_free()
		return false
	for board_cell in cells:
		if board_cell == null:
			_fail("board initialization produced a null cell")
			board.queue_free()
			return false
		if board_cell.get_node_or_null("ActivationVisual") == null:
			_fail("board cell %d is missing ActivationVisual" % board_cell.logical_id)
			board.queue_free()
			return false
		var area := board_cell.get_node_or_null("Area2D") as Area2D
		if area == null:
			_fail("board cell %d is missing Area2D" % board_cell.logical_id)
			board.queue_free()
			return false
		if board.is_cell_active_by_id(board_cell.logical_id) and not bool(board_cell.board_enabled):
			_fail("active board cell %d was not board-enabled after initialization" % board_cell.logical_id)
			board.queue_free()
			return false
		if not board.is_cell_active_by_id(board_cell.logical_id) and bool(board_cell.board_enabled):
			_fail("inactive board cell %d stayed board-enabled after initialization" % board_cell.logical_id)
			board.queue_free()
			return false
	var cell_five := board.get_cell_by_logical_id(5)
	var cell_six := board.get_cell_by_logical_id(6)
	if cell_five == null or cell_six == null:
		_fail("board did not create expected active cells 5 and 6")
		board.queue_free()
		return false
	if board._get_inactive_neighbor_edges(5).is_empty() or board._get_inactive_neighbor_edges(6).is_empty():
		_fail("active cells did not report inactive-neighbor boundary edges")
		board.queue_free()
		return false
	board.queue_free()
	await get_tree().process_frame
	return true

func _fail(message: String) -> void:
	push_error("CellActivationVisualTest: " + message)
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	get_tree().quit(1)
