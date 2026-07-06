extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")

var _failures: PackedStringArray = []
var _ui: UI
var _player: Player
var _reward_manager: BonusManager

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_reset_runtime_state()
	DataHandler.load_weapon_data()
	DataHandler.load_weapon_branch_data()
	DataHandler.load_economy_data()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.begin_post_battle_collect_gate(5.0)
	_expect(PhaseManager.is_post_battle_collect_gate_active(), "expected collect gate to be active")
	_expect(TaskRewardManager.is_reward_blocking_interactions(), "expected collect gate to block rest rewards")

	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

	_ui = UI_SCENE.instantiate() as UI
	add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame
	GlobalVariables.ui = _ui

	_reward_manager = BonusManager.new()
	add_child(_reward_manager)
	await get_tree().process_frame

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
	_reset_runtime_state()
	if _failures.is_empty():
		printerr("PASS post battle collect gate")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	printerr("FAIL post battle collect gate")
	get_tree().quit(1)
