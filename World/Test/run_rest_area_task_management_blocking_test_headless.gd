extends Node

const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE

	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	await get_tree().process_frame

	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	var board := BoardCellGenerator.new()
	board.name = "Board"
	board.cell_scene = CELL_SCENE
	for _index in range(9):
		board.initial_cell_profiles.append(CellProfile.new())
	add_child(board)
	var rest_area := REST_AREA_SCENE.instantiate() as RestArea
	add_child(rest_area)
	await get_tree().process_frame
	await get_tree().process_frame

	if not ui.open_cell_management_panel(&"task"):
		_fail("failed to open task management panel")
		return
	await get_tree().process_frame
	if ui.cell_management_panel == null or not ui.cell_management_panel.visible:
		_fail("task management panel is not visible")
		return
	get_viewport().warp_mouse(Vector2(8, 8))
	await get_tree().process_frame
	if not rest_area._is_mouse_over_ui():
		_fail("task management panel did not block rest-area hover outside the panel")
		return

	print("RestAreaTaskManagementBlockingTest: PASS")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("RestAreaTaskManagementBlockingTest: " + message)
	get_tree().quit(1)
