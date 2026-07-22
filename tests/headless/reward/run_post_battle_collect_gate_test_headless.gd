extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const BOARD_GENERATOR_SCRIPT := preload("res://World/board_cell_generator.gd")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures: PackedStringArray = []
var _ui: UI
var _player: Player
var _reward_manager: BonusManager
var _board: BoardCellGenerator
var _rest_area: RestArea

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_reset_runtime_state()
	DataHandler.load_weapon_data()
	DataHandler.load_weapon_branch_data()
	DataHandler.load_economy_data()
	PhaseManager.post_battle_collect_gate_timeout_sec = 5.0
	PhaseManager.phase = PhaseManager.BATTLE

	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

	_ui = UI_SCENE.instantiate() as UI
	add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame
	GlobalVariables.ui = _ui

	_board = BOARD_GENERATOR_SCRIPT.new() as BoardCellGenerator
	_board.name = "Board"
	_board.cell_scene = CELL_SCENE
	add_child(_board)
	await get_tree().process_frame

	_rest_area = REST_AREA_SCENE.instantiate() as RestArea
	_rest_area.name = "RestArea"
	_rest_area.board_path = NodePath("../Board")
	add_child(_rest_area)
	await get_tree().process_frame
	await get_tree().process_frame

	_reward_manager = BonusManager.new()
	add_child(_reward_manager)
	await get_tree().process_frame

	var rest_center := _rest_area.get_spawn_position()
	_player.global_position = rest_center + Vector2(180.0, 0.0)
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.begin_post_battle_collect_gate(5.0)
	_rest_area.call("_on_phase_changed", PhaseManager.PREPARE)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(PhaseManager.is_post_battle_collect_gate_active(), "expected collect gate to be active")
	_expect(TaskRewardManager.is_reward_blocking_interactions(), "expected collect gate to block rest rewards")
	_expect(_player.is_auto_nav_active(), "player should auto-navigate to rest center while collect gate is active")
	_expect(not bool(_player.movement_enabled), "manual player movement should remain disabled during collect gate auto-navigation")
	_expect(_player.moveto_dest.distance_to(rest_center) <= 1.0, "auto-navigation target should be rest center")

	var reward := RewardInfo.new()
	reward.gold_value = 1
	RewardDraftRuntime.set_pending_standard_draft([reward], {"draft_index": 1})
	_reward_manager.call("_open_completed_battle_standard_draft_if_ready")
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(not _is_reward_panel_open(), "reward panel should wait while collect gate is active")
	PhaseManager.complete_post_battle_collect_gate()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(_is_reward_panel_open(), "reward panel should open after collect gate clears")
	_expect(not PhaseManager.is_post_battle_collect_gate_active(), "expected collect gate to be inactive after completion")

	_finish()

func _is_reward_panel_open() -> bool:
	if _ui == null or not is_instance_valid(_ui):
		return false
	if _ui.reward_selection_panel == null or not is_instance_valid(_ui.reward_selection_panel):
		return false
	if _ui.reward_selection_panel.has_method("is_modal_open"):
		return bool(_ui.reward_selection_panel.call("is_modal_open"))
	return _ui.reward_selection_panel.visible

func _reset_runtime_state() -> void:
	PhaseManager.reset_runtime_state()
	RewardDraftRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()
	GlobalVariables.reset_runtime_state()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var exit_code := 0
	if _failures.is_empty():
		printerr("PASS post battle collect gate")
	else:
		exit_code = 1
		for failure in _failures:
			push_error(failure)
		printerr("FAIL post battle collect gate")
	await TEST_TEARDOWN.finish(self, exit_code, _reset_runtime_state)
	_ui = null
	_player = null
	_reward_manager = null
	_board = null
	_rest_area = null
