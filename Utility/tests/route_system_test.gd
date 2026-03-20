extends Node2D

const REWARD_MANAGER_SCRIPT := preload("res://Utility/reward_manager.gd")
const ENEMY_SPAWNER_SCRIPT := preload("res://Utility/enemy_spawner.gd")

@onready var info_label: Label = $CanvasLayer/InfoLabel

var _manager: BonusManager
var _spawner: EnemySpawner
var _pass_count := 0
var _fail_count := 0
var _logs: PackedStringArray = []
var _last_action := "Ready"

func _ready() -> void:
	await run_all_tests()
	_render_status()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F5:
		_last_action = "Rerun all tests"
		await run_all_tests()
		_render_status()

func run_all_tests() -> void:
	_reset_counters()
	_prepare_context()
	_test_normal_route_preserves_defaults()
	_test_bonus_route_skips_battle_and_offers_rewards()
	_test_difficult_route_increases_challenge_and_rewards()
	_logs.append("[SUMMARY] pass=%d fail=%d" % [_pass_count, _fail_count])
	for line in _logs:
		print(line)

func _prepare_context() -> void:
	if _manager and is_instance_valid(_manager):
		_manager.queue_free()
	if _spawner and is_instance_valid(_spawner):
		_spawner.queue_free()
	_manager = REWARD_MANAGER_SCRIPT.new() as BonusManager
	_spawner = ENEMY_SPAWNER_SCRIPT.new() as EnemySpawner
	add_child(_manager)
	add_child(_spawner)
	var sample_reward := RewardInfo.new()
	sample_reward.total_chip_value = 10
	sample_reward.item_id = "1"
	sample_reward.item_level = 1
	_manager.instance_list = [[sample_reward]]
	RunRouteManager.reset_runtime_state()

func _test_normal_route_preserves_defaults() -> void:
	RunRouteManager.set_route_for_level(0, "normal")
	var adjusted_rewards := _manager.get_adjusted_rewards_for_level(0)
	_assert_true(not adjusted_rewards.is_empty(), "Normal route has rewards")
	if adjusted_rewards.is_empty():
		return
	var reward := adjusted_rewards[0]
	_assert_eq_int(reward.total_chip_value, 10, "Normal route keeps chip reward unchanged")
	_assert_eq_int(reward.item_level, 1, "Normal route keeps item level unchanged")
	var spawn_info := SpawnInfo.new()
	spawn_info.hp = 10
	spawn_info.damage = 4
	spawn_info.hp_growth_per_level = 0.0
	spawn_info.damage_growth_per_level = 0.0
	var stats := _spawner.calculate_scaled_enemy_stats(spawn_info, 10, 4, 0)
	_assert_eq_int(int(stats.get("hp", -1)), 10, "Normal route keeps enemy HP unchanged")
	_assert_eq_int(int(stats.get("damage", -1)), 4, "Normal route keeps enemy damage unchanged")
	_assert_eq_int(_spawner.get_effective_time_out(30, 0), 30, "Normal route keeps timeout unchanged")

func _test_bonus_route_skips_battle_and_offers_rewards() -> void:
	RunRouteManager.set_route_for_level(0, "bonus")
	_assert_true(not RunRouteManager.should_start_battle_for_level(0), "Bonus route disables battle")
	_assert_true(not RunRouteManager.should_spawn_prepare_loot_for_level(0), "Bonus route skips prepare loot drops")
	var options := _manager.build_reward_selection_options(0)
	_assert_true(options.size() >= 1, "Bonus route builds at least one reward option")

func _test_difficult_route_increases_challenge_and_rewards() -> void:
	RunRouteManager.set_route_for_level(0, "difficult")
	var adjusted_rewards := _manager.get_adjusted_rewards_for_level(0)
	_assert_true(not adjusted_rewards.is_empty(), "Difficult route has adjusted rewards")
	if adjusted_rewards.is_empty():
		return
	var reward := adjusted_rewards[0]
	_assert_true(reward.total_chip_value > 10, "Difficult route increases chip reward")
	_assert_true(reward.item_level > 1, "Difficult route increases item level")
	var spawn_info := SpawnInfo.new()
	spawn_info.hp = 10
	spawn_info.damage = 4
	spawn_info.hp_growth_per_level = 0.0
	spawn_info.damage_growth_per_level = 0.0
	var stats := _spawner.calculate_scaled_enemy_stats(spawn_info, 10, 4, 0)
	_assert_true(int(stats.get("hp", 0)) > 10, "Difficult route increases enemy HP")
	_assert_true(int(stats.get("damage", 0)) > 4, "Difficult route increases enemy damage")
	_assert_true(_spawner.get_effective_time_out(30, 0) < 30, "Difficult route tightens battle timeout")

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		_logs.append("[PASS] %s" % message)
	else:
		_fail_count += 1
		_logs.append("[FAIL] %s" % message)

func _assert_eq_int(actual: int, expected: int, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%d actual=%d)" % [message, expected, actual])

func _reset_counters() -> void:
	_pass_count = 0
	_fail_count = 0
	_logs.clear()

func _render_status() -> void:
	var lines: PackedStringArray = []
	lines.append("Route System Test")
	lines.append("Auto tests run on load. [F5] rerun")
	lines.append("Last action: %s" % _last_action)
	lines.append("Results: pass=%d fail=%d" % [_pass_count, _fail_count])
	if not _logs.is_empty():
		lines.append("Last log: %s" % _logs[_logs.size() - 1])
	info_label.text = "\n".join(lines)
