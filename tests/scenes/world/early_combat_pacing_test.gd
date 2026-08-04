extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PROFILE_PATH := "res://data/spawns/spawn_combat_profile.tres"
const ECONOMY_PATH := "res://data/economy/economy_config.tres"
const CONTAINMENT_PATH := "res://data/battle_contracts/containment.tres"
const EXTRACTION_PATH := "res://data/battle_contracts/extraction.tres"
const OPERATION_PATH := "res://data/battle_contracts/operation.tres"
const REWARD_PATH := "res://data/battle_contracts/reward.tres"
const FakeContractPort := preload("res://tests/fixtures/combat/fake_battle_contract_combat_port.gd")
const EXPECTED_DURATIONS := [26, 28, 30, 32]
const EXPECTED_NORMAL_DURATIONS := [53, 55, 60, 67, 75, 84]
const EXPECTED_HP := [260, 373, 600, 738]
const ORIGINAL_DPS := [10.0, 720.0 / 54.0, 20.0, 1200.0 / 52.0]
const EXPECTED_GOLD := [30, 35, 39, 43]
const EXPECTED_START_TIMES := [
	[1],
	[5, 1],
	[1, 6, 14],
	[1, 7, 17],
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
		_assert_runtime_offer_policy()

	print("FAIL early combat pacing" if _failed else "PASS early combat pacing")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _assert_level(profile: SpawnCombatProfile, economy: EconomyConfig, level_index: int) -> void:
	var plan := profile.levels[level_index] as LevelCombatPlan
	_expect(plan != null, "level %d plan must exist" % (level_index + 1))
	if plan == null:
		return
	_expect(plan.time_out_sec == EXPECTED_DURATIONS[level_index], "level %d duration must match the early pacing curve" % (level_index + 1))
	_expect(plan.target_total_hp == EXPECTED_HP[level_index], "level %d HP budget must preserve target DPS" % (level_index + 1))
	var actual_dps := float(plan.target_total_hp) / float(plan.time_out_sec)
	_expect(absf(actual_dps - ORIGINAL_DPS[level_index]) <= 0.02, "level %d target DPS drifted" % (level_index + 1))

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
	_expect(containment != null and extraction != null and operation != null and reward != null, "early pacing protocol definitions must load")
	if containment == null or extraction == null or operation == null or reward == null:
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
	_expect(economy.get_early_standard_draft_count() == 3, "three early weapon-focused drafts plus the starter weapon must preserve the four-weapon opening")
	var profile := load(PROFILE_PATH) as SpawnCombatProfile
	_expect(profile != null and profile.get_elite_batch_limit(7) == 1 and profile.get_elite_batch_limit(8) == 2, "elite batch limits must follow spawn profile configuration")

func _assert_runtime_offer_policy() -> void:
	var port := FakeContractPort.new()
	BattleContractManager.reset_runtime_state()
	BattleContractManager.bind_combat_port(port)
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
