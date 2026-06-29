extends Node

func _ready() -> void:
	_run_and_quit()

func _run_and_quit() -> void:
	var ok := await _run()
	get_tree().quit(0 if ok else 1)

func _run() -> bool:
	DataHandler.load_economy_data()
	SpawnData.load_all_spawn_data(GlobalVariables.SPAWN_PATN)
	var spawner_scene := load("res://World/spawn/enemy_spawner.tscn") as PackedScene
	if spawner_scene == null:
		push_error("KillGoldDropProbe: failed to load enemy_spawner.tscn")
		return false
	var spawner := spawner_scene.instantiate() as EnemySpawner
	if spawner == null:
		push_error("KillGoldDropProbe: failed to instantiate EnemySpawner")
		return false
	add_child(spawner)
	await get_tree().process_frame
	var level_index := 0
	var enemy_hp := 10
	var enemy_count := 50
	var trial_count := 600
	var total_ratio := 0.0
	var zero_count := 0
	var positive_count := 0
	var mock_enemy := Node.new()
	mock_enemy.set_meta("_spawn_budget_scaled_hp", enemy_hp)
	add_child(mock_enemy)
	for _trial in range(trial_count):
		PhaseManager.current_level = level_index
		spawner.call("_start_kill_gold_budget", level_index, 60)
		var trial_gold := 0
		for _i in range(enemy_count):
			var gold := spawner.roll_enemy_kill_gold(mock_enemy)
			if gold > 0:
				positive_count += 1
				trial_gold += gold
			else:
				zero_count += 1
		var snapshot := spawner.get_kill_gold_budget_snapshot()
		var budget := maxi(int(snapshot.get("budget", 0)), 1)
		total_ratio += float(trial_gold) / float(budget)
	var average_ratio := total_ratio / float(trial_count)
	if average_ratio < 0.92 or average_ratio > 1.08:
		push_error("KillGoldDropProbe: HP-budget gold average ratio %.3f is outside tolerance." % average_ratio)
		return false
	if zero_count <= 0 or positive_count <= 0:
		push_error("KillGoldDropProbe: HP-budget gold should still produce mixed zero and positive rolls.")
		return false
	PhaseManager.current_level = 0
	var lazy_spawner := spawner_scene.instantiate() as EnemySpawner
	if lazy_spawner == null:
		push_error("KillGoldDropProbe: failed to instantiate lazy EnemySpawner")
		return false
	add_child(lazy_spawner)
	await get_tree().process_frame
	if not lazy_spawner.ensure_kill_gold_budget_active():
		push_error("KillGoldDropProbe: lazy budget activation failed.")
		return false
	var lazy_gold := lazy_spawner.roll_enemy_kill_gold(mock_enemy)
	var lazy_snapshot := lazy_spawner.get_kill_gold_budget_snapshot()
	GlobalVariables.economy_data = null
	var reload_spawner := spawner_scene.instantiate() as EnemySpawner
	if reload_spawner == null:
		push_error("KillGoldDropProbe: failed to instantiate reload EnemySpawner")
		return false
	add_child(reload_spawner)
	await get_tree().process_frame
	PhaseManager.current_level = 0
	reload_spawner.call("_start_kill_gold_budget", 0, 60)
	var reload_budget := int(reload_spawner.get_kill_gold_budget_snapshot().get("budget", 0))
	var reloaded_economy := GlobalVariables.economy_data as EconomyConfig
	var expected_reload_target := int(reloaded_economy.kill_gold_target_by_level[0]) if reloaded_economy and not reloaded_economy.kill_gold_target_by_level.is_empty() else 0
	var reload_variance := clampf(float(reloaded_economy.kill_gold_budget_variance), 0.0, 1.0) if reloaded_economy else 0.0
	var reload_min := int(round(float(expected_reload_target) * maxf(0.0, 1.0 - reload_variance)))
	var reload_max := int(round(float(expected_reload_target) * (1.0 + reload_variance)))
	if reload_budget < reload_min or reload_budget > reload_max:
		push_error("KillGoldDropProbe: economy reload budget should use resource target %d, got %d." % [expected_reload_target, reload_budget])
		return false
	print("KillGoldDropProbe: level=1 trials=%d enemy_count=%d hp=%d average_ratio=%.3f zero=%d positive=%d | lazy active=%s first=%d budget=%d" % [
		trial_count,
		enemy_count,
		enemy_hp,
		average_ratio,
		zero_count,
		positive_count,
		str(lazy_spawner.is_kill_gold_budget_active()),
		lazy_gold,
		int(lazy_snapshot.get("budget", 0)),
	])
	mock_enemy.queue_free()
	spawner.queue_free()
	lazy_spawner.queue_free()
	reload_spawner.queue_free()
	await get_tree().process_frame
	return true
