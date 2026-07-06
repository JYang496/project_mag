extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")

var _failures: PackedStringArray = []
var _ui: UI
var _player: Player

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_reset_runtime_state()
	DataHandler.load_weapon_data()
	DataHandler.load_weapon_branch_data()
	PhaseManager.phase = PhaseManager.PREPARE

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
	_expect(_ui.branch_select_panel != null, "expected branch panel to be created")
	_expect(_ui.branch_select_panel != null and _ui.branch_select_panel.visible, "expected branch panel to open while standard draft is still pending")
	_expect(_ui.branch_select_panel != null and not _ui.branch_select_panel._branch_ids.is_empty(), "expected branch options for machine gun fuse 2")
	_expect(RewardDraftRuntime.has_pending_standard_draft(), "standard draft should still be pending during grant-time branch prompt")

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
	_reset_runtime_state()
	if _failures.is_empty():
		printerr("PASS reward fuse branch selection")
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error(failure)
	printerr("FAIL reward fuse branch selection")
	get_tree().quit(1)
