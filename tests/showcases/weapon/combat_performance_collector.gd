extends Node
class_name CombatPerformanceCollector

const PERFORMANCE_RESULT := preload("res://tests/infrastructure/performance_result.gd")

var _collecting := false
var _scenario: WeaponPerformanceScenario
var _frame_samples := PackedFloat64Array()
var _physics_samples := PackedFloat64Array()
var _process_samples := PackedFloat64Array()
var _draw_call_samples := PackedFloat64Array()
var _enemy_step_samples := PackedFloat64Array()
var _enemy_interval_samples := PackedFloat64Array()
var _projectile_step_samples := PackedFloat64Array()
var _collectable_step_samples := PackedFloat64Array()
var _entity_series: Array[Dictionary] = []
var _hitch_counts := {"16_67_ms": 0, "33_33_ms": 0, "50_ms": 0, "100_ms": 0}
var _maximum_consecutive_hitches := 0
var _current_consecutive_hitches := 0
var _peaks := {"enemies": 0, "projectiles": 0, "collectables": 0, "area_effects": 0, "nodes": 0, "orphans": 0}
var _initial_pool_metrics: Dictionary = {}
var _setup_ms := 0.0
var _previous_frame_usec := 0
var _collection_started_usec := 0
var _slow_frame_count := 0
var _slow_frame_enemy_total := 0.0
var _slow_frame_enemy_step_total := 0.0
var _slow_frame_enemy_interval_total := 0.0
var _slow_frame_draw_call_total := 0.0
var _slow_frame_physics_total := 0.0
var _slow_frame_process_total := 0.0
var _previous_enemy_total_ms := 0.0
var _initial_enemy_total_ms := 0.0
var _initial_enemy_tick_count := 0


func begin(scenario: WeaponPerformanceScenario, setup_ms: float = 0.0) -> void:
	_scenario = scenario
	_setup_ms = setup_ms
	_frame_samples.clear()
	_physics_samples.clear()
	_process_samples.clear()
	_draw_call_samples.clear()
	_enemy_step_samples.clear()
	_enemy_interval_samples.clear()
	_projectile_step_samples.clear()
	_collectable_step_samples.clear()
	_entity_series.clear()
	_hitch_counts = {"16_67_ms": 0, "33_33_ms": 0, "50_ms": 0, "100_ms": 0}
	_maximum_consecutive_hitches = 0
	_current_consecutive_hitches = 0
	_peaks = {"enemies": 0, "projectiles": 0, "collectables": 0, "area_effects": 0, "nodes": 0, "orphans": 0}
	_initial_pool_metrics = ObjectPool.get_metrics_snapshot() if ObjectPool != null else {}
	_previous_frame_usec = Time.get_ticks_usec()
	_collection_started_usec = _previous_frame_usec
	_slow_frame_count = 0
	_slow_frame_enemy_total = 0.0
	_slow_frame_enemy_step_total = 0.0
	_slow_frame_enemy_interval_total = 0.0
	_slow_frame_draw_call_total = 0.0
	_slow_frame_physics_total = 0.0
	_slow_frame_process_total = 0.0
	var initial_enemy_metrics: Dictionary = EnemySimulationSystem.get_metrics_snapshot()
	_initial_enemy_total_ms = float(initial_enemy_metrics.get("total_step_ms", 0.0))
	_initial_enemy_tick_count = int(initial_enemy_metrics.get("physics_tick_count", 0))
	_previous_enemy_total_ms = _initial_enemy_total_ms
	for view in get_tree().get_nodes_in_group(&"hybrid_ground_view_3d"):
		if view.has_method("reset_visual_timing_metrics"):
			view.call("reset_visual_timing_metrics")
	_collecting = true


func finish(extra: Dictionary = {}) -> Dictionary:
	_collecting = false
	var frame_summary := PERFORMANCE_RESULT.summarize(_frame_samples)
	var final_enemy_metrics: Dictionary = EnemySimulationSystem.get_metrics_snapshot()
	var visual_metrics: Dictionary = {}
	for view in get_tree().get_nodes_in_group(&"hybrid_ground_view_3d"):
		if view.has_method("get_visual_performance_metrics"):
			visual_metrics = view.call("get_visual_performance_metrics") as Dictionary
			break
	var measured_duration_sec := maxf(float(Time.get_ticks_usec() - _collection_started_usec) / 1000000.0, 0.0)
	var result := PERFORMANCE_RESULT.build(
		_scenario.scenario_id,
		_scenario.random_seed,
		int(_peaks.enemies),
		str(_scenario.target_layout),
		_frame_samples,
		_build_counters(),
		{
			"phase": "production_world_weapon_lab",
			"scenario": _scenario.to_dictionary(),
			"setup_ms": _setup_ms,
			"measured_duration_sec": measured_duration_sec,
			"physics_frame_summary": PERFORMANCE_RESULT.summarize(_physics_samples),
			"process_monitor_summary": PERFORMANCE_RESULT.summarize(_process_samples),
			"draw_call_summary": PERFORMANCE_RESULT.summarize(_draw_call_samples),
			"slow_frame_context": {
				"threshold_ms": 25.0,
				"frames": _slow_frame_count,
				"average_enemies": _slow_frame_enemy_total / float(_slow_frame_count) if _slow_frame_count > 0 else 0.0,
				"average_enemy_step_ms": _slow_frame_enemy_step_total / float(_slow_frame_count) if _slow_frame_count > 0 else 0.0,
				"average_enemy_render_interval_ms": _slow_frame_enemy_interval_total / float(_slow_frame_count) if _slow_frame_count > 0 else 0.0,
				"average_draw_calls": _slow_frame_draw_call_total / float(_slow_frame_count) if _slow_frame_count > 0 else 0.0,
				"average_physics_monitor_ms": _slow_frame_physics_total / float(_slow_frame_count) if _slow_frame_count > 0 else 0.0,
				"average_process_monitor_ms": _slow_frame_process_total / float(_slow_frame_count) if _slow_frame_count > 0 else 0.0,
			},
			"enemy_step_summary": PERFORMANCE_RESULT.summarize(_enemy_step_samples),
			"enemy_render_interval_summary": PERFORMANCE_RESULT.summarize(_enemy_interval_samples),
			"enemy_simulation_total_ms": maxf(float(final_enemy_metrics.get("total_step_ms", 0.0)) - _initial_enemy_total_ms, 0.0),
			"enemy_physics_ticks": maxi(int(final_enemy_metrics.get("physics_tick_count", 0)) - _initial_enemy_tick_count, 0),
			"enemy_prune_total_ms": final_enemy_metrics.get("prune_total_ms", 0.0),
			"enemy_call_total_ms": final_enemy_metrics.get("enemy_call_total_ms", 0.0),
			"enemy_movement_profile": {
				"separation_ms": final_enemy_metrics.get("movement_separation_ms", 0.0),
				"slide_ms": final_enemy_metrics.get("movement_slide_ms", 0.0),
				"accept_ms": final_enemy_metrics.get("movement_accept_ms", 0.0),
				"sync_ms": final_enemy_metrics.get("movement_sync_ms", 0.0),
				"calls": final_enemy_metrics.get("movement_calls", 0),
			},
			"enemy_constraint_profile": {
				"total_ms": final_enemy_metrics.get("constraint_total_ms", 0.0),
				"calls": final_enemy_metrics.get("constraint_calls", 0),
				"full_refreshes": final_enemy_metrics.get("constraint_full_refreshes", 0),
			},
			"visual_sync_profile": visual_metrics,
			"enemy_registry_query_profile": EnemyRegistry.get_query_metrics(),
			"projectile_step_summary": PERFORMANCE_RESULT.summarize(_projectile_step_samples),
			"collectable_step_summary": PERFORMANCE_RESULT.summarize(_collectable_step_samples),
			"hitch_counts": _hitch_counts.duplicate(true),
			"maximum_consecutive_hitches": _maximum_consecutive_hitches,
			"one_percent_low_fps": _one_percent_low_fps(_frame_samples),
			"peaks": _peaks.duplicate(true),
			"entity_series": _entity_series.duplicate(true),
			"object_pool_before": _initial_pool_metrics,
			"object_pool_after": ObjectPool.get_metrics_snapshot() if ObjectPool != null else {},
			"rendering": _rendering_snapshot(),
			"measurement_note": "Central-system timings are sampled snapshots, not full exclusive frame attribution. Engine physics and process monitors can overlap or lag. Rendering, weapons, VFX and lab overhead are not individually timed; no exact causal shares are reported.",
		}
	)
	result.merge(frame_summary, true)
	result.merge(extra, true)
	return result


func cancel() -> void:
	_collecting = false


func _process(_delta: float) -> void:
	if not _collecting:
		return
	var now := Time.get_ticks_usec()
	var frame_ms := maxf(float(now - _previous_frame_usec) / 1000.0, 0.0)
	_previous_frame_usec = now
	_frame_samples.append(frame_ms)
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	_physics_samples.append(physics_ms)
	_process_samples.append(process_ms)
	var draw_calls := float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_draw_call_samples.append(draw_calls)
	var enemy_snapshot: Dictionary = EnemySimulationSystem.get_metrics_snapshot()
	var enemy_total_ms := float(enemy_snapshot.get("total_step_ms", 0.0))
	var enemy_interval_ms := maxf(enemy_total_ms - _previous_enemy_total_ms, 0.0)
	_previous_enemy_total_ms = enemy_total_ms
	_enemy_interval_samples.append(enemy_interval_ms)
	var projectile_snapshot: Dictionary = ProjectileSimulationSystem.get_metrics_snapshot()
	var collectable_snapshot: Dictionary = CollectableRegistry.get_batch_metrics_snapshot()
	_enemy_step_samples.append(float(enemy_snapshot.get("last_step_ms", 0.0)))
	_projectile_step_samples.append(float(projectile_snapshot.get("last_step_ms", 0.0)))
	_collectable_step_samples.append(float(collectable_snapshot.get("last_step_ms", 0.0)))
	_update_hitches(frame_ms)
	var counts := {
		"frame": _frame_samples.size(),
		"enemies": EnemyRegistry.get_enemy_count(),
		"projectiles": get_tree().get_node_count_in_group(&"runtime_projectiles"),
		"collectables": CollectableRegistry.get_collectable_count(),
		"area_effects": get_tree().get_node_count_in_group(&"runtime_area_effects"),
		"frame_ms": frame_ms,
		"physics_monitor_ms": physics_ms,
		"process_monitor_ms": process_ms,
		"enemy_step_ms": float(enemy_snapshot.get("last_step_ms", 0.0)),
		"enemy_interval_ms": enemy_interval_ms,
		"draw_calls": draw_calls,
	}
	if frame_ms >= 25.0:
		_slow_frame_count += 1
		_slow_frame_enemy_total += float(counts.enemies)
		_slow_frame_enemy_step_total += float(enemy_snapshot.get("last_step_ms", 0.0))
		_slow_frame_enemy_interval_total += enemy_interval_ms
		_slow_frame_draw_call_total += draw_calls
		_slow_frame_physics_total += physics_ms
		_slow_frame_process_total += process_ms
	for key in ["enemies", "projectiles", "collectables", "area_effects"]:
		_peaks[key] = maxi(int(_peaks[key]), int(counts[key]))
	_peaks.nodes = maxi(int(_peaks.nodes), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_peaks.orphans = maxi(int(_peaks.orphans), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))
	# A compact six-frame interval series correlates load with frame spikes.
	if _frame_samples.size() == 1 or _frame_samples.size() % 6 == 0:
		_entity_series.append(counts)


func _update_hitches(frame_ms: float) -> void:
	if frame_ms > 16.67:
		_hitch_counts["16_67_ms"] += 1
		_current_consecutive_hitches += 1
		_maximum_consecutive_hitches = maxi(_maximum_consecutive_hitches, _current_consecutive_hitches)
	else:
		_current_consecutive_hitches = 0
	if frame_ms > 33.33:
		_hitch_counts["33_33_ms"] += 1
	if frame_ms > 50.0:
		_hitch_counts["50_ms"] += 1
	if frame_ms > 100.0:
		_hitch_counts["100_ms"] += 1


func _build_counters() -> Dictionary:
	var before_hits := int(_initial_pool_metrics.get("pool_hits", 0))
	var before_misses := int(_initial_pool_metrics.get("pool_misses", 0))
	var after := ObjectPool.get_metrics_snapshot() if ObjectPool != null else {}
	var query_metrics: Dictionary = EnemyRegistry.get_query_metrics()
	return {
		"spawned_nodes": null,
		"freed_nodes": null,
		"query_count": query_metrics.get("query_count"),
		"candidate_checks": query_metrics.get("candidate_checks"),
		"bucket_visits": query_metrics.get("bucket_visits"),
		"separation_query_count": query_metrics.get("separation_query_count"),
		"radius_query_count": query_metrics.get("radius_query_count"),
		"rect_query_count": query_metrics.get("rect_query_count"),
		"separation_query_ms": query_metrics.get("separation_query_ms"),
		"radius_query_ms": query_metrics.get("radius_query_ms"),
		"rect_query_ms": query_metrics.get("rect_query_ms"),
		"collision_contacts": null,
		"vfx_spawned": null,
		"pool_hits": int(after.get("pool_hits", 0)) - before_hits,
		"pool_misses": int(after.get("pool_misses", 0)) - before_misses,
		"shutdown_diagnostics": 0,
	}


func _rendering_snapshot() -> Dictionary:
	return {
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"draw_calls_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"video_memory_mb": float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0,
		"static_memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
	}


func _one_percent_low_fps(samples: PackedFloat64Array) -> float:
	if samples.is_empty():
		return 0.0
	var slow_frame_ms := PERFORMANCE_RESULT.percentile(samples, 0.99)
	return 1000.0 / slow_frame_ms if slow_frame_ms > 0.0 else 0.0
