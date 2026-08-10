extends Node

const FakePort = preload("res://tests/fixtures/combat/fake_battle_contract_combat_port.gd")
const EliminationRuntime = preload("res://Combat/battle_contract/runtime/elimination_contract_runtime.gd")
const SurvivalRuntime = preload("res://Combat/battle_contract/runtime/survival_contract_runtime.gd")
const OperationRuntime = preload("res://Combat/battle_contract/runtime/operation_contract_runtime.gd")
const ContainmentRuntime = preload("res://Combat/battle_contract/runtime/containment_contract_runtime.gd")
const ExtractionRuntime = preload("res://Combat/battle_contract/runtime/extraction_contract_runtime.gd")
const RewardRuntime = preload("res://Combat/battle_contract/runtime/reward_contract_runtime.gd")
const RewardEnemyScene = preload("res://Npc/enemy/scenes/reward_enemy.tscn")
const FinaleDefinition = preload("res://data/battle_contracts/finale.tres")

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
	var configured_port = FakePort.new()
	configured_port.level_index = 4
	var configured_runtime = EliminationRuntime.new()
	configured_runtime.start(configured_port, {"batch_count_min": 2, "batch_count_max": 6, "levels_per_batch_step": 2, "early_release_ratio": 0.5, "batch_wait_timeout_sec": 5.0, "standard_duration_sec": 33.0})
	_expect(configured_port.spawn_policy.get("mode") == &"finite", "elimination must use the finite spawn policy")
	configured_port.battle_tick.emit({"delta_sec": 0.1})
	_expect(configured_runtime.total_batches == 4 and int(configured_port.configured_budget.get("batch_count", 0)) == 4, "elimination must derive batch count from protocol parameters")
	_expect(is_equal_approx(configured_runtime.early_release_ratio, 0.5) and is_equal_approx(configured_runtime.batch_wait_timeout_sec, 5.0), "elimination release pacing must come from protocol parameters")
	_expect(is_equal_approx(configured_runtime.standard_duration_sec, 33.0), "elimination reward baseline must come from protocol parameters")
	configured_port.enemy_spawned.emit({})
	configured_port.enemy_spawned.emit({})
	configured_port.enemy_died.emit({"was_killed": true, "scaled_hp": 100})
	_expect(configured_port.released_batches == 1, "configured elimination release ratio must advance the next batch")
	configured_runtime.stop()
	var tail_port = FakePort.new()
	tail_port.spawn_budget_snapshot = {"planned_total_hp": 300, "planned_enemy_count": 3}
	var tail_runtime = EliminationRuntime.new()
	tail_runtime.start(tail_port, {"batch_count_min": 3, "batch_count_max": 3})
	tail_port.battle_tick.emit({"delta_sec": 0.1})
	_expect(tail_runtime.current_batch == 3 and tail_port.released_batches == 2, "one-target-per-batch elimination tail must merge dynamically")
	tail_port.enemy_spawned.emit({})
	var tail_snapshot := tail_runtime._snapshot()
	_expect(int(tail_snapshot.get("active_enemies", -1)) == 1 and int(tail_snapshot.get("queued_enemies", -1)) == 2, "elimination snapshot must distinguish active enemies from queued reinforcements")
	tail_runtime.stop()
	var formation_port = FakePort.new()
	formation_port.spawn_budget_snapshot = {"planned_total_hp": 400, "planned_enemy_count": 4}
	var formation_runtime = EliminationRuntime.new()
	formation_runtime.start(formation_port, {"batch_count_min": 3, "batch_count_max": 3})
	formation_port.battle_tick.emit({"delta_sec": 0.1})
	_expect(formation_runtime.current_batch == 1 and formation_port.released_batches == 0, "multi-target opening formation must retain normal batch pacing")
	formation_runtime.stop()
	var finale_port = FakePort.new()
	finale_port.level_index = 9
	var finale_runtime = EliminationRuntime.new()
	finale_runtime.start(finale_port, FinaleDefinition.parameters)
	_expect(finale_runtime.total_batches == 3, "finale must retain exactly three finite batches")
	_expect(is_equal_approx(float(finale_port.spawn_policy.get("soft_cap_multiplier")), 1.10) and is_equal_approx(float(finale_port.spawn_policy.get("hard_cap_multiplier")), 1.25), "finale must pass its finite HP safety caps into the elimination runtime")
	finale_runtime.stop()

	var port = FakePort.new()
	var runtime = EliminationRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {})
	port.battle_tick.emit({"delta_sec": 0.1})
	_expect(port.external_victory_control and port.monitor_enemy_stalls, "elimination must own victory and monitor stalls")
	_expect(int(port.configured_budget.get("batch_count", 0)) == 3, "elimination must configure three early-game batches")
	port.active_enemy_count = 1
	port.enemy_spawned.emit({})
	port.spawn_budget_exhausted.emit({})
	_expect(results.is_empty(), "elimination must not finish while an enemy remains")
	port.active_enemy_count = 0
	port.enemy_died.emit({"was_killed": true, "scaled_hp": 100})
	port.spawn_budget_exhausted.emit({})
	_expect(results.size() == 1, "elimination completion must be emitted exactly once")
	_expect(results.size() == 1 and int(results[0].get("remaining_enemies", -1)) == 0, "elimination result must report no remaining enemies")
	runtime.stop()
	_expect(not port.external_victory_control and not port.monitor_enemy_stalls, "elimination stop must restore port controls")

	var guidance_port = FakePort.new()
	guidance_port.spawn_budget_snapshot = {"planned_total_hp": 500, "planned_enemy_count": 5}
	var guidance_runtime = EliminationRuntime.new()
	guidance_runtime.start(guidance_port, {"batch_count_min": 1, "batch_count_max": 1})
	guidance_port.battle_tick.emit({"delta_sec": 0.1})
	_expect(guidance_port.elimination_guidance_calls.is_empty(), "five remaining enemies must not enable offscreen guidance")
	guidance_port.enemy_spawned.emit({"enemy_id": 41})
	guidance_port.enemy_died.emit({"enemy_id": 41, "was_killed": true})
	_expect(guidance_port.elimination_guidance_calls == [true], "dropping below five total remaining enemies must enable offscreen guidance once")
	guidance_runtime.stop()
	_expect(guidance_port.elimination_guidance_calls == [true, false], "elimination cleanup must disable offscreen guidance")

	var drift_port = FakePort.new()
	var drift_runtime = EliminationRuntime.new()
	var drift_results: Array = []
	drift_runtime.completed.connect(_completed_collector.bind(drift_results))
	drift_runtime.start(drift_port, {})
	drift_port.battle_tick.emit({"delta_sec": 0.1})
	drift_port.active_enemy_count = 1
	drift_port.enemy_spawned.emit({})
	drift_port.spawn_budget_exhausted.emit({})
	drift_port.battle_tick.emit({"delta_sec": 0.1})
	_expect(drift_results.is_empty(), "registry reconciliation must preserve a genuinely living final enemy")
	drift_port.active_enemy_count = 0
	drift_port.battle_tick.emit({"delta_sec": 0.1})
	_expect(drift_results.size() == 1, "elimination must recover when the final enemy exits without a death signal")
	_expect(drift_results.size() == 1 and int(drift_results[0].get("remaining_enemies", -1)) == 0, "recovered elimination must report zero remaining enemies")
	drift_runtime.stop()

	var deployed_port = FakePort.new()
	deployed_port.spawn_budget_snapshot = {"planned_total_hp": 200, "planned_enemy_count": 2}
	var deployed_runtime = EliminationRuntime.new()
	var deployed_results: Array = []
	deployed_runtime.completed.connect(_completed_collector.bind(deployed_results))
	deployed_runtime.start(deployed_port, {"batch_count_min": 1, "batch_count_max": 1})
	deployed_port.battle_tick.emit({"delta_sec": 0.1})
	deployed_port.active_enemy_count = 2
	deployed_port.enemy_spawned.emit({})
	deployed_port.enemy_spawned.emit({})
	deployed_port.active_enemy_count = 1
	deployed_port.enemy_died.emit({"was_killed": true, "scaled_hp": 100})
	_expect(deployed_results.is_empty(), "elimination must not finish while a deployed enemy is still alive")
	deployed_port.active_enemy_count = 0
	deployed_port.enemy_died.emit({"was_killed": true, "scaled_hp": 100})
	_expect(deployed_results.size() == 1, "elimination must finish when no enemies are queued or actually alive without waiting for the budget signal")
	deployed_runtime.stop()

func _test_survival() -> void:
	var threat_port = FakePort.new()
	threat_port.level_duration_sec = 75.0
	var threat_runtime = SurvivalRuntime.new()
	threat_runtime.start(threat_port, {"threat_step_sec": 15.0})
	_expect(threat_port.spawn_policy.get("mode") == &"uncapped", "survival must be the only uncapped spawn protocol")
	var expected_threat_multipliers := [1.06, 1.12, 1.18, 1.24]
	for expected_multiplier in expected_threat_multipliers:
		threat_port.battle_tick.emit({"delta_sec": 15.0})
		_expect(
			is_equal_approx(threat_port.configured_threat, expected_multiplier),
			"survival threat must increase by six percent per level"
		)
	threat_runtime.stop()

	var port = FakePort.new()
	port.level_duration_sec = 30.0
	var runtime = SurvivalRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"threat_step_sec": 15.0})
	_expect(is_equal_approx(runtime.duration_sec, 30.0), "survival must use the current level duration")
	_expect(is_zero_approx(port.configured_duration), "survival must not override the current level duration")
	port.enemy_died.emit({"was_killed": true, "scaled_hp": 500})
	_expect(port.heals == [5], "survival resolve should heal once per kill event crossing the threshold")
	port.battle_tick.emit({"delta_sec": 29.0})
	_expect(port.configured_threat > 1.0 and results.is_empty(), "survival must raise threat without completing early")
	port.battle_tick.emit({"delta_sec": 1.0})
	port.battle_tick.emit({"delta_sec": 1.0})
	_expect(results.size() == 1, "survival completion must be guarded against repeat ticks")
	_expect(port.stop_spawning_calls == 1 and port.evacuations.size() == 1, "survival completion must stop spawning and evacuate once")
	runtime.stop()
	_expect(is_equal_approx(port.configured_threat, 1.0), "survival stop must reset threat")

func _test_operation() -> void:
	var configured_port = FakePort.new()
	var configured_runtime = OperationRuntime.new()
	var configured_results: Array = []
	configured_runtime.completed.connect(_completed_collector.bind(configured_results))
	configured_runtime.start(configured_port, {"beacon_count": 1, "charge_time_min_sec": 6.0, "charge_time_max_sec": 6.0, "duration_buffer_sec": 5.0})
	_expect(configured_port.spawn_policy.get("mode") == &"soft_capped" and is_equal_approx(float(configured_port.spawn_policy.get("soft_cap_multiplier")), 1.15), "operation must configure its soft HP cap")
	_expect(configured_runtime.total_beacons == 1 and is_equal_approx(configured_port.configured_duration, 11.0), "operation target count and duration buffer must come from protocol parameters")
	configured_port.battle_tick.emit({"delta_sec": 0.1})
	configured_port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 0})
	configured_port.battle_tick.emit({"delta_sec": 6.0})
	_expect(configured_results.size() == 1, "one-beacon operation configuration must complete after one beacon")
	configured_runtime.stop()

	var early_port = FakePort.new()
	var early_runtime = OperationRuntime.new()
	early_runtime.start(early_port, {"charge_time_min_sec": 10.0, "charge_time_max_sec": 14.0, "early_charge_time_sec": 8.0, "early_level_count": 4})
	_expect(is_equal_approx(early_runtime.charge_duration_sec, 8.0) and is_equal_approx(early_port.configured_duration, 28.0), "operation must use its short variant during the first four levels")
	early_runtime.stop()
	var normal_port = FakePort.new()
	normal_port.level_index = 4
	var normal_runtime = OperationRuntime.new()
	normal_runtime.start(normal_port, {"charge_time_min_sec": 10.0, "charge_time_max_sec": 14.0, "early_charge_time_sec": 8.0, "early_level_count": 4})
	_expect(is_equal_approx(normal_runtime.charge_duration_sec, 12.0) and is_equal_approx(normal_port.configured_duration, 36.0), "operation must restore its standard duration from level 5")
	normal_runtime.stop()

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
	_expect(port.spawn_policy_calls.size() == 1, "operation second beacon must retain one shared battle-wide HP cap")
	_expect(port.spawned_beacons.size() == 2 and port.evacuations.size() == 1, "operation must spawn two beacons and evacuate once")
	runtime.stop()

func _test_containment() -> void:
	var configured_port = FakePort.new()
	var configured_runtime = ContainmentRuntime.new()
	configured_runtime.start(configured_port, {"rift_count": 2, "seal_duration_sec": 8.0, "reinforcement_interval_sec": 9.0, "duration_buffer_sec": 5.0, "performance_wave_allowance_per_rift": 2.0})
	_expect(configured_port.spawn_policy.get("mode") == &"soft_capped" and is_equal_approx(float(configured_port.spawn_policy.get("hard_cap_multiplier")), 1.60), "containment must configure its reinforced hard cap")
	_expect(configured_runtime.rift_count == 2 and is_equal_approx(configured_port.configured_duration, 21.0), "containment target count and duration buffer must come from protocol parameters")
	_expect(is_equal_approx(configured_runtime.performance_wave_allowance_per_rift, 2.0), "containment performance allowance must come from protocol parameters")
	configured_runtime.stop()

	var port = FakePort.new()
	var runtime = ContainmentRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"rift_count": 3, "seal_duration_sec": 8.0, "reinforcement_interval_sec": 9.0})
	port.battle_tick.emit({"delta_sec": 0.1})
	_expect(port.spawned_objectives.size() == 3, "containment must spawn three legal rifts")
	_expect(port.spawned_objectives.all(func(item): return item.get("visual_kind") == &"containment"), "containment objectives must request the containment visual profile")
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 20})
	port.battle_tick.emit({"delta_sec": 8.0})
	_expect(is_equal_approx(float(runtime.progress_by_id[1]), 0.35), "containment enemy slowdown must have a 35 percent floor")
	port.battle_tick.emit({"delta_sec": 1.0})
	_expect(port.reinforcement_multipliers.size() == 1 and port.configured_threat > 1.0, "simultaneous containment rifts must merge into one capped reinforcement wave")
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
	var configured_port = FakePort.new()
	configured_port.level_index = 2
	var configured_runtime = ExtractionRuntime.new()
	configured_runtime.start(configured_port, {"early_level_count": 2, "mid_level_count": 5, "survival_duration_early_sec": 11.0, "survival_duration_mid_sec": 22.0, "survival_duration_late_sec": 33.0, "escape_duration_early_sec": 7.0, "escape_duration_mid_sec": 6.0, "escape_duration_late_sec": 5.0})
	_expect(configured_port.spawn_policy.get("mode") == &"soft_capped" and is_equal_approx(float(configured_port.spawn_policy.get("soft_cap_multiplier")), 1.25), "extraction must reserve a capped pursuit allowance")
	_expect(is_equal_approx(configured_runtime.duration_sec, 22.0) and is_equal_approx(configured_runtime.escape_duration_sec, 6.0), "extraction tier boundaries must come from protocol parameters")
	configured_runtime.stop()

	var port = FakePort.new()
	var runtime = ExtractionRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"survival_duration_early_sec": 2.0, "escape_duration_early_sec": 3.0})
	port.battle_tick.emit({"delta_sec": 2.0})
	_expect(runtime.phase == &"extracting" and not port.continuous_spawning, "extraction must stop continuous spawning after holding")
	_expect(port.spawned_objectives.size() == 1 and port.pursuit_wave_calls.size() == 1, "extraction must open one zone and one pursuit wave")
	_expect(port.spawned_objectives[0].get("visual_kind") == &"extraction", "extraction objective must request the extraction visual profile")
	port.battle_tick.emit({"delta_sec": 4.0})
	_expect(runtime.overtime_sec > 0.0 and results.is_empty(), "extraction overtime must not auto-complete")
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 0})
	port.beacon_presence_changed.emit({"beacon_id": 1, "player_inside": true, "enemy_count": 0})
	_expect(results.size() == 1 and float(results[0].get("performance_ratio", 2.0)) >= 0.6, "extraction must complete once with bounded performance")
	_expect(port.completed_beacons == [1], "extraction completion must trigger the target completion animation exactly once")
	runtime.stop()

func _test_reward() -> void:
	var reward_enemy := RewardEnemyScene.instantiate() as BaseEnemy
	var reward_body := reward_enemy.get_node("Body") as Sprite2D
	_expect(is_equal_approx(reward_enemy.movement_speed, 94.5), "reward enemy movement speed must remain 30% below its original 135.0 value")
	_expect(reward_body.texture != null, "reward enemy must bind its texture to the registered Body billboard")
	_expect(reward_body.get_node_or_null("RewardSprite") == null, "reward enemy must not hide its visual in an unregistered child sprite")
	reward_enemy.free()
	var early_port = FakePort.new()
	var early_runtime = RewardRuntime.new()
	early_runtime.start(early_port, {"duration_sec": 45.0, "early_duration_sec": 30.0, "early_level_count": 4})
	_expect(is_equal_approx(early_runtime.duration_sec, 30.0), "reward protocol must use a 30-second timer during the first four levels")
	early_runtime.stop()
	var normal_port = FakePort.new()
	normal_port.level_index = 4
	var normal_runtime = RewardRuntime.new()
	normal_runtime.start(normal_port, {"duration_sec": 45.0, "early_duration_sec": 30.0, "early_level_count": 4})
	_expect(is_equal_approx(normal_runtime.duration_sec, 45.0), "reward protocol must restore its 45-second timer from level 5")
	normal_runtime.stop()

	var port = FakePort.new()
	var runtime = RewardRuntime.new()
	var results: Array = []
	runtime.completed.connect(_completed_collector.bind(results))
	runtime.start(port, {"duration_sec": 5.0, "hp_budget_multiplier": 1.5, "reward_multiplier": 2.5})
	_expect(port.spawn_policy.get("mode") == &"finite" and is_equal_approx(float(port.spawn_policy.get("soft_cap_multiplier")), 2.0), "reward must retain a finite double-HP cap")
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
