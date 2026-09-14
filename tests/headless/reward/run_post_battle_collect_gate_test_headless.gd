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
	PhaseManager.phase = PhaseManager.BATTLE

	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	PlayerData.earn_gold(50, true)
	_expect(PlayerData.get_pending_gold_supplies().size() == 2, "gold earnings crossing two thresholds must enqueue two supplies")

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
	var reward := RewardInfo.new()
	reward.gold_value = 1
	RewardDraftRuntime.set_pending_standard_draft([reward], {"draft_index": 1})
	var pickup_radius: float = _player.grab_radius.shape.radius
	PhaseManager.enter_settlement()
	_expect(is_equal_approx(_player.grab_radius.shape.radius, pickup_radius), "settlement must preserve normal pickup range")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(not _rest_area.is_active(), "rest area must remain inactive during reward settlement")
	_expect(not _player.is_auto_nav_active(), "settlement must not route the player into an unselected rest protocol")
	_expect(_ui.gold_supply_controller.active, "first pending supply must open immediately without auto-collect waiting")
	_expect(RewardDraftRuntime.is_standard_draft_blocking_interactions(), "protocol reward must remain queued while supply is open")
	_claim_current_supply()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_ui.gold_supply_controller.active, "second pending supply must open before protocol reward")
	_claim_current_supply()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(PlayerData.get_pending_gold_supplies().is_empty(), "all pending supplies must be claimed before protocol reward")
	_expect(not _ui.gold_supply_controller.active, "supply panel must close before protocol reward panel opens")
	_expect(_is_reward_panel_open(), "reward panel should open only after all supplies clear")
	_expect(PhaseManager.current_state() == PhaseManager.SETTLEMENT, "settlement remains active until the reward is confirmed")

	_finish()

func _claim_current_supply() -> void:
	var controller = _ui.gold_supply_controller
	if controller == null or controller._rewards.is_empty():
		_expect(false, "supply controller must expose prepared rewards")
		return
	# The reserved core option never requires a replacement dialog.
	controller._selected(controller._rewards.back(), controller._generation)

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
