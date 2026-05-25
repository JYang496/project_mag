extends Node

func _ready() -> void:
	_run_and_quit()

func _run_and_quit() -> void:
	var ok := await _run()
	get_tree().quit(0 if ok else 1)

func _run() -> bool:
	DataHandler.load_economy_data()
	SpawnData.load_all_spawn_data(GlobalVariables.SPAWN_PATN)
	var spawner_scene := load("res://Utility/enemy_spawner.tscn") as PackedScene
	if spawner_scene == null:
		push_error("KillGoldDropProbe: failed to load enemy_spawner.tscn")
		return false
	var spawner := spawner_scene.instantiate() as EnemySpawner
	if spawner == null:
		push_error("KillGoldDropProbe: failed to instantiate EnemySpawner")
		return false
	add_child(spawner)
	await get_tree().process_frame
	var level_results: Array[String] = []
	for level_index in [0, 1]:
		PhaseManager.current_level = level_index
		spawner.start_timer()
		var zero_count := 0
		var positive_count := 0
		var total_gold := 0
		for _i in range(40):
			var gold := spawner.roll_enemy_kill_gold()
			if gold > 0:
				positive_count += 1
				total_gold += gold
			else:
				zero_count += 1
		var snapshot := spawner.get_kill_gold_budget_snapshot()
		level_results.append("L%d zero=%d positive=%d total=%d budget=%d paid=%d" % [
			level_index + 1,
			zero_count,
			positive_count,
			total_gold,
			int(snapshot.get("budget", 0)),
			int(snapshot.get("paid", 0)),
		])
		if zero_count <= 0:
			push_error("KillGoldDropProbe: level %d produced no zero-gold rolls." % (level_index + 1))
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
	var lazy_gold := lazy_spawner.roll_enemy_kill_gold()
	var lazy_snapshot := lazy_spawner.get_kill_gold_budget_snapshot()
	level_results.append("lazy active=%s first=%d budget=%d" % [
		str(lazy_spawner.is_kill_gold_budget_active()),
		lazy_gold,
		int(lazy_snapshot.get("budget", 0)),
	])
	print("KillGoldDropProbe: " + " | ".join(level_results))
	return true
