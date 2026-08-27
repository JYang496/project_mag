extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PROFILE_PATH := "res://data/spawns/spawn_combat_profile.tres"
const ECONOMY_PATH := "res://data/economy/economy_config.tres"
const CONTAINMENT_PATH := "res://data/battle_contracts/containment.tres"
const EXTRACTION_PATH := "res://data/battle_contracts/extraction.tres"
const OPERATION_PATH := "res://data/battle_contracts/operation.tres"
const REWARD_PATH := "res://data/battle_contracts/reward.tres"
const FINALE_PATH := "res://data/battle_contracts/finale.tres"
const ELIMINATION_PATH := "res://data/battle_contracts/elimination.tres"
const SURVIVAL_PATH := "res://data/battle_contracts/survival.tres"
const FakeContractPort := preload("res://tests/fixtures/combat/fake_battle_contract_combat_port.gd")
const EXPECTED_DURATIONS := [26, 34, 30, 32]
const EXPECTED_NORMAL_DURATIONS := [53, 55, 60, 67, 75, 84]
const EXPECTED_HP := [730, 800, 1000, 1138]
const EXPECTED_DPS := [730.0 / 26.0, 800.0 / 34.0, 1000.0 / 30.0, 1138.0 / 32.0]
const EXPECTED_GOLD := [30, 35, 39, 43]
const EXPECTED_START_TIMES := [
	[1],
	[8, 1],
	[1, 18, 10],
	[1, 7],
]

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile := load(PROFILE_PATH) as SpawnCombatProfile
	var economy := load(ECONOMY_PATH) as EconomyConfig
	_expect(profile != null, "early pacing profile must load")
	_expect(economy != null, "economy config must load")
	if profile != null and economy != null:
		profile.sanitize()
		_expect(profile.levels.size() >= 4, "spawn profile must define the first four levels")
		for level_index in range(mini(profile.levels.size(), 4)):
			_assert_level(profile, economy, level_index)
		for offset in range(mini(EXPECTED_NORMAL_DURATIONS.size(), maxi(profile.levels.size() - 4, 0))):
			var plan := profile.levels[offset + 4] as LevelCombatPlan
			_expect(plan != null and plan.time_out_sec == EXPECTED_NORMAL_DURATIONS[offset], "level %d must retain its standard duration" % (offset + 5))
		_assert_protocol_pacing(economy)
		_assert_spawn_pressure_policy()
		_assert_vanguard_policy(profile)
		_assert_limited_spawn_substitution()
		_assert_progression_profile()
		_assert_final_state_transition()
		_assert_runtime_offer_policy()

	print("FAIL early combat pacing" if _failed else "PASS early combat pacing")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _assert_level(profile: SpawnCombatProfile, economy: EconomyConfig, level_index: int) -> void:
	var plan := profile.levels[level_index] as LevelCombatPlan
	_expect(plan != null, "level %d plan must exist" % (level_index + 1))
	if plan == null:
		return
	_expect(plan.time_out_sec == EXPECTED_DURATIONS[level_index], "level %d duration must match the early pacing curve" % (level_index + 1))
	_expect(plan.target_total_hp == EXPECTED_HP[level_index], "level %d HP budget must match the early pacing curve" % (level_index + 1))
	var actual_dps := float(plan.target_total_hp) / float(plan.time_out_sec)
	_expect(absf(actual_dps - EXPECTED_DPS[level_index]) <= 0.02, "level %d target DPS drifted" % (level_index + 1))

	var gold_plan := economy.get_contract_gold_plan(&"elimination", level_index)
	_expect(int(gold_plan.get("total_gold", -1)) == EXPECTED_GOLD[level_index], "level %d expected total gold changed" % (level_index + 1))

	var actual_start_times: Array[int] = []
	for entry in plan.spawns:
		actual_start_times.append(entry.start_sec if entry != null else -1)
	var expected_start_times: Array = EXPECTED_START_TIMES[level_index]
	_expect(actual_start_times.size() == expected_start_times.size(), "level %d spawn roster size changed" % (level_index + 1))
	for entry_index in range(mini(actual_start_times.size(), expected_start_times.size())):
		_expect(actual_start_times[entry_index] == int(expected_start_times[entry_index]), "level %d spawn timing must remain proportionally staged" % (level_index + 1))

func _assert_protocol_pacing(economy: EconomyConfig) -> void:
	var containment := load(CONTAINMENT_PATH) as BattleContractDefinition
	var extraction := load(EXTRACTION_PATH) as BattleContractDefinition
	var operation := load(OPERATION_PATH) as BattleContractDefinition
	var reward := load(REWARD_PATH) as BattleContractDefinition
	var finale := load(FINALE_PATH) as BattleContractDefinition
	var elimination := load(ELIMINATION_PATH) as BattleContractDefinition
	var survival := load(SURVIVAL_PATH) as BattleContractDefinition
	_expect(containment != null and extraction != null and operation != null and reward != null and finale != null and elimination != null and survival != null, "pacing protocol definitions must load")
	if containment == null or extraction == null or operation == null or reward == null or finale == null or elimination == null or survival == null:
		return
	for level_index in range(4):
		_expect(not BattleContractManager.is_contract_unlocked_for_level(containment, level_index), "containment must stay locked through level 4")
		_expect(not BattleContractManager.is_contract_unlocked_for_level(extraction, level_index), "extraction must stay locked through level 4")
	_expect(BattleContractManager.is_contract_unlocked_for_level(containment, 4), "containment must unlock at level 5")
	_expect(BattleContractManager.is_contract_unlocked_for_level(extraction, 4), "extraction must unlock at level 5")
	_expect(BattleContractManager.get_max_long_form_options_for_level(4) == 1, "levels 5-8 must offer at most one long protocol")
	_expect(BattleContractManager.get_max_long_form_options_for_level(7) == 1, "level 8 must still offer at most one long protocol")
	_expect(BattleContractManager.get_max_long_form_options_for_level(8) == 2, "level 9 onward may offer two long protocols")
	_expect(containment.multiple_long_offer_level_index == 8 and extraction.multiple_long_offer_level_index == 8, "long-protocol pairing threshold must live in protocol resources")
	_expect(is_equal_approx(float(operation.parameters.get("early_charge_time_sec", 0.0)), 8.0), "operation must use eight-second early captures")
	_expect(int(operation.parameters.get("early_level_count", 0)) == 4, "operation early pacing must cover four levels")
	_expect(is_equal_approx(float(reward.parameters.get("early_duration_sec", 0.0)), 30.0), "reward protocol must use a 30-second early timer")
	_expect(int(reward.parameters.get("early_level_count", 0)) == 4, "reward early pacing must cover four levels")
	_expect(finale.contract_id == &"finale" and int(finale.parameters.get("batch_count_min", 0)) == 3 and int(finale.parameters.get("batch_count_max", 0)) == 3, "final protocol must use exactly three escalating formations")
	_expect(is_equal_approx(float(operation.parameters.get("spawn_soft_cap_multiplier", 0.0)), 1.15) and is_equal_approx(float(operation.parameters.get("spawn_hard_cap_multiplier", 0.0)), 1.35), "operation HP caps must live in its protocol resource")
	_expect(is_equal_approx(float(containment.parameters.get("spawn_soft_cap_multiplier", 0.0)), 1.35) and is_equal_approx(float(containment.parameters.get("spawn_hard_cap_multiplier", 0.0)), 1.60), "containment HP caps must reserve bounded reinforcement room")
	_expect(is_equal_approx(float(extraction.parameters.get("spawn_soft_cap_multiplier", 0.0)), 1.25) and is_equal_approx(float(extraction.parameters.get("spawn_hard_cap_multiplier", 0.0)), 1.45), "extraction HP caps must reserve bounded pursuit room")
	_expect(is_equal_approx(float(reward.parameters.get("spawn_soft_cap_multiplier", 0.0)), 2.0) and is_equal_approx(float(reward.parameters.get("spawn_hard_cap_multiplier", 0.0)), 2.15), "reward must retain a finite double-HP envelope")
	_expect(is_equal_approx(float(elimination.parameters.get("spawn_soft_cap_multiplier", 0.0)), 1.0) and is_equal_approx(float(finale.parameters.get("spawn_hard_cap_multiplier", 0.0)), 1.25), "elimination and finale must publish finite safety caps")
	_expect(str(survival.parameters.get("spawn_policy", "")) == "uncapped", "survival must be explicitly marked as the uncapped protocol")
	_expect(economy.get_early_standard_draft_count() == 3, "three early weapon-focused drafts plus the starter weapon must preserve the four-weapon opening")
	var profile := load(PROFILE_PATH) as SpawnCombatProfile
	_expect(profile != null and profile.get_elite_batch_limit(7) == 1 and profile.get_elite_batch_limit(8) == 2, "elite batch limits must follow spawn profile configuration")

func _assert_spawn_pressure_policy() -> void:
	var spawner := EnemySpawner.new()
	spawner.configure_contract_continuous_spawning(true)
	spawner.configure_contract_spawn_policy(&"soft_capped", 1.15, 1.35)
	spawner._contract_base_target_hp = 1000
	spawner._refresh_contract_spawn_caps()
	spawner._spawned_total_hp = 999
	var normal := spawner.get_contract_spawn_pressure_snapshot()
	_expect(int(normal.get("soft_cap_hp", 0)) == 1150 and int(normal.get("hard_cap_hp", 0)) == 1350, "operation cap multipliers must resolve against base level HP")
	_expect((normal.get("throttle", {}) as Dictionary).get("tier") == &"normal", "spawns below the soft cap must retain normal pacing")
	spawner._spawned_total_hp = 1150
	var first_tier := spawner.get_contract_spawn_pressure_snapshot().get("throttle", {}) as Dictionary
	_expect(first_tier.get("tier") == &"throttled_25" and int(first_tier.get("interval_sec", 0)) == 4, "soft-cap crossing must reduce releases to a four-second cadence")
	spawner._spawned_total_hp = 1265
	var second_tier := spawner.get_contract_spawn_pressure_snapshot().get("throttle", {}) as Dictionary
	_expect(second_tier.get("tier") == &"throttled_10" and int(second_tier.get("interval_sec", 0)) == 8, "ten-percent overflow must reduce releases to an eight-second cadence")
	spawner._spawned_total_hp = 1350
	_expect((spawner.get_contract_spawn_pressure_snapshot().get("throttle", {}) as Dictionary).get("tier") == &"hard_cap", "hard cap must stop further budget release")
	_expect(spawner.spawn_contract_pursuit_wave(6, 10) == 0, "extraction pursuit waves must not bypass the protocol hard cap")

	spawner._init_spawn_budget_runtime()
	spawner._planned_target_total_hp = 1000
	spawner._available_hp_budget = 0.0
	spawner._spawned_total_hp = 1150
	PhaseManager.battle_time = 100
	_expect(spawner._release_hp_budget_for_current_tick(0, 30), "soft-cap tier must release one throttled budget slice when its interval opens")
	spawner._available_hp_budget = 0.0
	PhaseManager.battle_time = 101
	_expect(not spawner._release_hp_budget_for_current_tick(0, 30) and is_zero_approx(spawner._available_hp_budget), "soft-cap tier must suppress releases between four-second intervals")
	PhaseManager.battle_time = 104
	_expect(spawner._release_hp_budget_for_current_tick(0, 30), "soft-cap tier must reopen after four seconds")

	spawner._spawned_total_hp = 1000
	spawner._spawn_budget_stopped = true
	spawner._update_spawn_budget_stop_state()
	_expect(spawner._planned_target_total_hp == 1000, "continuous spawning must never double the planned HP budget")
	_expect(not spawner._spawn_budget_stopped, "soft-capped operation must continue at throttled pacing below its hard cap")
	spawner.configure_contract_spawn_policy(&"uncapped", 0.0, 0.0)
	spawner._spawn_budget_stopped = true
	spawner._update_spawn_budget_stop_state()
	_expect(spawner._planned_target_total_hp == 1000 and not spawner._spawn_budget_stopped, "uncapped survival must continue without mutating its base HP target")

	spawner.configure_contract_spawn_policy(&"soft_capped", 1.15, 1.35)
	spawner._contract_base_target_hp = 1000
	spawner._refresh_contract_spawn_caps()
	spawner._planned_target_total_hp = 1000
	spawner._spawned_total_hp = 1300
	spawner._available_hp_budget = 0.0
	spawner.release_contract_reinforcement_budget(2.0)
	_expect(spawner._available_hp_budget > 0.0 and spawner._available_hp_budget <= 50.0, "containment reinforcement budget must be throttled and clipped to remaining hard-cap room")
	spawner.reset_contract_configuration()
	var reset_snapshot := spawner.get_contract_spawn_pressure_snapshot()
	_expect(reset_snapshot.get("mode") == &"finite" and int(reset_snapshot.get("soft_cap_hp", -1)) == 0, "spawn pressure policy must reset between battles")
	spawner.free()
	PhaseManager.battle_time = 0

func _assert_vanguard_policy(profile: SpawnCombatProfile) -> void:
	var spawner := EnemySpawner.new()
	spawner._runtime_spawn_states = spawner._build_runtime_states(profile.get_level_spawns(1))
	spawner._planned_target_total_hp = profile.get_target_total_hp(1)
	var candidates := spawner._get_vanguard_candidates()
	_expect(candidates.size() == 1, "level 2 vanguard must use only the earliest available enemy pool")
	if not candidates.is_empty():
		var entry := spawner._get_state_entry(candidates[0])
		_expect(entry != null and entry.start_sec == 1, "vanguard must not reveal delayed enemy types early")
	_expect(spawner._deploy_battle_vanguard(0) == 0, "level 1 must not deploy a vanguard")
	var budget_before := spawner._spawned_total_hp
	var deployed_hp := spawner._deploy_battle_vanguard(1)
	_expect(deployed_hp >= ceili(float(spawner._planned_target_total_hp) * 0.10), "level 2 vanguard must reach ten percent of total HP")
	_expect(spawner._spawned_total_hp == budget_before, "vanguard HP must remain outside the normal spawn budget")
	spawner.free()

func _assert_limited_spawn_substitution() -> void:
	var spawner := EnemySpawner.new()
	var substitute_entry := EnemySpawnEntry.new()
	substitute_entry.enemy_scene_path = "res://Npc/enemy/scenes/enemy_rolling_ball.tscn"
	var substitute_state: Dictionary = {"id": 2, "entry": substitute_entry, "alive": 0, "cooldown": 0}
	spawner._runtime_spawn_states = [substitute_state]
	spawner._contract_spawn_plan = [1]
	spawner._contract_spawn_plan_cursor = 0
	spawner._planned_target_total_hp = 100
	spawner._spawned_total_hp = 0
	spawner._combat_budget_active = true
	var selected := spawner._select_contract_spawn_candidate([substitute_state], {}, 0, 0, 0)
	_expect(int(selected.get("id", -1)) == 2, "a planned enemy blocked by its alive cap must be replaced by an eligible type")
	_expect(spawner._contract_spawn_plan[0] == 2, "spawn substitution must update the finite plan before advancing its cursor")
	spawner.free()

func _assert_progression_profile() -> void:
	var progression: Resource = PhaseManager.get_progression_profile()
	_expect(progression != null, "run progression profile must load")
	if progression == null:
		return
	_expect(progression.get_settlement_type_for_completed_level(0) == &"quick", "level 1 must use quick settlement")
	_expect(progression.get_settlement_type_for_completed_level(2) == &"chapter", "level 3 must close chapter one")
	_expect(progression.get_settlement_type_for_completed_level(5) == &"chapter", "level 6 must close chapter two")
	_expect(progression.get_settlement_type_for_completed_level(8) == &"chapter", "level 9 must close chapter three")
	_expect(progression.get_settlement_type_for_completed_level(9) == &"final", "level 10 must close the main run")
	_expect(progression.get_active_cell_ids_for_level(0) == PackedInt32Array([5, 6]), "chapter one must use the compact board")
	_expect(progression.get_active_cell_ids_for_level(3) == PackedInt32Array([4, 5, 6, 8]), "chapter two must unlock its board cross")
	_expect(progression.get_active_cell_ids_for_level(9).size() == 9, "final protocol must unlock the full board")

func _assert_final_state_transition() -> void:
	PhaseManager.reset_runtime_state()
	PhaseManager.current_level = 10
	PhaseManager.phase = PhaseManager.SETTLEMENT
	PhaseManager.enter_run_complete()
	_expect(PhaseManager.current_state() == PhaseManager.RUN_COMPLETE, "completed level 10 must enter run-complete state")
	PhaseManager.continue_into_endless()
	_expect(PhaseManager.current_state() == PhaseManager.REST, "overload choice must return to a full rest phase")
	_expect(PhaseManager.endless_mode, "overload choice must enable endless scaling explicitly")
	_expect(PhaseManager.is_full_shop_open(), "first overload entry must expose the full rest shop")
	PhaseManager.reset_runtime_state()

func _assert_runtime_offer_policy() -> void:
	var port := FakeContractPort.new()
	BattleContractManager.reset_runtime_state()
	BattleContractManager.bind_combat_port(port)
	PhaseManager.current_level = 0
	_expect(BattleContractManager.request_fixed_offer(&"elimination"), "early flow must support a fixed elimination offer")
	_expect(BattleContractManager.state == BattleContractManager.SELECTED, "fixed early offer must be selected without opening the protocol UI")
	BattleContractManager.reset_runtime_state()
	PhaseManager.current_level = 9
	_expect(BattleContractManager.request_fixed_offer(&"finale"), "level 10 must support its fixed final protocol")
	_expect(BattleContractManager.selected_contract != null and BattleContractManager.selected_contract.contract_id == &"finale", "fixed final offer must select the final protocol")
	BattleContractManager.reset_runtime_state()
	PhaseManager.current_level = 0
	for iteration in range(16):
		var early_options := BattleContractManager.request_offer()
		var early_long_count := early_options.filter(func(option): return option.long_form).size()
		_expect(early_long_count == 0, "first four levels must never offer a long protocol")
	PhaseManager.current_level = 4
	var saw_long_protocol := false
	for iteration in range(64):
		var mid_options := BattleContractManager.request_offer()
		var mid_long_count := mid_options.filter(func(option): return option.long_form).size()
		_expect(mid_long_count <= 1, "levels 5-8 must never offer two long protocols together")
		saw_long_protocol = saw_long_protocol or mid_long_count == 1
	_expect(saw_long_protocol, "long protocols must enter the offer pool at level 5")
	BattleContractManager.unbind_combat_port()
	BattleContractManager.reset_runtime_state()
	PhaseManager.reset_runtime_state()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
