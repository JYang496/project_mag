extends Node

signal suite_stopped

const PROFILE := preload("res://data/spawns/spawn_combat_profile.tres")
const SCENARIO := preload("res://tests/showcases/weapon/weapon_performance_scenario.gd")
const COLLECTOR := preload("res://tests/showcases/weapon/combat_performance_collector.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const COUNTS := [10, 40, 120]
const REPORT_DIRECTORY := "user://performance/enemy_lab"
const SPIKE_SCENE_DEPENDENCIES: Array[String] = [
	"res://Npc/enemy/scenes/base_enemy.tscn",
	"res://Npc/enemy/scripts/enemy_spike_projectile.gd",
	"res://asset/images/enemies/enemy_spike_projectile.png",
	"res://Visual/Oblique/billboard_visual_2d.gd",
	"res://Npc/enemy/scenes/enemy_spike_projectile.tscn",
	"res://Combat/visual/combat_visual_palette.gd",
	"res://Combat/visual/combat_feedback_spec.gd",
	"res://Npc/enemy/scripts/enemy_spike_turret.gd",
	"res://asset/images/enemies/spike_turret.png",
	"res://asset/sounds/01_extremely_small_firepower_single.wav",
	"res://asset/sounds/synthetic_single_gunshot.wav",
	"res://Combat/area_effect/area_effect.tscn",
	"res://Npc/enemy/scenes/target_warning.tscn",
	"res://Npc/enemy/scenes/mortar_shell_descent_vfx.tscn",
	"res://asset/images/effects/mortar_impact/mortar_impact_frames.tres",
	"res://Npc/enemy/scripts/enemy_mortar_turret.gd",
	"res://asset/images/enemies/mortar_turret.png",
]

var _world: WorldShell
var _player: Player
var _spawner: EnemySpawner
var _collector: CombatPerformanceCollector
var _enemy_paths: Array[String] = []
var _enemy_picker: OptionButton
var _status: Label
var _run_button: Button
var _death_button: Button
var _spawn_button: Button
var _all_button: Button
var _cancel_button: Button
var _running := false
var _cancelled := false


func _ready() -> void:
	_world = get_parent() as WorldShell
	if _world == null:
		push_error("Enemy performance lab requires WorldShell.")
		return
	_world.build_completed.connect(_on_world_ready, CONNECT_ONE_SHOT)


func _on_world_ready() -> void:
	await get_tree().process_frame
	_player = PlayerData.player as Player
	_spawner = _world.get_node_or_null("EnemySpawner") as EnemySpawner
	if _player == null or _spawner == null:
		push_error("Enemy performance lab could not acquire world services.")
		return
	_spawner.stop_spawning()
	_spawner.erase_all_enemies()
	LoadingPerformance.hide_world_build_overlay()
	PhaseManager.phase = PhaseManager.BATTLE_STARTING
	PhaseManager.enter_battle()
	var board := _world.get_node_or_null("Board") as BoardCellGenerator
	if board != null:
		_player.global_position = board.get_center_cell_global_position()
	_player.velocity = Vector2.ZERO
	_player.damage_disabled = true
	var hurt_box := _player.hurt_box as HurtBox
	if hurt_box != null:
		hurt_box.set_collision_layer_value(1, false)
	for level in PROFILE.levels:
		if level == null:
			continue
		for entry in level.spawns:
			if entry != null and not entry.enemy_scene_path.is_empty() and not _enemy_paths.has(entry.enemy_scene_path):
				_enemy_paths.append(entry.enemy_scene_path)
	_enemy_paths.sort()
	_collector = COLLECTOR.new()
	add_child(_collector)
	_build_panel()
	_start_command_line_sample_if_requested.call_deferred()


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	_world.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(930, 105)
	panel.size = Vector2(334, 390)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var heading := Label.new()
	heading.text = "全敌人生成器 · 性能测试"
	heading.add_theme_font_size_override("font_size", 18)
	content.add_child(heading)
	var help := Label.new()
	help.text = "固定玩家，不攻击；每种敌人依次生成 10 / 40 / 120 个。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)
	_enemy_picker = OptionButton.new()
	for path in _enemy_paths:
		_enemy_picker.add_item(path.get_file().get_basename())
	content.add_child(_enemy_picker)
	_run_button = Button.new()
	_run_button.text = "测试所选敌人"
	_run_button.pressed.connect(_start_selected)
	content.add_child(_run_button)
	_death_button = Button.new()
	_death_button.text = "测试 40 敌人同时死亡"
	_death_button.pressed.connect(_start_selected_death_burst)
	content.add_child(_death_button)
	_spawn_button = Button.new()
	_spawn_button.text = "测试 40 敌人同帧生成"
	_spawn_button.pressed.connect(_start_selected_spawn_burst)
	content.add_child(_spawn_button)
	_all_button = Button.new()
	_all_button.text = "测试全部敌人"
	_all_button.pressed.connect(_start_all)
	content.add_child(_all_button)
	_cancel_button = Button.new()
	_cancel_button.text = "停止测试"
	_cancel_button.disabled = true
	_cancel_button.pressed.connect(func() -> void: _cancelled = true)
	content.add_child(_cancel_button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "共 %d 种战斗配置敌人。结果保存到 %s。" % [_enemy_paths.size(), REPORT_DIRECTORY]
	content.add_child(_status)
	var menu_button := Button.new()
	menu_button.text = "返回主菜单"
	menu_button.pressed.connect(_return_to_menu)
	content.add_child(menu_button)


func _start_selected() -> void:
	if _enemy_picker.selected < 0:
		return
	_start_suite([_enemy_paths[_enemy_picker.selected]])


func _start_selected_death_burst() -> void:
	if _enemy_picker.selected < 0 or _running:
		return
	_start_death_burst(_enemy_paths[_enemy_picker.selected], 40)


func _start_selected_spawn_burst() -> void:
	if _enemy_picker.selected < 0 or _running:
		return
	_start_spawn_burst(_enemy_paths[_enemy_picker.selected], 40)


func _start_all() -> void:
	_start_suite(_enemy_paths.duplicate())


func _start_command_line_sample_if_requested() -> void:
	var requested_path := ""
	var requested_count := 40
	var death_burst := false
	var spawn_burst := false
	var production_spawn_level := -1
	var production_spawn_prewarm := false
	var production_spawn_prewarm_sync := false
	var production_spawn_split_spike := false
	var production_duration_sec := 8.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--enemy-lab-auto="):
			requested_path = argument.trim_prefix("--enemy-lab-auto=")
		elif argument.begins_with("--enemy-lab-count="):
			requested_count = maxi(int(argument.trim_prefix("--enemy-lab-count=")), 1)
		elif argument == "--enemy-lab-death-burst":
			death_burst = true
		elif argument == "--enemy-lab-spawn-burst":
			spawn_burst = true
		elif argument.begins_with("--enemy-lab-production-spawn-level="):
			production_spawn_level = maxi(int(argument.trim_prefix("--enemy-lab-production-spawn-level=")), 0)
		elif argument == "--enemy-lab-production-spawn-prewarm":
			production_spawn_prewarm = true
		elif argument == "--enemy-lab-production-spawn-prewarm-sync":
			production_spawn_prewarm = true
			production_spawn_prewarm_sync = true
		elif argument == "--enemy-lab-production-spawn-split-spike":
			production_spawn_prewarm = true
			production_spawn_split_spike = true
		elif argument.begins_with("--enemy-lab-production-duration="):
			production_duration_sec = maxf(float(argument.trim_prefix("--enemy-lab-production-duration=")), 1.0)
	if requested_path.is_empty() and production_spawn_level < 0:
		return
	if production_spawn_level < 0 and not _enemy_paths.has(requested_path):
		push_error("Enemy performance lab scene is not part of the production spawn profile: %s" % requested_path)
		get_tree().quit(2)
		return
	_running = true
	_run_button.disabled = true
	_death_button.disabled = true
	_spawn_button.disabled = true
	_all_button.disabled = true
	_cancel_button.disabled = false
	var results: Array[Dictionary] = []
	if production_spawn_level >= 0:
		results.append(await _sample("", 0))
		results.append(await _sample_production_spawn(production_spawn_level, production_spawn_prewarm, production_duration_sec, production_spawn_prewarm_sync, production_spawn_split_spike))
	else:
		for sample in [{"path": "", "count": 0}, {"path": requested_path, "count": requested_count}]:
			var sample_path := str(sample.path)
			var sample_count := int(sample.count)
			var result: Dictionary
			if spawn_burst and not sample_path.is_empty():
				result = await _sample_spawn_burst(sample_path, sample_count)
			elif death_burst and not sample_path.is_empty():
				result = await _sample_death_burst(sample_path, sample_count)
			else:
				result = await _sample(sample_path, sample_count)
			if not result.is_empty():
				results.append(result)
	var report_path := _save_report(results)
	print("ENEMY_PERFORMANCE_REPORT=%s" % report_path)
	await _clear_enemies()
	await _finish_command_line_sample(0 if results.size() == 2 else 1)


func _finish_command_line_sample(exit_code: int) -> void:
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	PhaseManager.cleanup_battle_runtime_transients()
	await TEST_TEARDOWN.finish(_world, exit_code)


func _start_suite(paths: Array[String]) -> void:
	if _running or paths.is_empty():
		return
	_running = true
	_cancelled = false
	_run_button.disabled = true
	_death_button.disabled = true
	_spawn_button.disabled = true
	_all_button.disabled = true
	_cancel_button.disabled = false
	var results: Array[Dictionary] = []
	var total := paths.size() * COUNTS.size() + 1
	var step := 0
	for path in [""] + paths:
		if _cancelled or not is_inside_tree():
			break
		var counts: Array = [0] if path.is_empty() else COUNTS
		for count in counts:
			if _cancelled or not is_inside_tree():
				break
			step += 1
			_status.text = "[%d/%d] %s × %d：准备中" % [step, total, "空场基线" if path.is_empty() else path.get_file().get_basename(), count]
			var result := await _sample(path, count)
			if not is_inside_tree():
				return
			if not result.is_empty():
				results.append(result)
	await _clear_enemies()
	if not is_inside_tree():
		return
	if not _cancelled:
		var report_path := _save_report(results)
		_status.text = "完成 %d 项。报告：%s" % [results.size(), report_path]
		print("ENEMY_PERFORMANCE_REPORT=%s" % report_path)
	else:
		_status.text = "测试已停止；未完成的采样未保存。"
	_running = false
	_run_button.disabled = false
	_death_button.disabled = false
	_spawn_button.disabled = false
	_all_button.disabled = false
	_cancel_button.disabled = true
	suite_stopped.emit()


func _start_death_burst(path: String, count: int) -> void:
	_running = true
	_cancelled = false
	_run_button.disabled = true
	_death_button.disabled = true
	_spawn_button.disabled = true
	_all_button.disabled = true
	_cancel_button.disabled = false
	var result := await _sample_death_burst(path, count)
	await _clear_enemies()
	if not _cancelled and not result.is_empty():
		var report_path := _save_report([result])
		_status.text = "集中死亡测试完成。报告：%s" % report_path
	else:
		_status.text = "集中死亡测试已停止。"
	_running = false
	_run_button.disabled = false
	_death_button.disabled = false
	_spawn_button.disabled = false
	_all_button.disabled = false
	_cancel_button.disabled = true
	suite_stopped.emit()


func _start_spawn_burst(path: String, count: int) -> void:
	_running = true
	_cancelled = false
	_run_button.disabled = true
	_death_button.disabled = true
	_spawn_button.disabled = true
	_all_button.disabled = true
	_cancel_button.disabled = false
	var result := await _sample_spawn_burst(path, count)
	await _clear_enemies()
	if not _cancelled and not result.is_empty():
		var report_path := _save_report([result])
		_status.text = "集中生成测试完成。报告：%s" % report_path
	else:
		_status.text = "集中生成测试已停止。"
	_running = false
	_run_button.disabled = false
	_death_button.disabled = false
	_spawn_button.disabled = false
	_all_button.disabled = false
	_cancel_button.disabled = true
	suite_stopped.emit()


func _sample(path: String, count: int) -> Dictionary:
	await _clear_enemies()
	if _cancelled or not is_inside_tree():
		return {}
	var setup_started := Time.get_ticks_usec()
	var scene := load(path) as PackedScene if not path.is_empty() else null
	if not path.is_empty() and scene == null:
		push_error("Enemy scene unavailable: %s" % path)
		return {}
	for index in count:
		var enemy := scene.instantiate() as BaseEnemy
		if enemy == null:
			continue
		enemy.name = "EnemyPerformanceTarget%03d" % index
		enemy.damage = 0
		enemy.hp = maxi(enemy.hp, 1000000)
		var angle := TAU * float(index) / float(maxi(count, 1))
		var ring := 320.0 + float(index % 5) * 75.0
		enemy.global_position = _player.global_position + Vector2.from_angle(angle) * ring
		enemy.add_to_group(&"enemy_performance_lab_target")
		_world.add_child(enemy)
		if index % 20 == 19:
			await get_tree().process_frame
			if _cancelled or not is_inside_tree():
				return {}
	var setup_ms := float(Time.get_ticks_usec() - setup_started) / 1000.0
	await _wait_seconds(2.0)
	if _cancelled or not is_inside_tree():
		return {}
	var scenario := SCENARIO.new() as WeaponPerformanceScenario
	scenario.scenario_id = "empty_baseline" if path.is_empty() else "%s_%d" % [path.get_file().get_basename(), count]
	scenario.display_name = "空场基线" if path.is_empty() else "%s × %d" % [path.get_file().get_basename(), count]
	scenario.target_count = count
	scenario.real_enemy_count = count
	scenario.fire_pattern = &"none"
	scenario.skill_pattern = &"none"
	EnemyRegistry.reset_query_metrics()
	EnemyRegistry.set_query_profiling_enabled(true)
	EnemySimulationSystem.reset_metrics()
	EnemySimulationSystem.detailed_profiling_enabled = true
	ObjectPool.reset_metrics()
	_collector.begin(scenario, setup_ms)
	_status.text = "%s：采样中" % scenario.display_name
	await _wait_seconds(8.0)
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	if _cancelled or not is_inside_tree():
		_collector.cancel()
		return {}
	var result := _collector.finish({"enemy_scene_path": path, "enemy_label": scenario.display_name, "requested_count": count})
	await _clear_enemies()
	return {} if _cancelled or not is_inside_tree() else result


func _sample_production_spawn(level_index: int, prewarm: bool = false, duration_sec: float = 8.0, prewarm_sync: bool = false, split_spike: bool = false) -> Dictionary:
	await _clear_enemies()
	if _cancelled or not is_inside_tree():
		return {}
	var previous_level := PhaseManager.current_level
	PhaseManager.current_level = level_index
	var prewarm_ms := 0.0
	var prewarm_ready := false
	var prewarm_step_peak_ms := 0.0
	var prewarm_step_peak_path := ""
	var prewarm_frame_peak_ms := 0.0
	var dependency_steps: Array[Dictionary] = []
	var dependency_references: Array[Resource] = []
	if prewarm:
		var prewarm_started := Time.get_ticks_usec()
		if split_spike:
			for dependency_path in SPIKE_SCENE_DEPENDENCIES:
				await get_tree().process_frame
				var dependency_started := Time.get_ticks_usec()
				var dependency := load(dependency_path) as Resource
				var dependency_ms := float(Time.get_ticks_usec() - dependency_started) / 1000.0
				dependency_steps.append({"path": dependency_path, "elapsed_ms": dependency_ms, "loaded": dependency != null})
				if dependency != null:
					dependency_references.append(dependency)
		_spawner.prepare_spawn_scenes_for_level(level_index, prewarm_sync)
		var previous_frame_started := 0
		while not _spawner.are_spawn_scenes_ready_for_level(level_index) and Time.get_ticks_usec() - prewarm_started < 10000000:
			await get_tree().process_frame
			var current_frame_started := Time.get_ticks_usec()
			if previous_frame_started > 0:
				prewarm_frame_peak_ms = maxf(prewarm_frame_peak_ms, float(current_frame_started - previous_frame_started) / 1000.0)
			previous_frame_started = current_frame_started
			var prewarm_step := _spawner.advance_spawn_scene_prewarm()
			if float(prewarm_step.get("elapsed_ms", 0.0)) > prewarm_step_peak_ms:
				prewarm_step_peak_ms = float(prewarm_step.elapsed_ms)
				prewarm_step_peak_path = str(prewarm_step.path)
		prewarm_ms = float(Time.get_ticks_usec() - prewarm_started) / 1000.0
		prewarm_ready = _spawner.are_spawn_scenes_ready_for_level(level_index)
	_spawner.reset_spawn_performance_metrics()
	EnemyRegistry.reset_query_metrics()
	EnemyRegistry.set_query_profiling_enabled(true)
	EnemySimulationSystem.reset_metrics()
	EnemySimulationSystem.detailed_profiling_enabled = true
	ObjectPool.reset_metrics()
	var scenario := SCENARIO.new() as WeaponPerformanceScenario
	scenario.scenario_id = "production_spawn_level_%d" % level_index
	scenario.display_name = "真实刷怪 · 关卡 %d" % level_index
	scenario.fire_pattern = &"production_spawn"
	scenario.skill_pattern = &"none"
	_collector.begin(scenario, 0.0)
	_status.text = "%s：采样中" % scenario.display_name
	_spawner.start_timer()
	await _wait_seconds(duration_sec)
	_spawner.stop_spawning()
	var spawn_metrics := _spawner.get_spawn_performance_metrics()
	var active_count := _spawner.get_active_enemy_count()
	PhaseManager.current_level = previous_level
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	if _cancelled or not is_inside_tree():
		_collector.cancel()
		return {}
	return _collector.finish({
		"enemy_label": scenario.display_name,
		"sample_mode": "production_spawn",
		"level_index": level_index,
		"duration_sec": duration_sec,
		"prewarm_requested": prewarm,
		"prewarm_sync": prewarm_sync,
		"prewarm_ready": prewarm_ready,
		"prewarm_ms": prewarm_ms,
		"prewarm_step_peak_ms": prewarm_step_peak_ms,
		"prewarm_step_peak_path": prewarm_step_peak_path,
		"prewarm_frame_peak_ms": prewarm_frame_peak_ms,
		"split_spike_dependencies": split_spike,
		"dependency_steps": dependency_steps,
		"active_enemy_count_at_end": active_count,
		"spawn_performance": spawn_metrics,
		"measurement_note": "Actual World and EnemySpawner timer, production level spawn data and budget, stationary damage-immune player; eight-second opening sample.",
	})


func _sample_death_burst(path: String, count: int) -> Dictionary:
	await _clear_enemies()
	if _cancelled or not is_inside_tree() or path.is_empty():
		return {}
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Enemy scene unavailable: %s" % path)
		return {}
	var setup_started := Time.get_ticks_usec()
	var targets: Array[BaseEnemy] = []
	for index in count:
		var enemy := scene.instantiate() as BaseEnemy
		if enemy == null:
			continue
		enemy.name = "EnemyDeathBurstTarget%03d" % index
		enemy.damage = 0
		var angle := TAU * float(index) / float(maxi(count, 1))
		var ring := 320.0 + float(index % 5) * 75.0
		enemy.global_position = _player.global_position + Vector2.from_angle(angle) * ring
		enemy.add_to_group(&"enemy_performance_lab_target")
		_world.add_child(enemy)
		targets.append(enemy)
		if index % 20 == 19:
			await get_tree().process_frame
	var setup_ms := float(Time.get_ticks_usec() - setup_started) / 1000.0
	await _wait_seconds(2.0)
	if _cancelled or not is_inside_tree():
		return {}
	var scenario := SCENARIO.new() as WeaponPerformanceScenario
	scenario.scenario_id = "%s_%d_death_burst" % [path.get_file().get_basename(), count]
	scenario.display_name = "%s × %d 同帧死亡" % [path.get_file().get_basename(), count]
	scenario.target_count = count
	scenario.real_enemy_count = count
	scenario.fire_pattern = &"death_burst"
	scenario.skill_pattern = &"none"
	EnemyRegistry.reset_query_metrics()
	EnemyRegistry.set_query_profiling_enabled(true)
	EnemySimulationSystem.reset_metrics()
	EnemySimulationSystem.detailed_profiling_enabled = true
	ObjectPool.reset_metrics()
	_collector.begin(scenario, setup_ms)
	_status.text = "%s：采样中" % scenario.display_name
	await _wait_seconds(0.5)
	if is_instance_valid(_spawner):
		_spawner.ensure_kill_gold_budget_active()
	for enemy in targets:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead:
			enemy.death(null)
	await _wait_seconds(2.0)
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	if _cancelled or not is_inside_tree():
		_collector.cancel()
		return {}
	return _collector.finish({
		"enemy_scene_path": path,
		"enemy_label": scenario.display_name,
		"requested_count": count,
		"sample_mode": "death_burst",
	})


func _sample_spawn_burst(path: String, count: int) -> Dictionary:
	await _clear_enemies()
	if _cancelled or not is_inside_tree() or path.is_empty():
		return {}
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Enemy scene unavailable: %s" % path)
		return {}
	await _wait_seconds(0.5)
	var scenario := SCENARIO.new() as WeaponPerformanceScenario
	scenario.scenario_id = "%s_%d_spawn_burst" % [path.get_file().get_basename(), count]
	scenario.display_name = "%s × %d 同帧生成" % [path.get_file().get_basename(), count]
	scenario.target_count = count
	scenario.real_enemy_count = count
	scenario.fire_pattern = &"spawn_burst"
	scenario.skill_pattern = &"none"
	EnemyRegistry.reset_query_metrics()
	EnemyRegistry.set_query_profiling_enabled(true)
	EnemySimulationSystem.reset_metrics()
	EnemySimulationSystem.detailed_profiling_enabled = true
	ObjectPool.reset_metrics()
	_collector.begin(scenario, 0.0)
	_status.text = "%s：采样中" % scenario.display_name
	var setup_started := Time.get_ticks_usec()
	for index in count:
		var enemy := scene.instantiate() as BaseEnemy
		if enemy == null:
			continue
		enemy.name = "EnemySpawnBurstTarget%03d" % index
		enemy.damage = 0
		var angle := TAU * float(index) / float(maxi(count, 1))
		var ring := 320.0 + float(index % 5) * 75.0
		enemy.global_position = _player.global_position + Vector2.from_angle(angle) * ring
		enemy.prepare_spawn_sequence()
		enemy.add_to_group(&"enemy_performance_lab_target")
		_world.add_child(enemy)
	var setup_ms := float(Time.get_ticks_usec() - setup_started) / 1000.0
	await _wait_seconds(2.0)
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	if _cancelled or not is_inside_tree():
		_collector.cancel()
		return {}
	return _collector.finish({
		"enemy_scene_path": path,
		"enemy_label": scenario.display_name,
		"requested_count": count,
		"sample_mode": "spawn_burst",
		"spawn_call_ms": setup_ms,
		"measurement_note": "Stress case: all enemies instantiate and activate in one frame. Production spawner may also instantiate multiple enemies per timer tick, but defers their activation; compare against its peak_tick_instantiated metric.",
	})


func _wait_seconds(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0 and not _cancelled and is_inside_tree():
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		if _cancelled or not is_inside_tree():
			return
		remaining -= maxf(float(Time.get_ticks_usec() - started) / 1000000.0, 0.0001)


func _clear_enemies() -> void:
	if not is_inside_tree():
		return
	# Mirror clones are not original lab targets, but they must be removed before
	# the next scenario is sampled.
	if is_instance_valid(_spawner):
		_spawner.erase_all_enemies()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().physics_frame


func _save_report(results: Array[Dictionary]) -> String:
	var directory := ProjectSettings.globalize_path(REPORT_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return "保存失败"
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var path := "%s/enemy_performance_%s.json" % [directory, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "保存失败"
	file.store_string(JSON.stringify({"suite_id": "enemy_generator_matrix", "environment": {"engine": Engine.get_version_info(), "time": stamp}, "results": results}, "  "))
	file.close()
	return path


func _return_to_menu() -> void:
	_cancelled = true
	if _running:
		await suite_stopped
	if not is_inside_tree():
		return
	if _player != null and is_instance_valid(_player):
		_player.damage_disabled = false
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	PhaseManager.reset_runtime_state()
	get_tree().change_scene_to_file("res://World/Start.tscn")


func _exit_tree() -> void:
	_cancelled = true
	if _collector != null and is_instance_valid(_collector):
		_collector.cancel()
	if _player != null and is_instance_valid(_player):
		_player.damage_disabled = false
	EnemyRegistry.set_query_profiling_enabled(false)
	EnemySimulationSystem.detailed_profiling_enabled = false
	if _spawner != null and is_instance_valid(_spawner):
		_spawner.stop_spawning()
	PhaseManager.cleanup_battle_runtime_transients()
