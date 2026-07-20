extends Node

const FakePort = preload("res://tests/fixtures/combat/fake_battle_contract_combat_port.gd")
const EliminationRuntime = preload("res://Combat/battle_contract/runtime/elimination_contract_runtime.gd")
const SurvivalRuntime = preload("res://Combat/battle_contract/runtime/survival_contract_runtime.gd")
const OperationRuntime = preload("res://Combat/battle_contract/runtime/operation_contract_runtime.gd")
const ContainmentRuntime = preload("res://Combat/battle_contract/runtime/containment_contract_runtime.gd")
const ExtractionRuntime = preload("res://Combat/battle_contract/runtime/extraction_contract_runtime.gd")
const RewardRuntime = preload("res://Combat/battle_contract/runtime/reward_contract_runtime.gd")

var failures: PackedStringArray = []

func _ready() -> void:
	_test_elimination()
	_test_survival()
	_test_operation()
	_test_containment()
	_test_extraction()
	_test_reward()
	if failures.is_empty():
		print("PASS combat.contract_runtime_matrix")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FAIL combat.contract_runtime_matrix (%d assertions)" % failures.size())
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _completed_collector(snapshot: Dictionary, results: Array) -> void:
	results.append(snapshot.duplicate(true))

func _test_elimination() -> void:
	var port = FakePort.new()
	var runtime = EliminationRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {})
	port.battle_tick.emit({"delta_sec": 0.1})
	_expect(port.external_victory_control and port.monitor_enemy_stalls, "elimination must own victory and monitor stalls")
	_expect(int(port.configured_budget.get("batch_count", 0)) == 3, "elimination must configure three early-game batches")
	port.enemy_spawned.emit({})
	port.spawn_budget_exhausted.emit({})
	_expect(results.is_empty(), "elimination must not finish while an enemy remains")
	port.enemy_died.emit({"was_killed": true, "scaled_hp": 100})
	port.spawn_budget_exhausted.emit({})
	_expect(results.size() == 1, "elimination completion must be emitted exactly once")
	_expect(results.size() == 1 and int(results[0].get("remaining_enemies", -1)) == 0, "elimination result must report no remaining enemies")
	runtime.stop()
	_expect(not port.external_victory_control and not port.monitor_enemy_stalls, "elimination stop must restore port controls")

func _test_survival() -> void:
	var port = FakePort.new()
	var runtime = SurvivalRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {})
	_expect(is_equal_approx(port.configured_duration, 45.0), "survival early duration must be 45 seconds")
	port.enemy_died.emit({"was_killed": true, "scaled_hp": 500})
	_expect(port.heals == [5], "survival resolve should heal once per kill event crossing the threshold")
	port.battle_tick.emit({"delta_sec": 30.0})
	_expect(port.configured_threat > 1.0 and results.is_empty(), "survival must raise threat without completing early")
	port.battle_tick.emit({"delta_sec": 15.0})
	port.battle_tick.emit({"delta_sec": 1.0})
	_expect(results.size() == 1, "survival completion must be guarded against repeat ticks")
	_expect(port.stop_spawning_calls == 1 and port.evacuations.size() == 1, "survival completion must stop spawning and evacuate once")
	runtime.stop()
	_expect(is_equal_approx(port.configured_threat, 1.0), "survival stop must reset threat")

func _test_operation() -> void:
	var port = FakePort.new()
	var runtime = OperationRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"charge_time_min_sec": 10.0, "charge_time_max_sec": 10.0})
	port.battle_tick.emit({"delta_sec": 4.0})
	_expect(runtime.progress == 0.0 and runtime.stalled_sec >= 4.0, "operation progress must pause while player is outside")
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 20})
	port.battle_tick.emit({"delta_sec": 10.0})
	_expect(is_equal_approx(runtime.progress, 0.35), "operation enemy slowdown must have a 35 percent floor")
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 0})
	port.battle_tick.emit({"delta_sec": 6.5})
	port.beacon_presence_changed.emit({"beacon_id": 2, "player_inside": true, "enemy_count": 0})
	port.battle_tick.emit({"delta_sec": 10.0})
	port.battle_tick.emit({"delta_sec": 1.0})
	_expect(results.size() == 1, "operation completion must be guarded after both beacons")
	_expect(port.spawned_beacons.size() == 2 and port.evacuations.size() == 1, "operation must spawn two beacons and evacuate once")
	runtime.stop()

func _test_containment() -> void:
	var port = FakePort.new()
	var runtime = ContainmentRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"rift_count": 3, "seal_duration_sec": 8.0, "reinforcement_interval_sec": 9.0})
	port.battle_tick.emit({"delta_sec": 0.1})
	_expect(port.spawned_objectives.size() == 3, "containment must spawn three legal rifts")
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 20})
	port.battle_tick.emit({"delta_sec": 8.0})
	_expect(is_equal_approx(float(runtime.progress_by_id[1]), 0.35), "containment enemy slowdown must have a 35 percent floor")
	port.battle_tick.emit({"delta_sec": 1.0})
	_expect(port.reinforcement_multipliers.size() == 3 and port.configured_threat > 1.0, "containment must release reinforcements and apply surge threat")
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 0})
	port.battle_tick.emit({"delta_sec": 5.2})
	for rift_id in [2, 3]:
		port.beacon_presence_changed.emit({"beacon_id": rift_id, "player_inside": true, "enemy_count": 0})
		port.battle_tick.emit({"delta_sec": 8.0})
	port.battle_tick.emit({"delta_sec": 1.0})
	_expect(results.size() == 1, "containment completion must be guarded against repeat ticks")
	_expect(results.size() == 1 and float(results[0].get("performance_ratio", -1.0)) >= 0.0 and float(results[0].get("performance_ratio", 2.0)) <= 1.0, "containment performance ratio must be normalized")
	runtime.stop()
	_expect(is_equal_approx(port.configured_threat, 1.0), "containment stop must reset threat")

func _test_extraction() -> void:
	var port = FakePort.new()
	var runtime = ExtractionRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"survival_duration_early_sec": 2.0, "escape_duration_early_sec": 3.0})
	port.battle_tick.emit({"delta_sec": 2.0})
	_expect(runtime.phase == &"extracting" and not port.continuous_spawning, "extraction must stop continuous spawning after holding")
	_expect(port.spawned_objectives.size() == 1 and port.pursuit_wave_calls.size() == 1, "extraction must open one zone and one pursuit wave")
	port.battle_tick.emit({"delta_sec": 4.0})
	_expect(runtime.overtime_sec > 0.0 and results.is_empty(), "extraction overtime must not auto-complete")
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 0})
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 0})
	_expect(results.size() == 1 and float(results[0].get("performance_ratio", 2.0)) >= 0.6, "extraction must complete once with bounded performance")
	runtime.stop()

func _test_reward() -> void:
	var port = FakePort.new()
	var runtime = RewardRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"duration_sec": 5.0, "hp_budget_multiplier": 1.5, "reward_multiplier": 2.5})
	_expect(port.reward_stage_calls.size() == 1 and port.reward_stage_calls[0] == {"enabled": true, "hp_budget_multiplier": 1.5, "reward_multiplier": 2.5}, "reward stage multipliers must reach the combat port")
	port.enemy_spawned.emit({})
	port.spawn_budget_exhausted.emit({})
	port.enemy_died.emit({"was_killed": true})
	port.battle_tick.emit({"delta_sec": 10.0})
	_expect(results.size() == 1 and results[0].get("completion_reason") == &"all_enemies_defeated", "reward must complete once when its exhausted budget is cleared")
	runtime.stop()
	_expect(port.reward_stage_calls.size() == 2 and not bool(port.reward_stage_calls[1].get("enabled", true)), "reward stop must disable reward stage")

	port = FakePort.new()
	runtime = RewardRuntime.new()
	results = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"duration_sec": 1.0})
	port.battle_tick.emit({"delta_sec": 1.0})
	port.battle_tick.emit({"delta_sec": 1.0})
	_expect(results.size() == 1 and results[0].get("completion_reason") == &"timeout", "reward timeout must complete once")
	_expect(port.evacuations.size() == 1, "reward timeout must evacuate enemies")
	runtime.stop()
