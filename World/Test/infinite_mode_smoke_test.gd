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

	var first_level: LevelCombatPlan = null
	if not SpawnData.level_list.is_empty():
		first_level = SpawnData.level_list[0] as LevelCombatPlan
	var first_spawn: EnemySpawnEntry = null
	if first_level and not first_level.spawns.is_empty():
		first_spawn = first_level.spawns[0] as EnemySpawnEntry
	_assert_true(first_spawn != null, "A valid EnemySpawnEntry is required for scaling checks.")
	if first_spawn != null:
		var low_stats := spawner.calculate_scaled_enemy_stats(10, 1, 0)
		var high_stats := spawner.calculate_scaled_enemy_stats(10, 1, 12)
		_assert_true(int(high_stats.get("hp", 0)) > int(low_stats.get("hp", 0)), "Scaled HP should increase at higher infinite levels.")

	PhaseManager.battle_time = 10
	spawner.call("_prepare_level_combat_budget", 9, 60)
	var budget_low := float(spawner.call("_resolve_batch_hp_budget", 9, 60))
	spawner.call("_prepare_level_combat_budget", 14, 60)
	var budget_high := float(spawner.call("_resolve_batch_hp_budget", 14, 60))
	_assert_true(budget_high > budget_low, "Spawn HP budget should grow for higher infinite levels.")
	_assert_true(int(spawner.get("_budget_release_duration_sec")) == 48, "Spawn HP budget should release by 80 percent of effective timeout.")
	var target_hp := int(spawner.get("_planned_target_total_hp"))
	spawner.set("_spawned_total_hp", maxi(target_hp - 100, 0))
	spawner.set("_available_hp_budget", 0.0)
	PhaseManager.battle_time = 48
	spawner.call("_release_hp_budget_for_current_tick", 14, 60)
	_assert_true(float(spawner.get("_available_hp_budget")) >= 100.0, "Remaining HP budget should be released at the 80 percent mark.")
	_assert_true(bool(spawner.get("_budget_release_finished")), "Budget release should be marked finished after the 80 percent catch-up.")
	_assert_true(not bool(spawner.get("_spawn_budget_stopped")), "Spawn budget should keep spawning while spawned HP is below target.")
	spawner.set("_spawned_total_hp", target_hp)
	spawner.call("_update_spawn_budget_stop_state")
	_assert_true(bool(spawner.get("_spawn_budget_stopped")), "Spawn budget should stop once spawned HP reaches target.")
	_assert_true(bool(spawner.call("_should_end_after_spawn_budget_stopped")), "Battle can end after spawn budget stops and enemies are cleared.")
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
