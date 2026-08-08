extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures: PackedStringArray = []
var _ui: UI
var _player: Player

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_reset_runtime_state()
	DataHandler.load_weapon_data()
	DataHandler.load_weapon_branch_data()
	PhaseManager.phase = PhaseManager.SETTLEMENT

	_ui = UI_SCENE.instantiate() as UI
	add_child(_ui)
	await get_tree().process_frame
	await get_tree().process_frame

	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(PlayerData.player_weapon_list.size() == 1, "expected player to start with one weapon")
	var weapon := PlayerData.player_weapon_list[0] as Weapon if not PlayerData.player_weapon_list.is_empty() else null
	_expect(weapon != null, "expected starting weapon instance")
	if weapon == null:
		_finish()
		return
	_expect(DataHandler.get_weapon_id_from_instance(weapon) == "1", "expected starting weapon id 1")
	_expect(int(weapon.fuse) == 1, "expected starting weapon fuse 1")

	var reward := RewardInfo.new()
	reward.item_id = "1"
	reward.item_level = 1
	RewardDraftRuntime.set_pending_standard_draft([reward], {"draft_index": 1})
	_expect(RewardDraftRuntime.has_pending_standard_draft(), "expected pending standard draft before grant")
	_expect(TaskRewardManager.is_reward_blocking_interactions(), "expected standard draft to block general rewards")

	var manager := BonusManager.new()
	add_child(manager)
	var granted := manager.grant_reward_immediately(reward)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(granted, "expected duplicate weapon reward to grant")
	_expect(int(weapon.fuse) == 2, "expected duplicate weapon reward to fuse weapon to 2")
	_expect(not _ui.toast_presenter.panel.visible, "duplicate weapon fusion must not use the top system toast")
	_expect(_ui.branch_select_panel != null, "expected branch panel to be created")
	_expect(_ui.branch_select_panel != null and _ui.branch_select_panel.visible, "expected branch panel to open while standard draft is still pending")
	_expect(_ui.branch_select_panel != null and not _ui.branch_select_panel._branch_ids.is_empty(), "expected branch options for machine gun fuse 2")
	_expect(RewardDraftRuntime.has_pending_standard_draft(), "standard draft should still be pending during grant-time branch prompt")

	RewardDraftRuntime.clear_pending_standard_draft()
	PhaseManager.request_settlement_completion_check()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(PhaseManager.current_state() == PhaseManager.SETTLEMENT, "protocol selection must wait for the evolution branch")

	_ui._init_rest_area_ui_controller()
	_ui.rest_area_ui_controller.warehouse_menu_in()
	_expect(
		_ui.warehouse_primary_root == null or not _ui.warehouse_primary_root.visible,
		"warehouse must stay closed while settlement choices are active"
	)

	var branch_id := str(_ui.branch_select_panel._branch_ids[0]) if not _ui.branch_select_panel._branch_ids.is_empty() else ""
	if branch_id != "":
		_ui.branch_select_panel._on_branch_button_pressed(branch_id)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
	_expect(PhaseManager.current_state() == PhaseManager.PROTOCOL_SELECTION, "protocol selection should open after all evolution choices finish")
	_ui.rest_area_ui_controller.warehouse_menu_in()
	_expect(
		_ui.warehouse_primary_root == null or not _ui.warehouse_primary_root.visible,
		"warehouse must stay closed during protocol selection"
	)

	var duplicate_def := DataHandler.read_weapon_data("1") as WeaponDefinition
	var direct_duplicate := duplicate_def.scene.instantiate() as Weapon if duplicate_def and duplicate_def.scene else null
	_expect(direct_duplicate != null, "expected a direct duplicate instance for the equipment invariant")
	if direct_duplicate != null:
		_player.create_weapon(direct_duplicate)
		await get_tree().process_frame
		_expect(PlayerData.player_weapon_list.size() == 1, "direct instance equipment must not create a duplicate weapon id")
		_expect(int(weapon.fuse) == 3, "direct duplicate equipment must fuse the already equipped weapon")
		_expect(not _ui.toast_presenter.panel.visible, "direct duplicate weapon fusion must not use the top system toast")

	var new_weapon_id := ""
	for candidate_id in DataHandler.get_weapon_ids():
		if str(candidate_id) != "1":
			new_weapon_id = str(candidate_id)
			break
	_expect(new_weapon_id != "", "expected a second weapon definition for new-weapon toast coverage")
	if new_weapon_id != "":
		var new_weapon_reward := RewardInfo.new()
		new_weapon_reward.item_id = new_weapon_id
		new_weapon_reward.item_level = 1
		var new_weapon_granted := manager.grant_reward_immediately(new_weapon_reward)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(new_weapon_granted, "expected new weapon reward to grant")
		_expect(not _ui.toast_presenter.panel.visible, "new weapon reward must not use the top system toast")

	_finish()

func _reset_runtime_state() -> void:
	PhaseManager.reset_runtime_state()
	RewardDraftRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PlayerData.reset_runtime_state()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var exit_code := 0
	if _failures.is_empty():
		printerr("PASS reward fuse branch selection")
	else:
		exit_code = 1
		for failure in _failures:
			push_error(failure)
		printerr("FAIL reward fuse branch selection")
	await TEST_TEARDOWN.finish(self, exit_code, _reset_runtime_state)
	_ui = null
	_player = null
