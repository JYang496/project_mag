extends Node

signal test_finished(success: bool)

var _failed := false

func _ready() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	if SpawnData.level_list.is_empty():
		SpawnData.load_all_spawn_data(GlobalVariables.SPAWN_PATN)
	_assert_true(not SpawnData.level_list.is_empty(), "SpawnData must be loaded for infinite mode test.")

	var spawner_scene := load("res://Utility/enemy_spawner.tscn") as PackedScene
	_assert_true(spawner_scene != null, "EnemySpawner scene should load.")
	if spawner_scene == null:
		_finish()
		return

	var spawner := spawner_scene.instantiate() as EnemySpawner
	_assert_true(spawner != null, "EnemySpawner instance should be valid.")
	if spawner == null:
		_finish()
		return
	add_child(spawner)
	await get_tree().process_frame

	PhaseManager.current_level = 15
	_assert_true(PhaseManager.current_level > 9, "PhaseManager.current_level should be unbounded and exceed level 9.")

	var single_pool_size := int(spawner.debug_get_runtime_spawn_pool_size_for_level(0))
	var mixed_pool_size := int(spawner.debug_get_runtime_spawn_pool_size_for_level(10))
	_assert_true(mixed_pool_size > single_pool_size, "Infinite mode mixed spawn pool should exceed single-level pool size.")

	var first_level: LevelSpawnConfig = null
	if not SpawnData.level_list.is_empty():
		first_level = SpawnData.level_list[0] as LevelSpawnConfig
	var first_spawn: SpawnInfo = null
	if first_level and not first_level.spawns.is_empty():
		first_spawn = first_level.spawns[0] as SpawnInfo
	_assert_true(first_spawn != null, "A valid SpawnInfo is required for scaling checks.")
	if first_spawn != null:
		var low_stats := spawner.calculate_scaled_enemy_stats(first_spawn, 10, 1, 0)
		var high_stats := spawner.calculate_scaled_enemy_stats(first_spawn, 10, 1, 12)
		_assert_true(int(high_stats.get("hp", 0)) > int(low_stats.get("hp", 0)), "Scaled HP should increase at higher infinite levels.")

	PhaseManager.battle_time = 10
	var budget_low := int(spawner.call("_resolve_batch_budget", 9, 60))
	var budget_high := int(spawner.call("_resolve_batch_budget", 14, 60))
	_assert_true(budget_high > budget_low, "Spawn budget should grow for higher infinite levels.")
	_assert_true(spawner.debug_get_infinite_overflow_level(10) == 1, "Overflow level should start at 1 for level index 10.")

	spawner.queue_free()
	_finish()

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)

func _finish() -> void:
	PhaseManager.current_level = 0
	PhaseManager.battle_time = 0
	test_finished.emit(not _failed)
