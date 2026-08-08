extends Node

const FakeUI = preload("res://tests/fixtures/world/fake_battle_loop_ui.gd")
const FakePort = preload("res://tests/fixtures/world/fake_battle_loop_port.gd")
const FakeOwner = preload("res://tests/fixtures/world/fake_rest_area_route_owner.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures: PackedStringArray = []
var _ui: Node
var _port: BattleContractCombatPort
var _owner: Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_reset_runtime_state()
	SaveManager.clear_run()
	DataHandler.load_economy_data()
	_ui = FakeUI.new()
	GlobalVariables.ui = _ui
	_port = FakePort.new()
	BattleContractManager.bind_combat_port(_port)
	_owner = FakeOwner.new()
	add_child(_owner)
	await get_tree().process_frame

	GlobalVariables.request_new_game_battle()
	_expect(GlobalVariables.consume_new_game_battle_request(), "new game should schedule one initial battle")
	_expect(not GlobalVariables.consume_new_game_battle_request(), "initial battle request must be consumed exactly once")
	_owner.route_flow.request_battle_contract()
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(PhaseManager.current_state() == PhaseManager.BATTLE, "new game should enter battle without stopping in the rest area")
	_expect(BattleContractManager.state == BattleContractManager.ACTIVE, "initial fixed contract should be active")
	_expect(BattleContractManager.selected_contract != null and BattleContractManager.selected_contract.contract_id == &"elimination", "new game should use the configured initial contract")
	_expect(_ui.received_options.is_empty(), "initial fixed contract should not open protocol selection UI")
	_expect(_port.start_spawning_calls == 1, "initial battle should start spawning exactly once")
	_finish()

func _reset_runtime_state() -> void:
	BattleContractManager.unbind_combat_port()
	BattleContractManager.reset_persistent_state()
	PhaseManager.reset_runtime_state()
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
		printerr("PASS world.new_game_direct_battle")
	else:
		exit_code = 1
		for failure in _failures:
			push_error(failure)
			printerr("FAIL world.new_game_direct_battle")
	SaveManager.clear_run()
	await TEST_TEARDOWN.finish(self, exit_code, _reset_runtime_state, [_ui, _port])
	_ui = null
	_port = null
	_owner = null
