extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PORT_SCRIPT := preload("res://Combat/battle_contract/BattleContractCombatPort.gd")
const ELIMINATION := preload("res://Combat/battle_contract/runtime/elimination_contract_runtime.gd")
const SURVIVAL := preload("res://Combat/battle_contract/runtime/survival_contract_runtime.gd")
const CONTAINMENT := preload("res://Combat/battle_contract/runtime/containment_contract_runtime.gd")
const EXTRACTION := preload("res://Combat/battle_contract/runtime/extraction_contract_runtime.gd")

var failures := 0

class FakePort extends PORT_SCRIPT:
	var planned_hp := 100
	var frequency := 1.0
	var elite_hp := 0
	var mortar_calls := 0
	var spawned_objectives: Array[int] = []
	var points := PackedVector2Array([Vector2(10, 10), Vector2(100, 10), Vector2(200, 10)])

	func request_configure_finite_budget(total_budget: float, _batch_count: int) -> void: planned_hp = int(total_budget)
	func request_configure_spawn_frequency_multiplier(multiplier: float) -> void: frequency = multiplier
	func get_spawn_budget_snapshot() -> Dictionary: return {"planned_total_hp": planned_hp, "planned_enemy_count": 4}
	func get_active_enemy_count() -> int: return 0
	func get_level_index() -> int: return 0
	func get_level_duration_sec() -> float: return 30.0
	func get_battle_intro_snapshot() -> Dictionary: return {"target_total_hp": 500}
	func request_spawn_contract_elite(target_hp: int) -> bool: elite_hp = target_hp; return true
	func request_spawn_mortar_barrage(_options: Dictionary) -> int: mortar_calls += 1; return 2
	func get_battlefield_capabilities() -> Dictionary: return {"containment_points": points, "extraction_points": points}
	func request_spawn_objective(objective_id: int, _position: Vector2, _visual_kind: StringName = &"containment") -> void: spawned_objectives.append(objective_id)

func _ready() -> void:
	_test_elimination()
	_test_survival()
	_test_containment()
	_test_extraction()
	print("PASS enhanced contract runtime" if failures == 0 else "FAIL enhanced contract runtime")
	await TEST_TEARDOWN.finish(self, 0 if failures == 0 else 1)

func _test_elimination() -> void:
	var port := FakePort.new()
	var runtime = ELIMINATION.new()
	runtime.start(port, {"hp_budget_multiplier": 1.3, "spawn_frequency_multiplier": 2.0})
	port.battle_tick.emit({"delta_sec": 0.1})
	_expect(port.planned_hp == 130, "Enhanced elimination must raise the finite HP budget by 30%")
	_expect(is_equal_approx(port.frequency, 2.0), "Enhanced elimination must double spawn scheduling frequency")
	runtime.stop()
	_expect(is_equal_approx(port.frequency, 1.0), "Elimination teardown must restore spawn frequency")

func _test_survival() -> void:
	var port := FakePort.new()
	var runtime = SURVIVAL.new()
	runtime.start(port, {"elite_hp_budget_multiplier": 1.0})
	port.battle_tick.emit({"delta_sec": 0.1})
	port.battle_tick.emit({"delta_sec": 0.1})
	_expect(port.elite_hp == 500, "Enhanced survival must spawn one elite with level-budget HP")
	_expect(bool(runtime._snapshot().get("enhanced_elite_spawned", false)), "Enhanced survival must record its elite spawn")
	runtime.stop()

func _test_containment() -> void:
	var port := FakePort.new()
	var runtime = CONTAINMENT.new()
	runtime.start(port, {"rift_count": 1, "mortar_initial_delay_sec": 0.1, "mortar_interval_min_sec": 1.0, "mortar_interval_max_sec": 1.0})
	port.battle_tick.emit({"delta_sec": 0.2})
	_expect(port.mortar_calls == 1, "Enhanced containment must schedule periodic mortar barrages")
	runtime.stop()

func _test_extraction() -> void:
	var port := FakePort.new()
	var runtime = EXTRACTION.new()
	runtime.start(port, {"survival_duration_early_sec": 1.0, "early_level_count": 4, "escape_duration_early_sec": 5.0, "navigation_key_count": 2})
	port.battle_tick.emit({"delta_sec": 1.1})
	_expect(runtime.phase == &"collecting_keys" and port.spawned_objectives.has(101) and port.spawned_objectives.has(102), "Enhanced extraction must open two navigation keys before extraction")
	port.beacon_presence_changed.emit({"beacon_id": 101, "player_inside": true, "enemy_count": 0})
	port.beacon_presence_changed.emit({"beacon_id": 102, "player_inside": true, "enemy_count": 0})
	_expect(runtime.phase == &"extracting" and port.spawned_objectives.has(1), "Collecting both keys must unlock the extraction zone")
	runtime.stop()

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error("FAIL: %s" % message)

