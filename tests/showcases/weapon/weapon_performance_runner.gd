extends Node
class_name WeaponPerformanceRunner

const COLLECTOR_SCRIPT := preload("res://tests/showcases/weapon/combat_performance_collector.gd")
const DRIVER_SCRIPT := preload("res://tests/showcases/weapon/simulated_player_driver.gd")
const REPORT_SCRIPT := preload("res://tests/showcases/weapon/weapon_performance_report.gd")

signal suite_started(suite_id: String, scenario_count: int)
signal scenario_started(display_name: String, index: int, total: int)
signal scenario_finished(result: Dictionary)
signal suite_finished(report: Dictionary, report_path: String)
signal progress_changed(message: String)

var host: Node
var collector: CombatPerformanceCollector
var driver: SimulatedPlayerDriver
var running := false
var current_state: StringName = &"idle"
var latest_report: Dictionary = {}
var latest_report_path := ""
var active_scenario: WeaponPerformanceScenario


func setup(host_value: Node) -> void:
	host = host_value
	collector = COLLECTOR_SCRIPT.new()
	collector.name = "CombatPerformanceCollector"
	add_child(collector)
	driver = DRIVER_SCRIPT.new()
	driver.name = "SimulatedPlayerDriver"
	add_child(driver)


func run_suite(suite_id: String, scenarios: Array[WeaponPerformanceScenario], save_as_baseline := false) -> Dictionary:
	if running or host == null:
		return {}
	running = true
	current_state = &"setup"
	var started_at := Time.get_datetime_string_from_system(false, true)
	var results: Array[Dictionary] = []
	var total_runs := 0
	for scenario in scenarios:
		total_runs += maxi(scenario.repeat_count, 1)
	suite_started.emit(suite_id, total_runs)
	var run_index := 0
	for scenario in scenarios:
		if not running:
			break
		for repeat_index in maxi(scenario.repeat_count, 1):
			if not running:
				break
			run_index += 1
			scenario_started.emit(scenario.display_name, run_index, total_runs)
			var result := await _run_scenario(scenario, repeat_index)
			if not running:
				break
			results.append(result)
			scenario_finished.emit(result)
	if not running:
		return {}
	latest_report = REPORT_SCRIPT.build_suite(suite_id, results, started_at)
	latest_report_path = REPORT_SCRIPT.save_suite(latest_report)
	if save_as_baseline:
		REPORT_SCRIPT.save_baseline(latest_report)
	current_state = &"idle"
	running = false
	suite_finished.emit(latest_report, latest_report_path)
	return latest_report


func cancel() -> void:
	if not running:
		return
	running = false
	current_state = &"cancelled"
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	driver.stop()
	Input.action_release("ATTACK")
	if host != null and host.has_method("performance_cleanup_scenario"):
		host.call_deferred("performance_cleanup_scenario")


func _run_scenario(scenario: WeaponPerformanceScenario, repeat_index: int) -> Dictionary:
	current_state = &"setup"
	active_scenario = scenario
	progress_changed.emit("准备：%s" % scenario.display_name)
	var setup_started := Time.get_ticks_usec()
	var context: Dictionary = await host.performance_prepare_scenario(scenario)
	var setup_ms := float(Time.get_ticks_usec() - setup_started) / 1000.0
	var player := context.get("player") as Player
	var weapon := context.get("weapon") as Weapon
	var targets: Array[Node2D] = []
	for target_value in context.get("targets", []) as Array:
		var target := target_value as Node2D
		if target != null:
			targets.append(target)
	driver.begin(player, weapon, scenario, targets)
	current_state = &"warmup"
	progress_changed.emit("预热：%s" % scenario.display_name)
	await _wait_seconds(scenario.warmup_sec)
	if not running:
		driver.stop()
		active_scenario = null
		return {}
	EnemyRegistry.reset_query_metrics()
	EnemyRegistry.set_query_profiling_enabled(true)
	EnemySimulationSystem.reset_metrics()
	EnemySimulationSystem.detailed_profiling_enabled = true
	for view in get_tree().get_nodes_in_group(&"hybrid_ground_view_3d"):
		if view.has_method("reset_visual_timing_metrics"):
			view.call("reset_visual_timing_metrics")
	ObjectPool.reset_metrics()
	collector.begin(scenario, setup_ms)
	current_state = &"sampling"
	progress_changed.emit("采样：%s" % scenario.display_name)
	await _wait_seconds(scenario.duration_sec)
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	if not running:
		collector.finish()
		driver.stop()
		active_scenario = null
		return {}
	var result := collector.finish({
		"repeat_index": repeat_index,
		"cache_state": "cold_requested" if scenario.cold_cache_mode else ("first_pass" if repeat_index == 0 else "warm"),
		"weapon_label": str(context.get("weapon_label", "")),
	})
	driver.stop()
	current_state = &"cooldown"
	await _wait_seconds(scenario.cooldown_sec)
	current_state = &"cleanup"
	var cleanup_started := Time.get_ticks_usec()
	await host.performance_cleanup_scenario()
	var cleanup_ms := float(Time.get_ticks_usec() - cleanup_started) / 1000.0
	result["cleanup_ms"] = cleanup_ms
	result["post_cleanup"] = {
		"enemies": EnemyRegistry.get_enemy_count(),
		"projectiles": get_tree().get_node_count_in_group(&"runtime_projectiles"),
		"collectables": CollectableRegistry.get_collectable_count(),
		"area_effects": get_tree().get_node_count_in_group(&"runtime_area_effects"),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}
	active_scenario = null
	return result


func _wait_seconds(duration_sec: float) -> void:
	var remaining := maxf(duration_sec, 0.0)
	while remaining > 0.0 and running:
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		var elapsed := maxf(float(Time.get_ticks_usec() - started) / 1000000.0, 0.0001)
		remaining -= elapsed
		if host != null and host.has_method("performance_tick_scenario"):
			host.call("performance_tick_scenario", active_scenario, elapsed)
