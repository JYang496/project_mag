extends Node

const RESULT := preload("res://tests/infrastructure/performance_result.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const OBJECTIVE_POINT_PLANNER := preload("res://World/spawn/contract_objective_point_planner.gd")
const ROLLING_ENEMY := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")
const SEED := 0x4D4147
const SCALES := [80, 160, 240]
const STEADY_SAMPLE_FRAMES := 48
const STEADY_QUERIES_PER_FRAME := 12

var _failed := false
var _created: Array[Node2D] = []
var _results: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_validate_result_math()
	_validate_objective_point_planner()
	await _validate_central_simulation_systems()
	var first_positions := _generate_positions(80, SEED, &"dense")
	var repeated_positions := _generate_positions(80, SEED, &"dense")
	_expect(first_positions == repeated_positions, "fixed seed must produce identical positions")
	for scale in SCALES:
		await _run_scale(scale)
		await _run_central_simulation_scale(scale)
		await _run_batch_entity_scale(scale)
		await _run_real_enemy_scale(scale)
	await _run_bulk_death(80)
	await _run_repeat_battle(80)
	_exercise_object_pool()
	var output := {
		"schema_version": RESULT.SCHEMA_VERSION,
		"suite_id": "phase4_registry_combat_baseline",
		"revision": OS.get_environment("PHASE4_REVISION"),
		"generated_utc": Time.get_datetime_string_from_system(true),
		"results": _results,
	}
	var path := "user://phase4_performance_baseline.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "baseline JSON must be writable")
	if file != null:
		file.store_string(JSON.stringify(output, "  "))
		file.close()
	print("PHASE4_BASELINE_PATH=%s" % ProjectSettings.globalize_path(path))
	print("PHASE4_BASELINE_JSON=%s" % JSON.stringify(output))
	print("FAIL: phase4 performance benchmark suite" if _failed else "PASS: phase4 performance benchmark suite")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0, _reset_runtime_state)

func _run_scale(count: int) -> void:
	_reset_registry_and_nodes()
	EnemyRegistry.reset_query_metrics()
	var spawn_started := Time.get_ticks_usec()
	var positions := _generate_positions(count, SEED + count, &"dense")
	for position in positions:
		_create_probe(position)
	var spawn_ms := float(Time.get_ticks_usec() - spawn_started) / 1000.0
	var spawn_samples := PackedFloat64Array([spawn_ms])
	_results.append(RESULT.build(
		"spawn_burst_%d" % count, SEED + count, count, "dense_grid", spawn_samples,
		{"spawned_nodes": count, "freed_nodes": 0, "query_count": 0, "candidate_checks": 0, "bucket_visits": 0,
		 "collision_contacts": null, "vfx_spawned": null, "pool_hits": null, "pool_misses": null},
		{"phase": "spawn", "position_signature": _position_signature(positions)}
	))
	await get_tree().process_frame
	EnemyRegistry.reset_query_metrics()
	var samples := PackedFloat64Array()
	for frame_index in STEADY_SAMPLE_FRAMES:
		var started := Time.get_ticks_usec()
		for query_index in STEADY_QUERIES_PER_FRAME:
			var origin := Vector2(
				float((frame_index * 37 + query_index * 71) % 640) - 320.0,
				float((frame_index * 53 + query_index * 29) % 480) - 240.0
			)
			EnemyRegistry.get_enemies_in_radius(origin, 96.0)
		await get_tree().process_frame
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var query_metrics := EnemyRegistry.get_query_metrics()
	_results.append(RESULT.build(
		"dense_steady_%d" % count, SEED + count, count, "dense_grid", samples,
		{"spawned_nodes": count, "freed_nodes": 0, "query_count": query_metrics.get("query_count"),
		 "candidate_checks": query_metrics.get("candidate_checks"), "bucket_visits": query_metrics.get("bucket_visits"),
		 "collision_contacts": null, "vfx_spawned": null, "pool_hits": null, "pool_misses": null},
		{"phase": "steady", "warmup_frames": 1, "queries_per_frame": STEADY_QUERIES_PER_FRAME,
		 "position_signature": _position_signature(positions)}
	))
	_expect(EnemyRegistry.get_enemy_count() == count, "steady scale %d registry count drifted" % count)

func _run_bulk_death(count: int) -> void:
	_reset_registry_and_nodes()
	for position in _generate_positions(count, SEED + 700, &"dense"):
		_create_probe(position)
	await get_tree().process_frame
	var started := Time.get_ticks_usec()
	for enemy in _created:
		enemy.queue_free()
	_created.clear()
	await get_tree().process_frame
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_results.append(RESULT.build(
		"bulk_death_%d" % count, SEED + 700, count, "dense_grid", PackedFloat64Array([elapsed_ms]),
		{"spawned_nodes": count, "freed_nodes": count, "query_count": 0, "candidate_checks": 0, "bucket_visits": 0,
		 "collision_contacts": null, "vfx_spawned": 0, "pool_hits": null, "pool_misses": null},
		{"phase": "bulk_death", "presentation_mode": "logic_only"}
	))
	_expect(EnemyRegistry.get_enemy_count() == 0, "bulk death must empty registry")

func _run_central_simulation_scale(count: int) -> void:
	var probes: Array[SimulationEnemyProbe] = []
	for index in count:
		var probe := SimulationEnemyProbe.new()
		probe.position = Vector2(float(index % 20) * 8.0, float(index / 20) * 8.0)
		add_child(probe)
		EnemySimulationSystem.register_enemy(probe)
		probes.append(probe)
	EnemySimulationSystem.reset_metrics()
	var samples := PackedFloat64Array()
	for frame_index in 24:
		var started := Time.get_ticks_usec()
		await get_tree().physics_frame
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var system_metrics := EnemySimulationSystem.get_metrics_snapshot()
	_results.append(RESULT.build(
		"central_enemy_simulation_%d" % count, SEED + 1200 + count, count, "dense_grid", samples,
		{"spawned_nodes": count, "freed_nodes": count, "query_count": 0, "candidate_checks": 0, "bucket_visits": 0,
		 "collision_contacts": null, "vfx_spawned": null, "pool_hits": null, "pool_misses": null},
		{"phase": "central_simulation", "system_metrics": system_metrics}
	))
	_expect(int(system_metrics.registered) >= count, "central simulation scale %d lost registrations" % count)
	for probe in probes:
		_expect(probe.step_count > 0 and probe.step_count < 1000, "central simulation must run only the batch hook")
		EnemySimulationSystem.unregister_enemy(probe)
		probe.queue_free()
	await get_tree().process_frame

func _run_batch_entity_scale(count: int) -> void:
	var projectiles: Array[SimulationProjectileProbe] = []
	var collectables: Array[SimulationCollectableProbe] = []
	for index in count:
		var projectile := SimulationProjectileProbe.new()
		add_child(projectile)
		ProjectileSimulationSystem.register_projectile(projectile)
		projectiles.append(projectile)
		var collectable := SimulationCollectableProbe.new()
		add_child(collectable)
		CollectableRegistry.register_collectable(collectable)
		collectables.append(collectable)
	var samples := PackedFloat64Array()
	for frame_index in 24:
		var started := Time.get_ticks_usec()
		await get_tree().physics_frame
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var projectile_metrics := ProjectileSimulationSystem.get_metrics_snapshot()
	var collectable_metrics := CollectableRegistry.get_batch_metrics_snapshot()
	_results.append(RESULT.build(
		"batch_projectile_collectable_%d" % count, SEED + 1800 + count, 0, "dense_grid", samples,
		{"spawned_nodes": count * 2, "freed_nodes": count * 2, "query_count": 0, "candidate_checks": 0, "bucket_visits": 0,
		 "collision_contacts": null, "vfx_spawned": null, "pool_hits": null, "pool_misses": null},
		{"phase": "batch_entities", "projectile_count": count, "collectable_count": count,
		 "projectile_metrics": projectile_metrics, "collectable_metrics": collectable_metrics}
	))
	_expect(int(projectile_metrics.registered) >= count, "projectile batch scale %d lost registrations" % count)
	_expect(int(collectable_metrics.registered) >= count, "collectable batch scale %d lost registrations" % count)
	for projectile in projectiles:
		_expect(projectile.step_count > 0, "batched projectile did not advance")
		ProjectileSimulationSystem.unregister_projectile(projectile)
		projectile.queue_free()
	for collectable in collectables:
		_expect(collectable.step_count > 0, "batched collectable did not advance")
		CollectableRegistry.unregister_collectable(collectable)
		collectable.queue_free()
	await get_tree().process_frame

func _run_real_enemy_scale(count: int) -> void:
	_reset_registry_and_nodes()
	var previous_player: Node = PlayerData.player
	var player := CharacterBody2D.new()
	player.global_position = Vector2.ZERO
	add_child(player)
	PlayerData.player = player
	var enemies: Array[BaseEnemy] = []
	var positions := _generate_positions(count, SEED + 2400 + count, &"dense")
	for position in positions:
		var enemy := ROLLING_ENEMY.instantiate() as BaseEnemy
		enemy.global_position = position + Vector2(600.0, 600.0)
		add_child(enemy)
		enemies.append(enemy)
	await get_tree().process_frame
	await get_tree().physics_frame
	EnemySimulationSystem.reset_metrics()
	var samples := PackedFloat64Array()
	for frame_index in 24:
		var started := Time.get_ticks_usec()
		await get_tree().physics_frame
		samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
	var system_metrics := EnemySimulationSystem.get_metrics_snapshot()
	_results.append(RESULT.build(
		"real_enemy_simulation_%d" % count, SEED + 2400 + count, count, "dense_grid", samples,
		{"spawned_nodes": count, "freed_nodes": count, "query_count": null, "candidate_checks": null, "bucket_visits": null,
		 "collision_contacts": null, "vfx_spawned": null, "pool_hits": null, "pool_misses": null},
		{"phase": "real_enemy_simulation", "enemy_type": "rolling_ball", "system_metrics": system_metrics}
	))
	_expect(int(system_metrics.registered) >= count, "real enemy scale %d lost central registrations" % count)
	for enemy in enemies:
		EnemySimulationSystem.unregister_enemy(enemy)
		enemy.queue_free()
	player.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	PlayerData.player = previous_player
	_expect(EnemyRegistry.get_enemy_count() == 0, "real enemy scale %d retained registry entries" % count)

func _run_repeat_battle(count: int) -> void:
	var battle_summaries: Array[Dictionary] = []
	for battle_index in 2:
		_reset_registry_and_nodes()
		for position in _generate_positions(count, SEED + 900, &"spread"):
			_create_probe(position)
		await get_tree().process_frame
		EnemyRegistry.reset_query_metrics()
		var samples := PackedFloat64Array()
		for frame_index in 24:
			var started := Time.get_ticks_usec()
			EnemyRegistry.get_enemies_in_radius(Vector2.ZERO, 480.0)
			await get_tree().process_frame
			samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		var summary := RESULT.summarize(samples)
		summary["query_metrics"] = EnemyRegistry.get_query_metrics()
		summary["registry_before_cleanup"] = EnemyRegistry.get_spatial_debug_snapshot()
		battle_summaries.append(summary)
		_reset_registry_and_nodes()
		await get_tree().process_frame
		_expect(EnemyRegistry.get_enemy_count() == 0, "battle %d cleanup retained registry nodes" % (battle_index + 1))
	var first_p99 := float(battle_summaries[0].p99_frame_ms)
	var second_p99 := float(battle_summaries[1].p99_frame_ms)
	var drift_ratio := second_p99 / maxf(first_p99, 0.001)
	_results.append(RESULT.build(
		"battle_repeat_80", SEED + 900, count, "spread_grid", PackedFloat64Array([first_p99, second_p99]),
		{"spawned_nodes": count * 2, "freed_nodes": count * 2, "query_count": 48,
		 "candidate_checks": int(battle_summaries[0].query_metrics.candidate_checks) + int(battle_summaries[1].query_metrics.candidate_checks),
		 "bucket_visits": int(battle_summaries[0].query_metrics.bucket_visits) + int(battle_summaries[1].query_metrics.bucket_visits),
		 "collision_contacts": null, "vfx_spawned": null, "pool_hits": null, "pool_misses": null},
		{"phase": "repeat", "battle_summaries": battle_summaries, "second_to_first_p99_ratio": drift_ratio}
	))
	# Headless scheduling noise can dominate tiny probe workloads; structural state
	# must be exact while timing drift remains a reported soft metric.
	_expect(int(battle_summaries[0].registry_before_cleanup.enemy_count) == count, "first battle population mismatch")
	_expect(int(battle_summaries[1].registry_before_cleanup.enemy_count) == count, "second battle population mismatch")

func _exercise_object_pool() -> void:
	ObjectPool.clear()
	ObjectPool.reset_metrics()
	var template := Node2D.new()
	var packed := PackedScene.new()
	packed.pack(template)
	template.free()
	for index in 80:
		var node := ObjectPool.acquire(packed)
		add_child(node)
		ObjectPool.release(node)
	var metrics := ObjectPool.get_metrics_snapshot()
	_expect(int(metrics.pool_hits) == 79, "pool exercise must reuse after first miss")
	_expect(int(metrics.pool_misses) == 1, "pool exercise must instantiate exactly once")
	_results.append(RESULT.build(
		"object_pool_reuse", SEED, 0, "none", PackedFloat64Array(),
		{"spawned_nodes": 1, "freed_nodes": 0, "query_count": null, "candidate_checks": null, "bucket_visits": null,
		 "collision_contacts": null, "vfx_spawned": null, "pool_hits": metrics.pool_hits, "pool_misses": metrics.pool_misses},
		{"phase": "pool", "pool_metrics": metrics}
	))

func _generate_positions(count: int, seed_value: int, density: StringName) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var positions := PackedVector2Array()
	var spacing := 24.0 if density == &"dense" else 72.0
	var columns := maxi(ceili(sqrt(float(count))), 1)
	for index in count:
		var x := float(index % columns) * spacing + rng.randf_range(-1.5, 1.5)
		var y := float(index / columns) * spacing + rng.randf_range(-1.5, 1.5)
		positions.append(Vector2(x, y) - Vector2(columns, columns) * spacing * 0.5)
	return positions

func _position_signature(positions: PackedVector2Array) -> int:
	var signature := 17
	for position in positions:
		signature = int((signature * 31 + roundi(position.x * 10.0) * 7 + roundi(position.y * 10.0)) & 0x7fffffff)
	return signature

func _create_probe(position: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.global_position = position
	add_child(enemy)
	EnemyRegistry.register_enemy(enemy)
	_created.append(enemy)
	return enemy

func _reset_registry_and_nodes() -> void:
	for enemy in _created:
		if enemy != null and is_instance_valid(enemy):
			EnemyRegistry.unregister_enemy(enemy)
			enemy.queue_free()
	_created.clear()
	for enemy in EnemyRegistry.get_enemies():
		EnemyRegistry.unregister_enemy(enemy)

func _reset_runtime_state() -> void:
	_reset_registry_and_nodes()
	EnemyRegistry.reset_query_metrics()
	ObjectPool.clear()
	ObjectPool.reset_metrics()

func _validate_result_math() -> void:
	var samples := PackedFloat64Array([4.0, 1.0, 3.0, 2.0, 100.0])
	var summary := RESULT.summarize(samples)
	_expect(is_equal_approx(float(summary.average_frame_ms), 22.0), "average calculation drifted")
	_expect(is_equal_approx(float(summary.p95_frame_ms), 100.0), "p95 calculation drifted")
	_expect(is_equal_approx(float(summary.maximum_frame_ms), 100.0), "maximum calculation drifted")

func _validate_objective_point_planner() -> void:
	var planner := OBJECTIVE_POINT_PLANNER.new()
	var cells: Array = []
	for position in [Vector2(-800.0, 0.0), Vector2(0.0, -800.0), Vector2(800.0, 0.0), Vector2(0.0, 800.0)]:
		var cell := Node2D.new()
		cell.global_position = position - Vector2(256.0, 256.0)
		add_child(cell)
		cells.append(cell)
	var beacons: PackedVector2Array = planner.select_beacon_points(cells, Vector2.ZERO)
	var objectives: PackedVector2Array = planner.select_objective_points(cells, Vector2.ZERO)
	_expect(beacons.size() == 2, "objective planner must select a beacon pair")
	_expect(beacons[0].distance_to(beacons[1]) >= planner.MIN_BEACON_DISTANCE, "beacon pair spacing regressed")
	_expect(objectives.size() == 3, "objective planner must select three separated points")
	for cell in cells:
		cell.queue_free()

func _validate_central_simulation_systems() -> void:
	var enemy := SimulationEnemyProbe.new()
	add_child(enemy)
	_expect(EnemySimulationSystem.register_enemy(enemy), "ordinary enemy must register with central simulation")
	_expect(not enemy.is_physics_processing(), "central enemy must disable its individual physics callback")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(enemy.step_count > 0, "central enemy system must advance registered enemies")
	var active_steps := enemy.step_count
	remove_child(enemy)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(enemy.step_count == active_steps, "detached enemy must not receive central simulation steps")
	_expect(int(EnemySimulationSystem.get_metrics_snapshot().registered) == 0, "detached enemy must be pruned from central simulation")
	enemy.queue_free()

	var projectile := SimulationProjectileProbe.new()
	add_child(projectile)
	_expect(ProjectileSimulationSystem.register_projectile(projectile), "simple projectile must register with batch simulation")
	_expect(not projectile.is_physics_processing(), "batched projectile must disable its individual physics callback")
	await get_tree().physics_frame
	_expect(projectile.step_count > 0, "projectile batch system must advance registered projectiles")
	ProjectileSimulationSystem.unregister_projectile(projectile, true)
	_expect(projectile.is_physics_processing(), "complex projectile fallback must restore individual processing")
	projectile.queue_free()

	var collectable := SimulationCollectableProbe.new()
	add_child(collectable)
	CollectableRegistry.register_collectable(collectable)
	_expect(not collectable.is_physics_processing(), "registered collectable must use central attraction")
	await get_tree().physics_frame
	_expect(collectable.step_count > 0, "collectable registry must advance attraction in one batch")
	CollectableRegistry.unregister_collectable(collectable)
	collectable.queue_free()

	await get_tree().process_frame
	var metrics := CombatRuntimeMetrics.get_snapshot()
	_expect(metrics.has("peaks") and metrics.has("frame_p95_ms"), "runtime metrics must expose peaks and frame percentiles")

class SimulationEnemyProbe extends Node2D:
	var step_count := 0
	var is_boss := false

	func simulation_physics_step(_delta: float) -> void:
		step_count += 1

	func _physics_process(_delta: float) -> void:
		step_count += 1000

	func uses_central_simulation() -> bool:
		return true

class SimulationProjectileProbe extends Node2D:
	var step_count := 0

	func batch_simulation_step(_delta: float) -> void:
		step_count += 1

class SimulationCollectableProbe extends Node2D:
	var step_count := 0

	func batch_attraction_step(_delta: float) -> void:
		step_count += 1

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
