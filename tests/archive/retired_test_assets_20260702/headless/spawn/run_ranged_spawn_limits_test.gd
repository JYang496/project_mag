extends Node

const SpawnerScene := preload("res://World/spawn/enemy_spawner.tscn")
const SpikeScene := preload("res://Npc/enemy/scenes/enemy_spike_turret.tscn")
const RollingBallScene := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")

var _spawner: EnemySpawner

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var profile := SpawnData.get_spawn_combat_profile()
	if profile == null:
		_fail("missing spawn combat profile")
		return
	if int(profile.get("max_same_type_per_batch")) != 15:
		_fail("max_same_type_per_batch should be 15")
		return
	if int(profile.get("max_ranged_per_batch")) != 4:
		_fail("max_ranged_per_batch should be 4")
		return
	if int(profile.get("max_ranged_alive_total")) != 8:
		_fail("max_ranged_alive_total should be 8")
		return

	_spawner = SpawnerScene.instantiate() as EnemySpawner
	if _spawner == null:
		_fail("failed to instantiate EnemySpawner")
		return
	_spawner.debug_print_spawn_stats = false
	get_tree().root.add_child(_spawner)
	await get_tree().process_frame

	var ranged_entry := EnemySpawnEntry.new()
	ranged_entry.enemy = SpikeScene
	ranged_entry.weight = 1
	var melee_entry := EnemySpawnEntry.new()
	melee_entry.enemy = RollingBallScene
	melee_entry.weight = 1
	var capped_state := {"id": 0, "entry": ranged_entry, "alive": 8, "cooldown": 0}
	_spawner._runtime_spawn_states = [capped_state]
	var can_pick_at_cap := bool(_spawner.call("_can_pick_candidate", capped_state, {}, 0, 0, 2))
	if can_pick_at_cap:
		_fail("ranged candidate was pickable after 8 ranged enemies were already alive")
		return

	var ranged_batch_full_state := {"id": 0, "entry": ranged_entry, "alive": 0, "cooldown": 0}
	var melee_after_ranged_state := {"id": 1, "entry": melee_entry, "alive": 0, "cooldown": 0}
	_spawner._runtime_spawn_states = [ranged_batch_full_state, melee_after_ranged_state]
	var can_pick_ranged_after_batch_cap := bool(_spawner.call("_can_pick_candidate", ranged_batch_full_state, {}, 4, 0, 2))
	if can_pick_ranged_after_batch_cap:
		_fail("ranged candidate was pickable after 4 ranged enemies were already in the batch")
		return
	var melee_scene_path := melee_entry.enemy.resource_path
	var can_pick_melee_after_ranged_batch_cap := bool(_spawner.call(
		"_can_pick_candidate",
		melee_after_ranged_state,
		{melee_scene_path: 14},
		4,
		0,
		2
	))
	if not can_pick_melee_after_ranged_batch_cap:
		_fail("melee candidate should stay pickable after the ranged batch cap when same-type batch count is below 15")
		return
	var can_pick_melee_at_same_type_cap := bool(_spawner.call(
		"_can_pick_candidate",
		melee_after_ranged_state,
		{melee_scene_path: 15},
		4,
		0,
		2
	))
	if can_pick_melee_at_same_type_cap:
		_fail("melee candidate was pickable after 15 same-type enemies were already in the batch")
		return

	var spawn_state := {"id": 0, "entry": ranged_entry, "alive": 0, "cooldown": 0}
	_spawner._runtime_spawn_states = [spawn_state]
	var spawned_hp := int(_spawner.call("_spawn_from_state", spawn_state, 9))
	if spawned_hp <= 0:
		_fail("single ranged spawn call did not spawn enemies")
		return
	if int(spawn_state.get("alive", 0)) != 9:
		_fail("single ranged spawn call should be allowed to exceed the ranged alive total cap")
		return

	print("PASS: ranged spawn batch and alive limits")
	_cleanup()
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("FAIL: %s" % message)
	_cleanup()
	get_tree().quit(1)

func _cleanup() -> void:
	if _spawner != null and is_instance_valid(_spawner):
		_spawner.queue_free()
