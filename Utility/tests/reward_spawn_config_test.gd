extends Node2D

const REWARD_MANAGER_SCRIPT := preload("res://Utility/reward_manager.gd")
const MODULE_DAMAGE_UP := preload("res://Player/Weapons/Modules/damage_up.tscn")

@onready var info_label: Label = $CanvasLayer/InfoLabel

var _manager: BonusManager
var _pass_count: int = 0
var _fail_count: int = 0
var _logs: PackedStringArray = []
var _last_action: String = "Ready"

func _ready() -> void:
	await run_all_tests()
	_render_status()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F5:
			_last_action = "Rerun all tests"
			await run_all_tests()
			_render_status()
		KEY_1:
			_last_action = "Spawn valid reward cache level 0"
			await _manual_spawn_valid_level_zero()
			_render_status()
		KEY_2:
			_last_action = "Spawn malformed reward list"
			await _manual_spawn_malformed_level()
			_render_status()
		KEY_R:
			_last_action = "Reset test manager"
			_reset_manager()
			_render_status()
		_:
			return

func run_all_tests() -> void:
	_reset_counters()
	_reset_manager()
	_test_spawn_data_reward_config_shape()
	_test_direct_module_reward_config()
	await _test_create_loot_box_with_unexpected_input()
	_logs.append("[SUMMARY] pass=%d fail=%d" % [_pass_count, _fail_count])
	for line in _logs:
		print(line)

func _reset_counters() -> void:
	_pass_count = 0
	_fail_count = 0
	_logs.clear()

func _reset_manager() -> void:
	if _manager and is_instance_valid(_manager):
		_manager.queue_free()
	_manager = REWARD_MANAGER_SCRIPT.new() as BonusManager
	add_child(_manager)
	_manager.rebuild_rewards_cache()

func _test_spawn_data_reward_config_shape() -> void:
	_assert_true(SpawnData.level_list.size() > 0, "SpawnData has at least one level config")
	var level_index := 0
	for level_config in SpawnData.level_list:
		if level_config == null:
			_assert_true(true, "Level %d config can be null (skipped safely)" % level_index)
			level_index += 1
			continue
		var typed_level := level_config as LevelSpawnConfig
		_assert_true(typed_level != null, "Level %d is LevelSpawnConfig" % level_index)
		if typed_level == null:
			level_index += 1
			continue
		_assert_true(typed_level.rewards is Array, "Level %d rewards is array" % level_index)
		var reward_idx := 0
		for reward_entry in typed_level.rewards:
			if not (reward_entry is RewardInfo):
				_assert_true(false, "Level %d reward[%d] should be RewardInfo (found invalid)" % [level_index, reward_idx])
			else:
				var reward: RewardInfo = reward_entry
				var has_weapon_reward := reward.item_id.strip_edges() != "" and reward.item_level > 0
				var has_module_reward := reward.module_scene != null
				var has_coin_reward := reward.total_chip_value > 0
				_assert_true(has_weapon_reward or has_module_reward or has_coin_reward,
					"Level %d reward[%d] has at least one reward payload type" % [level_index, reward_idx])
			reward_idx += 1
		level_index += 1

func _test_direct_module_reward_config() -> void:
	var module_reward := RewardInfo.new()
	module_reward.module_scene = MODULE_DAMAGE_UP
	module_reward.module_level = 99
	module_reward.total_chip_value = 1
	_manager.instance_list = [[module_reward]]
	var spawned := _manager.create_loot_box_for_level(0)
	_assert_eq_int(spawned, 1, "Direct module reward spawns one loot box")
	var children := _manager.get_children()
	if children.is_empty():
		_assert_true(false, "Direct module reward test expected one loot box child")
		return
	var loot_box := children[children.size() - 1]
	_assert_true(loot_box.get("module_scene") == MODULE_DAMAGE_UP, "Direct module reward keeps configured module scene")
	_assert_eq_int(int(loot_box.get("module_level")), Module.MAX_LEVEL, "Direct module reward clamps module level")
	loot_box.queue_free()

func _test_create_loot_box_with_unexpected_input() -> void:
	_manager.instance_list = [
		[
			null,
			{"not": "reward_info"},
			_build_coin_reward(15),
			_build_weapon_reward("1", 2),
			_build_module_reward()
		]
	]
	var before_children := _manager.get_child_count()
	var out_of_range_spawned := _manager.create_loot_box_for_level(99)
	_assert_eq_int(out_of_range_spawned, 0, "Out-of-range level index spawns zero loot boxes")
	_assert_eq_int(_manager.get_child_count(), before_children, "Out-of-range level does not add children")

	var spawned := _manager.create_loot_box_for_level(0)
	await get_tree().process_frame
	_assert_eq_int(spawned, 3, "Malformed reward entries are skipped while valid entries spawn")
	_assert_eq_int(_manager.get_child_count(), before_children + 3, "Spawned loot boxes were added to manager")

func _manual_spawn_valid_level_zero() -> void:
	if _manager == null or not is_instance_valid(_manager):
		_reset_manager()
	_manager.rebuild_rewards_cache()
	var spawned := _manager.create_loot_box_for_level(0)
	_logs.append("[MANUAL] spawned from level 0 cache: %d" % spawned)

func _manual_spawn_malformed_level() -> void:
	if _manager == null or not is_instance_valid(_manager):
		_reset_manager()
	_manager.instance_list = [[null, _build_coin_reward(7), {"bad": true}, _build_module_reward()]]
	var spawned := _manager.create_loot_box_for_level(0)
	_logs.append("[MANUAL] spawned from malformed level list: %d" % spawned)

func _build_coin_reward(total_coin: int) -> RewardInfo:
	var reward := RewardInfo.new()
	reward.total_chip_value = total_coin
	return reward

func _build_weapon_reward(item_id: String, item_level: int) -> RewardInfo:
	var reward := RewardInfo.new()
	reward.item_id = item_id
	reward.item_level = item_level
	return reward

func _build_module_reward() -> RewardInfo:
	var reward := RewardInfo.new()
	reward.module_scene = MODULE_DAMAGE_UP
	reward.module_level = 2
	return reward

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		_logs.append("[PASS] %s" % message)
	else:
		_fail_count += 1
		_logs.append("[FAIL] %s" % message)

func _assert_eq_int(actual: int, expected: int, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%d actual=%d)" % [message, expected, actual])

func _render_status() -> void:
	var lines: PackedStringArray = []
	lines.append("Reward Spawn Config Test")
	lines.append("Auto tests run on load.")
	lines.append("Keys: [F5] Rerun  [1] Spawn Valid Level 0  [2] Spawn Malformed  [R] Reset")
	lines.append("Last action: %s" % _last_action)
	lines.append("Results: pass=%d fail=%d" % [_pass_count, _fail_count])
	lines.append("Manager loot box children: %d" % (_manager.get_child_count() if _manager else 0))
	if not _logs.is_empty():
		lines.append("Last log: %s" % _logs[_logs.size() - 1])
	info_label.text = "\n".join(lines)
