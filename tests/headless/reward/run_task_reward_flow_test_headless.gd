extends Node

const REST_AREA_SCENE := preload("res://World/rest_area.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const CELL_SCENE := preload("res://Board/Cells/cell.tscn")
const RARITY_UTIL := preload("res://data/LootRarity.gd")

var _ui: UI
var _rest_area: RestArea
var _board: BoardCellGenerator

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	get_tree().current_scene = self
	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	RunRouteManager.reset_runtime_state()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	DataHandler.prepare_world_data()

	var reward_manager := BonusManager.new()
	reward_manager.name = "RewardManager"
	add_child(reward_manager)

	PhaseManager.enter_battle()
	TaskRewardManager.notify_objective_completed("TestCell")
	if not TaskRewardManager.has_pending_reward():
		_fail(1, "TaskRewardFlowTest: objective did not unlock a reward.")
		return
	var first_options := TaskRewardManager.get_pending_reward_options()
	if first_options.size() != 3:
		_fail(2, "TaskRewardFlowTest: objective reward did not contain three options.")
		return
	TaskRewardManager.notify_objective_completed("SecondCell")
	if TaskRewardManager.get_pending_reward_options().size() != 3:
		_fail(3, "TaskRewardFlowTest: repeated objective completion changed reward count.")
		return

	PhaseManager.enter_gameover()
	if TaskRewardManager.has_pending_reward():
		_fail(4, "TaskRewardFlowTest: failed battle retained the reward.")
		return

	PhaseManager.reset_runtime_state()
	PhaseManager.enter_battle()
	PhaseManager.current_level += 1
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.phase_changed.emit(PhaseManager.PREPARE)
	if TaskRewardManager.has_pending_reward():
		_fail(5, "TaskRewardFlowTest: normal battle completion granted a default reward.")
		return

	for route in RunRouteManager.get_available_routes_for_level(0):
		if route != null and not route.battle_enabled:
			_fail(6, "TaskRewardFlowTest: non-battle route remains player-selectable.")
			return

	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PlayerData.player_gold = 211
	if not TaskRewardManager.begin_battle_snapshot():
		_fail(7, "TaskRewardFlowTest: failed to create pending-reward snapshot.")
		return
	PhaseManager.enter_battle()
	TaskRewardManager.notify_objective_completed("PersistentCell")
	PhaseManager.current_level += 1
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.phase_changed.emit(PhaseManager.PREPARE)
	if not TaskRewardManager.prepare_world_start():
		_fail(8, "TaskRewardFlowTest: pending reward was not detected on restart.")
		return
	PlayerData.player_gold = 1
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	TaskRewardManager.reset_runtime_state(true)
	if not TaskRewardManager.restore_snapshot_after_player_spawn():
		_fail(9, "TaskRewardFlowTest: pending-reward rest state was not restored.")
		return
	if not TaskRewardManager.has_pending_reward() or int(PlayerData.player_gold) != 211:
		_fail(10, "TaskRewardFlowTest: pending reward state was not preserved.")
		return

	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PlayerData.player_gold = 137
	if not TaskRewardManager.begin_battle_snapshot():
		_fail(11, "TaskRewardFlowTest: failed to create rollback snapshot.")
		return
	PlayerData.player_gold = 1
	if not TaskRewardManager.prepare_world_start():
		_fail(12, "TaskRewardFlowTest: unfinished battle was not detected on restart.")
		return
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	TaskRewardManager.reset_runtime_state(true)
	if not TaskRewardManager.restore_snapshot_after_player_spawn():
		_fail(13, "TaskRewardFlowTest: rollback snapshot was not restored.")
		return
	if int(PlayerData.player_gold) != 137:
		_fail(14, "TaskRewardFlowTest: player state did not roll back to battle start.")
		return

	if not await _run_task_reward_ui_contract_test():
		return

	TaskRewardManager.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	print("TaskRewardFlowTest: PASS")
	get_tree().quit(0)

func _fail(code: int, message: String) -> void:
	push_error(message)
	TaskRewardManager.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	get_tree().quit(code)

func _run_task_reward_ui_contract_test() -> bool:
	TaskRewardManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	CellTaskModuleRuntime.load_definitions()
	CellEffectRuntime.load_definitions()
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.current_level = 1

	await _setup_ui_rest_area_scene()
	if _ui == null or _rest_area == null:
		_fail(15, "TaskRewardFlowTest: failed to set up UI/rest-area scene for reward panel contract.")
		return false

	var options: Array[RewardInfo] = TaskRewardManager.call("_build_reward_options_from_current_state")
	if options.size() != 3:
		_fail(16, "TaskRewardFlowTest: task reward UI setup did not build three options.")
		return false
	if _count_rewards_of_kind(options, RewardInfo.KIND_CELL_EFFECT) < 2:
		_fail(17, "TaskRewardFlowTest: task reward options did not include at least two terrain rewards.")
		return false
	if _count_rewards_of_kind(options, RewardInfo.KIND_TASK_MODULE) > 1:
		_fail(18, "TaskRewardFlowTest: task reward options included more than one task module.")
		return false

	if not await _assert_regular_reward_selection_entry_still_opens():
		return false

	var opened := _ui.request_task_reward_selection(options, Callable(), 2, 3)
	await get_tree().process_frame
	if not opened:
		_fail(19, "TaskRewardFlowTest: task reward panel did not open.")
		return false

	var panel := _ui.reward_selection_panel
	if panel == null or not panel.is_modal_open():
		_fail(20, "TaskRewardFlowTest: task reward panel is not visible after opening.")
		return false
	if panel.options_box.get_child_count() != 3:
		_fail(21, "TaskRewardFlowTest: task reward panel did not render three reward cards.")
		return false
	if panel.subtitle_label == null or panel.subtitle_label.text.find("Reward 2/3") < 0:
		_fail(22, "TaskRewardFlowTest: task reward panel did not show Reward n/m progress text.")
		return false
	if panel.can_cancel_modal():
		_fail(23, "TaskRewardFlowTest: task reward panel allowed cancellation.")
		return false
	if panel.cancel_visible_modal() or not panel.is_modal_open():
		_fail(24, "TaskRewardFlowTest: task reward panel closed through cancel path.")
		return false
	if not await _assert_uncancelable_task_reward_ignores_cancel_inputs(panel):
		return false
	if not _ui.is_world_interaction_blocked() or not _rest_area._is_world_interaction_blocked():
		_fail(25, "TaskRewardFlowTest: task reward panel did not block UI/rest-area world interaction.")
		return false

	var task_index := _find_reward_index(options, RewardInfo.KIND_TASK_MODULE)
	var cell_index := _find_reward_index(options, RewardInfo.KIND_CELL_EFFECT)
	if task_index < 0 or cell_index < 0:
		_fail(26, "TaskRewardFlowTest: task reward panel options did not include both task module and cell effect rewards.")
		return false

	var task_description := _get_reward_description(options[task_index])
	var cell_description := _get_reward_description(options[cell_index])
	if task_description == "" or cell_description == "":
		_fail(27, "TaskRewardFlowTest: reward description source data was missing.")
		return false
	var task_rarity_text := RARITY_UTIL.get_display_name(options[task_index].get_rarity())
	if task_rarity_text != "" and _control_text_contains(panel.options_box.get_child(task_index), task_rarity_text):
		_fail(28, "TaskRewardFlowTest: task module reward card displayed rarity text.")
		return false
	if _control_text_contains(panel.options_box.get_child(task_index), task_description):
		_fail(29, "TaskRewardFlowTest: task module reward card displayed full description text.")
		return false
	if _control_text_contains(panel.options_box.get_child(cell_index), cell_description):
		_fail(30, "TaskRewardFlowTest: cell effect reward card displayed full description text.")
		return false

	await _select_reward_card(panel, task_index)
	if not _detail_outcome_contains(panel, "Ready To Install"):
		_fail(31, "TaskRewardFlowTest: task module reward detail did not show Ready To Install outcome.")
		return false
	if not _detail_outcome_contains(panel, "Board > Task Management"):
		_fail(40, "TaskRewardFlowTest: task module reward detail did not explain the deployment path.")
		return false
	await _select_reward_card(panel, cell_index)
	if not _detail_outcome_contains(panel, "Cell Effects inventory"):
		_fail(32, "TaskRewardFlowTest: cell effect reward detail did not show Cell Effects inventory outcome.")
		return false
	if _detail_outcome_contains(panel, "Board > Task Management"):
		_fail(41, "TaskRewardFlowTest: non-task reward detail displayed the task deployment path.")
		return false

	panel.close_panel()
	await get_tree().process_frame
	if _ui.is_world_interaction_blocked() or _rest_area._is_world_interaction_blocked():
		_fail(33, "TaskRewardFlowTest: task reward panel left world interaction blocked after close.")
		return false
	return true

func _setup_ui_rest_area_scene() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		return
	get_tree().root.add_child(player)
	await get_tree().process_frame

	_ui = UI_SCENE.instantiate() as UI
	if _ui == null:
		return
	get_tree().root.add_child(_ui)

	_board = BoardCellGenerator.new()
	_board.name = "Board"
	_board.cell_scene = CELL_SCENE
	_board.auto_assign_enemy_on_battle = false
	for _index in range(9):
		_board.initial_cell_profiles.append(CellProfile.new())
	add_child(_board)

	_rest_area = REST_AREA_SCENE.instantiate() as RestArea
	_rest_area.board_path = NodePath("../Board")
	_rest_area.add_to_group("rest_area")
	add_child(_rest_area)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	_rest_area._set_camera_owner_active(false)
	await get_tree().process_frame

func _find_reward_index(options: Array[RewardInfo], reward_kind: StringName) -> int:
	for index in range(options.size()):
		var reward := options[index]
		if reward != null and reward.reward_kind == reward_kind:
			return index
	return -1

func _count_rewards_of_kind(options: Array[RewardInfo], reward_kind: StringName) -> int:
	var count := 0
	for reward in options:
		if reward != null and reward.reward_kind == reward_kind:
			count += 1
	return count

func _assert_regular_reward_selection_entry_still_opens() -> bool:
	var reward_manager := get_node_or_null("RewardManager") as BonusManager
	if reward_manager == null:
		_fail(34, "TaskRewardFlowTest: missing reward manager for regular reward entry smoke.")
		return false
	var economy := EconomyConfig.new()
	economy.reward_module_options_enabled = true
	economy.reward_weapon_option_chance = 0.0
	economy.reward_economy_option_chance = 0.0
	GlobalVariables.economy_data = economy
	var battle_options := reward_manager.build_reward_selection_options(0, RunRouteManager.get_route_for_level(0), 3)
	if battle_options.is_empty():
		_fail(35, "TaskRewardFlowTest: regular reward entry did not build any reward options.")
		return false
	var module_index := _find_module_reward_index(battle_options)
	if module_index < 0:
		_fail(42, "TaskRewardFlowTest: regular reward draft did not include a module option when enabled.")
		return false
	if not _ui.request_reward_selection("Battle Reward", battle_options, Callable(), Callable(), true):
		_fail(36, "TaskRewardFlowTest: regular reward selection entry did not open.")
		return false
	await get_tree().process_frame
	var panel := _ui.reward_selection_panel
	if panel == null or not panel.is_modal_open() or not panel.can_cancel_modal():
		_fail(37, "TaskRewardFlowTest: regular reward selection panel did not remain cancelable.")
		return false
	await _select_reward_card(panel, module_index)
	if panel.detail_body_label == null or panel.detail_body_label.text.find("Effect Tags:") < 0:
		_fail(43, "TaskRewardFlowTest: module reward detail did not show effect tags.")
		return false
	if panel.detail_body_label.text.find("Fit:") < 0:
		_fail(44, "TaskRewardFlowTest: module reward detail did not show fit status.")
		return false
	if panel.detail_body_label.text.find("Best On:") >= 0:
		_fail(46, "TaskRewardFlowTest: module reward detail still showed best-fit recommendation text.")
		return false
	if not _detail_outcome_contains(panel, "Temporary Modules"):
		_fail(45, "TaskRewardFlowTest: module reward detail did not show its inventory landing.")
		return false
	panel.close_panel()
	await get_tree().process_frame
	return true

func _find_module_reward_index(options: Array[RewardInfo]) -> int:
	for index in range(options.size()):
		var reward := options[index]
		if reward != null and reward.module_scene != null:
			return index
	return -1

func _assert_uncancelable_task_reward_ignores_cancel_inputs(panel: RewardSelectionPanel) -> bool:
	var action_event := InputEventAction.new()
	action_event.action = &"ui_cancel"
	action_event.pressed = true
	panel._input(action_event)
	await get_tree().process_frame
	if not panel.is_modal_open():
		_fail(38, "TaskRewardFlowTest: task reward panel closed on Esc/ui_cancel input.")
		return false

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_RIGHT
	mouse_event.pressed = true
	panel._input(mouse_event)
	await get_tree().process_frame
	if not panel.is_modal_open():
		_fail(39, "TaskRewardFlowTest: task reward panel closed on right-click cancel input.")
		return false
	return true

func _get_reward_description(reward: RewardInfo) -> String:
	if reward == null:
		return ""
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		var task_definition := CellTaskModuleRuntime.get_definition(reward.task_module_id)
		return task_definition.description.strip_edges() if task_definition != null else ""
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		var effect_definition := CellEffectRuntime.get_definition(reward.cell_effect_id)
		return effect_definition.description.strip_edges() if effect_definition != null else ""
	return ""

func _control_text_contains(root: Node, needle: String) -> bool:
	if root == null or needle.strip_edges() == "":
		return false
	var label := root as Label
	if label != null and label.text.find(needle) >= 0:
		return true
	var button := root as Button
	if button != null and button.text.find(needle) >= 0:
		return true
	for child in root.get_children():
		if _control_text_contains(child, needle):
			return true
	return false

func _select_reward_card(panel: RewardSelectionPanel, index: int) -> void:
	var button := panel.options_box.get_child(index) as Button
	if button != null:
		button.emit_signal("pressed")
	await get_tree().process_frame

func _detail_outcome_contains(panel: RewardSelectionPanel, needle: String) -> bool:
	return panel.detail_outcome_label != null \
		and panel.detail_outcome_label.visible \
		and panel.detail_outcome_label.text.find(needle) >= 0
