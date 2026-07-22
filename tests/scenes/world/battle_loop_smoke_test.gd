extends Node

const FakeUI = preload("res://tests/fixtures/world/fake_battle_loop_ui.gd")
const FakePort = preload("res://tests/fixtures/world/fake_battle_loop_port.gd")
const FakeOwner = preload("res://tests/fixtures/world/fake_rest_area_route_owner.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures: PackedStringArray = []
var _ui: Node
var _port: BattleContractCombatPort
var _owner: Node
var _reward_manager: BonusManager

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_reset_runtime_state()
	SaveManager.clear_run()
	DataHandler.load_economy_data()
	PhaseManager.current_level = 2
	PhaseManager.phase = PhaseManager.PREPARE
	PhaseManager.post_battle_collect_gate_timeout_sec = 5.0
	PlayerData.run_completed_levels = 5

	_ui = FakeUI.new()
	GlobalVariables.ui = _ui
	_reward_manager = BonusManager.new()
	add_child(_reward_manager)
	_port = FakePort.new()
	BattleContractManager.bind_combat_port(_port)
	_owner = FakeOwner.new()
	add_child(_owner)
	await get_tree().process_frame

	_owner.route_flow.request_battle_contract()
	_expect(_ui.received_options.size() >= 2 and _ui.received_options.size() <= 3, "prepare route should present two or three contract options")
	_expect(BattleContractManager.state == BattleContractManager.OFFERED, "contract manager should enter offered state")
	_expect(_ui.confirm_callback.is_valid(), "contract selection UI should receive a confirmation callback")
	if _ui.received_options.is_empty() or not _ui.confirm_callback.is_valid():
		_finish()
		return

	var elimination = _ui.received_options.filter(func(option): return option.contract_id == &"elimination").front()
	_expect(BattleContractManager.select_contract(elimination), "elimination option should be selectable")
	_ui.confirm_callback.call()
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(PhaseManager.current_state() == PhaseManager.BATTLE, "confirmed contract should enter battle phase")
	_expect(BattleContractManager.state == BattleContractManager.ACTIVE, "confirmed contract should activate its runtime")
	_expect(_port.start_spawning_calls == 1, "battle start should request spawning exactly once")
	_expect(_port.external_victory_enabled, "elimination runtime should own victory completion")
	_expect(_ui.intro_prepared and _ui.selection_closed and _ui.battle_intro_played, "battle UI transition hooks should all run")
	_expect(FileAccess.file_exists("user://battle_rollback_snapshot.json"), "battle start should persist a rollback snapshot")
	_expect(not SaveManager.has_run(), "entering battle must not write the main run save")
	_expect(not FileAccess.file_exists(SaveManager.CHECKPOINT_PATH), "entering battle must not write a main-save checkpoint")

	var previous_level := PhaseManager.current_level
	var previous_completed := PlayerData.run_completed_levels
	_port.enemy_spawned.emit({})
	_port.spawn_budget_exhausted.emit({})
	_expect(BattleContractManager.state == BattleContractManager.ACTIVE, "living enemies should prevent elimination completion")
	_port.enemy_died.emit({"was_killed": true, "scaled_hp": 100})
	await get_tree().create_timer(1.15).timeout
	await get_tree().process_frame

	_expect(BattleContractManager.state == BattleContractManager.COMPLETED, "last enemy death should complete elimination")
	_expect(_port.finish_battle_calls == 1, "completed contract should request battle finish once")
	_expect(str(_port.last_finish_result.get("contract_id", "")) == "elimination", "finish result should identify the completed contract")
	_expect(PhaseManager.current_state() == PhaseManager.PREPARE, "victory transition should return to prepare phase")
	_expect(PhaseManager.current_level == previous_level + 1, "victory should advance one level")
	_expect(PlayerData.run_completed_levels == previous_completed + 1, "victory should increment completed run levels")
	_expect(PhaseManager.is_post_battle_collect_gate_active(), "prepare transition should open the post-battle collection gate")
	_expect(_ui.purchase_refresh_reset, "third-battle shop cycle should reset purchase refresh cost")
	_expect(PhaseManager.is_full_shop_open(), "full shop should open after every third completed battle")
	_expect(SaveManager.has_run(), "victory return to prepare must write the main run save")

	PhaseManager.complete_post_battle_collect_gate()
	await get_tree().create_timer(1.65).timeout
	await get_tree().process_frame
	_expect(not PhaseManager.is_post_battle_collect_gate_active(), "collection gate should be explicitly completable")
	_expect(_ui.standard_reward_requests == 1, "standard battle reward should be requested once after the collection gate")
	_finish()

func _reset_runtime_state() -> void:
	BattleContractManager.unbind_combat_port()
	BattleContractManager.reset_persistent_state()
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
		printerr("PASS world.battle_loop_smoke")
	else:
		exit_code = 1
		for failure in _failures:
			push_error(failure)
		printerr("FAIL world.battle_loop_smoke")
	SaveManager.clear_run()
	await TEST_TEARDOWN.finish(self, exit_code, _reset_runtime_state, [_ui, _port])
	_ui = null
	_port = null
	_owner = null
	_reward_manager = null
