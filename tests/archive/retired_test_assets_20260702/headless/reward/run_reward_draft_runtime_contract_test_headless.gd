extends Node

const REWARD_MANAGER_SCENE := preload("res://World/rewards/reward_manager.tscn")

var _reward_manager: BonusManager
var _route: RunRouteDefinition

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_setup()
	if not _assert_stage_rules_and_early_options():
		return
	if not _assert_fallback_economy_boundary():
		return
	if not _assert_pending_restore_contract():
		return
	if not _assert_non_standard_sources_do_not_advance_count():
		return
	if not await _assert_standard_completion_uses_draft_without_ground_drop():
		return
	_cleanup()
	print("RewardDraftRuntimeContractTest: PASS")
	get_tree().quit(0)

func _setup() -> void:
	get_tree().current_scene = self
	DataHandler.prepare_world_data()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	RewardDraftRuntime.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	RunRouteManager.reset_runtime_state()
	RunRouteManager.reload_route_definitions()
	var economy := EconomyConfig.new()
	economy.reward_module_options_enabled = true
	economy.reward_weapon_option_chance = 0.6
	economy.reward_economy_option_chance = 0.15
	economy.early_standard_draft_count = 3
	economy.early_weapon_progress_slot_enabled = true
	economy.early_module_option_chances = PackedFloat32Array([0.0, 0.2, -1.0])
	economy.early_economy_option_enabled = false
	economy.early_allow_fallback_economy = true
	GlobalVariables.economy_data = economy
	_reward_manager = REWARD_MANAGER_SCENE.instantiate() as BonusManager
	add_child(_reward_manager)
	_route = RunRouteManager.get_route_for_level(0)

func _assert_stage_rules_and_early_options() -> bool:
	RewardDraftRuntime.standard_draft_count = 0
	RewardDraftRuntime.clear_pending_standard_draft()
	var draft_one_rules := RewardDraftRuntime.get_standard_draft_stage_rules(GlobalVariables.economy_data)
	if not bool(draft_one_rules.get("reserve_weapon_progress_slot", false)):
		return _fail(1, "Draft 1 should reserve a weapon-progress slot.")
	if float(draft_one_rules.get("module_option_chance", -1.0)) != 0.0:
		return _fail(2, "Draft 1 module chance should be 0%.")
	if bool(draft_one_rules.get("normal_economy_enabled", true)):
		return _fail(3, "Early drafts should disable normal economy options.")
	var first_options := _reward_manager.build_standard_battle_draft_options(0, _route, 3)
	if first_options.size() != 3:
		return _fail(4, "Draft 1 should build three options.")
	if not _has_weapon_progress_reward(first_options):
		return _fail(5, "Draft 1 should include weapon-progress.")
	if _has_module_reward(first_options):
		return _fail(6, "Draft 1 should not include module rewards.")
	if _has_normal_economy_reward(first_options):
		return _fail(7, "Draft 1 should not include normal economy rewards.")
	if _has_fallback_economy_reward(first_options):
		return _fail(8, "Draft 1 should not fallback to economy while weapon candidates exist.")

	RewardDraftRuntime.standard_draft_count = 1
	RewardDraftRuntime.clear_pending_standard_draft()
	var draft_two_rules := RewardDraftRuntime.get_standard_draft_stage_rules(GlobalVariables.economy_data)
	if absf(float(draft_two_rules.get("module_option_chance", 0.0)) - 0.2) > 0.0001:
		return _fail(9, "Draft 2 module chance should be 20%.")

	RewardDraftRuntime.standard_draft_count = 2
	RewardDraftRuntime.clear_pending_standard_draft()
	var draft_three_rules := RewardDraftRuntime.get_standard_draft_stage_rules(GlobalVariables.economy_data)
	if absf(float(draft_three_rules.get("module_option_chance", 0.0)) - 0.4) > 0.0001:
		return _fail(10, "Draft 3 should use long-term module chance.")

	RewardDraftRuntime.standard_draft_count = 3
	RewardDraftRuntime.clear_pending_standard_draft()
	var draft_four_rules := RewardDraftRuntime.get_standard_draft_stage_rules(GlobalVariables.economy_data)
	if bool(draft_four_rules.get("reserve_weapon_progress_slot", true)):
		return _fail(11, "Draft 4 should not reserve a fixed weapon-progress slot.")
	if not bool(draft_four_rules.get("normal_economy_enabled", false)):
		return _fail(12, "Draft 4 should return to normal economy weights.")
	return true

func _assert_fallback_economy_boundary() -> bool:
	RewardDraftRuntime.standard_draft_count = 0
	RewardDraftRuntime.clear_pending_standard_draft()
	var normal_options := _reward_manager.build_standard_battle_draft_options(0, _route, 6)
	if _has_fallback_economy_reward(normal_options):
		return _fail(13, "Fallback economy should not appear while weapon/module candidates can fill the draft.")
	var original_weapon_list := GlobalVariables.weapon_list
	var original_module_enabled := GlobalVariables.economy_data.reward_module_options_enabled
	GlobalVariables.weapon_list = {"hidden_fixture": _make_hidden_weapon_definition()}
	GlobalVariables.economy_data.reward_module_options_enabled = false
	var empty_pool_options := _reward_manager.build_standard_battle_draft_options(0, _route, 3)
	GlobalVariables.weapon_list = original_weapon_list
	GlobalVariables.economy_data.reward_module_options_enabled = original_module_enabled
	if not _has_fallback_economy_reward(empty_pool_options):
		return _fail(14, "Fallback economy should appear when weapon/module candidates cannot fill options.")
	if _has_normal_economy_reward(empty_pool_options):
		return _fail(15, "Empty-pool early fallback should not be counted as normal economy.")
	return true

func _assert_pending_restore_contract() -> bool:
	RewardDraftRuntime.standard_draft_count = 0
	RewardDraftRuntime.clear_pending_standard_draft()
	var options := _reward_manager.build_standard_battle_draft_options(0, _route, 3)
	RewardDraftRuntime.set_pending_standard_draft(options, {"draft_index": 1, "level_index": 0, "route_id": "normal"})
	var before_keys := _reward_keys(RewardDraftRuntime.get_pending_standard_draft_options())
	seed(99137)
	var after_keys := _reward_keys(RewardDraftRuntime.get_pending_standard_draft_options())
	if before_keys != after_keys:
		return _fail(16, "Pending draft restore should not reroll options.")
	var snapshot := RewardDraftRuntime.build_battle_rollback_snapshot()
	RewardDraftRuntime.record_standard_draft_consumed()
	if int(RewardDraftRuntime.standard_draft_count) != 1:
		return _fail(17, "Draft count should increment when pending draft is consumed.")
	RewardDraftRuntime.restore_battle_rollback_snapshot(snapshot)
	if _reward_keys(RewardDraftRuntime.get_pending_standard_draft_options()) != before_keys:
		return _fail(18, "Battle rollback should restore pending options.")
	RewardDraftRuntime.restore_battle_rollback_snapshot({
		"standard_draft_count": 0,
		"pending_options": [{
			"kind": str(RewardInfo.KIND_STANDARD),
			"module_path": "res://missing/reward_module.tscn",
			"module_level": 1,
			"rarity": "rare",
			"reward_key": "module:missing",
		}],
		"pending_context": {"draft_index": 1},
		"pending_draft_index": 1,
		"pending_consumed_recorded": false,
	})
	var restored_invalid := RewardDraftRuntime.get_pending_standard_draft_options()
	if restored_invalid.size() != 1 or not _has_fallback_economy_reward(restored_invalid):
		return _fail(19, "Invalid pending option should convert only that option to fallback economy.")
	RewardDraftRuntime.clear_pending_standard_draft()
	return true

func _assert_non_standard_sources_do_not_advance_count() -> bool:
	RewardDraftRuntime.reset_runtime_state()
	PhaseManager.enter_battle()
	TaskRewardManager.notify_objective_completed("DraftRuntimeContractCell")
	if int(RewardDraftRuntime.standard_draft_count) != 0:
		return _fail(20, "Task rewards should not advance standard draft count.")
	PhaseManager.phase = PhaseManager.PREPARE
	var bonus_route := RunRouteManager.get_route_for_level(0)
	_reward_manager.build_reward_selection_options(0, bonus_route, 3)
	if int(RewardDraftRuntime.standard_draft_count) != 0:
		return _fail(21, "Bonus/generic reward selection should not advance standard draft count.")
	_reward_manager.build_special_ground_drop_rewards(0, bonus_route)
	if int(RewardDraftRuntime.standard_draft_count) != 0:
		return _fail(22, "Special ground-drop builders should not advance standard draft count.")
	TaskRewardManager.reset_runtime_state()
	return true

func _assert_standard_completion_uses_draft_without_ground_drop() -> bool:
	RewardDraftRuntime.reset_runtime_state()
	PhaseManager.phase = PhaseManager.BATTLE
	PhaseManager.current_level = 0
	_reward_manager.call("_on_phase_changed", PhaseManager.BATTLE)
	PhaseManager.current_level = 1
	PhaseManager.phase = PhaseManager.PREPARE
	_reward_manager.call("_on_phase_changed", PhaseManager.PREPARE)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if int(RewardDraftRuntime.standard_draft_count) != 1:
		return _fail(23, "Standard battle completion should consume one standard draft.")
	for node in get_tree().get_nodes_in_group(&"unclaimed_battle_rewards"):
		if node and is_instance_valid(node):
			return _fail(24, "Standard battle completion should not spawn generic ground drops.")
	return true

func _has_weapon_progress_reward(options: Array[RewardInfo]) -> bool:
	for reward in options:
		if reward == null:
			continue
		if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
			return true
		if reward.item_id.strip_edges() != "":
			return true
	return false

func _has_module_reward(options: Array[RewardInfo]) -> bool:
	for reward in options:
		if reward != null and reward.module_scene != null:
			return true
	return false

func _has_normal_economy_reward(options: Array[RewardInfo]) -> bool:
	for reward in options:
		if reward != null and str(reward.reward_key_override).begins_with("economy:"):
			return true
	return false

func _has_fallback_economy_reward(options: Array[RewardInfo]) -> bool:
	for reward in options:
		if reward != null and str(reward.reward_key_override).begins_with("fallback_economy:"):
			return true
	return false

func _reward_keys(options: Array[RewardInfo]) -> PackedStringArray:
	var keys := PackedStringArray()
	for reward in options:
		keys.append(_reward_key(reward))
	return keys

func _reward_key(reward: RewardInfo) -> String:
	if reward == null:
		return "null"
	if reward.reward_key_override.strip_edges() != "":
		return reward.reward_key_override
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return "upgrade:%s" % reward.target_weapon_id
	if reward.item_id.strip_edges() != "":
		return "weapon:%s" % reward.item_id.strip_edges()
	if reward.module_scene != null:
		return "module:%s" % str(reward.module_scene.resource_path)
	return "reward:%s" % str(reward)

func _make_hidden_weapon_definition() -> WeaponDefinition:
	var definition := WeaponDefinition.new()
	definition.weapon_id = "hidden_fixture"
	definition.is_hidden = true
	definition.drop_weight = 0.0
	return definition

func _cleanup() -> void:
	RewardDraftRuntime.reset_runtime_state()
	TaskRewardManager.reset_runtime_state()
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	GlobalVariables.economy_data = null

func _fail(code: int, message: String) -> bool:
	push_error("RewardDraftRuntimeContractTest: %s" % message)
	_cleanup()
	get_tree().quit(code)
	return false
