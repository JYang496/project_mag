extends Node

const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")

var _ui: UI
var _rest_area: RestArea
var _previous_temporary_confirmation_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	get_tree().current_scene = self
	_reset_state()
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail("failed to instantiate player")
		return
	get_tree().root.add_child(player)
	_ui = UI_SCENE.instantiate() as UI
	if _ui == null:
		_fail("failed to instantiate UI")
		return
	get_tree().root.add_child(_ui)
	var board := _make_board()
	add_child(board)
	_rest_area = REST_AREA_SCENE.instantiate() as RestArea
	if _rest_area == null:
		_fail("failed to instantiate RestArea")
		return
	_rest_area.board_path = NodePath("../Board")
	_rest_area.add_to_group("rest_area")
	add_child(_rest_area)
	await get_tree().process_frame
	await get_tree().process_frame
	_previous_temporary_confirmation_enabled = bool(_ui.call("_is_temporary_module_confirmation_enabled"))
	_ui.call("_set_temporary_module_confirmation_enabled", true)

	await _test_temporary_module_confirmation_continues_to_battle()
	if PhaseManager.current_state() == PhaseManager.BATTLE:
		PhaseManager.enter_prepare()
		await get_tree().process_frame
	await _test_chained_confirmations_do_not_require_second_hold()
	if PhaseManager.current_state() == PhaseManager.BATTLE:
		PhaseManager.enter_prepare()
		await get_tree().process_frame
	await _test_hidden_then_confirmed_unassigned_dialog_still_starts_battle()

	_ui.call("_set_temporary_module_confirmation_enabled", _previous_temporary_confirmation_enabled)
	_reset_state()
	print("RestAreaStartBattleConfirmationChainTest: PASS")
	get_tree().quit(0)

func _test_temporary_module_confirmation_continues_to_battle() -> void:
	_reset_state()
	InventoryData.obtain_module(_make_module())
	_rest_area.call("_on_start_battle_button_activated")
	await get_tree().process_frame
	var dialog := _get_dialog()
	if dialog == null or not dialog.visible:
		_fail("temporary module settlement confirmation did not open")
		return
	_confirm_transaction_dialog(dialog)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		_fail("confirming temporary module settlement did not enter battle")

func _test_chained_confirmations_do_not_require_second_hold() -> void:
	_reset_state()
	InventoryData.obtain_module(_make_module())
	CellTaskModuleRuntime.grant_module("task_kill_common")
	_rest_area.call("_on_start_battle_button_activated")
	await get_tree().process_frame
	var dialog := _get_dialog()
	if dialog == null or not dialog.visible:
		_fail("temporary module settlement confirmation did not open before chained confirmation")
		return
	_confirm_transaction_dialog(dialog)
	await get_tree().process_frame
	await get_tree().process_frame
	dialog = _get_dialog()
	if dialog == null or not dialog.visible:
		_fail("unassigned task module confirmation did not appear after first confirmation")
		return
	_confirm_dialog_hide_before_confirmed(dialog)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		_fail("confirming chained task-module prompt did not enter battle")

func _test_hidden_then_confirmed_unassigned_dialog_still_starts_battle() -> void:
	_reset_state()
	CellTaskModuleRuntime.grant_starting_cell_loadout(0)
	_rest_area.call("_on_start_battle_button_activated")
	await get_tree().process_frame
	var dialog := _get_dialog()
	if dialog == null or not dialog.visible:
		_fail("starter unassigned task module confirmation did not open")
		return
	dialog.hide()
	await get_tree().process_frame
	dialog.emit_signal("confirmed")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		_fail("hiding before confirmed swallowed the unassigned task module continue callback")

func _make_board() -> BoardCellGenerator:
	var board := BoardCellGenerator.new()
	board.name = "Board"
	board.cell_scene = CELL_SCENE
	board.auto_assign_enemy_on_battle = false
	for _index in range(9):
		board.initial_cell_profiles.append(CellProfile.new())
	return board

func _make_module() -> Module:
	var module_instance := TEST_MODULE_SCENE.instantiate() as Module
	if module_instance == null:
		_fail("failed to instantiate module")
	return module_instance

func _get_dialog() -> ConfirmationDialog:
	if _ui == null or _ui.modal_dialog_controller == null:
		return null
	return _ui.modal_dialog_controller.dialog as ConfirmationDialog

func _dialog_message(dialog: ConfirmationDialog) -> String:
	if dialog == null:
		return ""
	var message := dialog.find_child("Message", true, false) as Label
	return message.text if message != null else dialog.dialog_text

func _confirm_transaction_dialog(dialog: ConfirmationDialog) -> void:
	if dialog == null:
		return
	dialog.emit_signal("confirmed")
	dialog.hide()

func _confirm_dialog_hide_before_confirmed(dialog: ConfirmationDialog) -> void:
	if dialog == null:
		return
	dialog.hide()
	dialog.emit_signal("confirmed")

func _reset_state() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellTaskModuleRuntime.load_definitions()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 0

func _fail(message: String) -> void:
	if _ui != null:
		_ui.call("_set_temporary_module_confirmation_enabled", _previous_temporary_confirmation_enabled)
	push_error("RestAreaStartBattleConfirmationChainTest: " + message)
	_reset_state()
	get_tree().quit(1)
