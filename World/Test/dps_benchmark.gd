extends Node2D
class_name DpsBenchmark

@export var config: Resource
@export var player_scene: PackedScene = preload("res://Player/Mechas/scenes/Player.tscn")
@export var dummy_scene: PackedScene = preload("res://World/Test/dps_test_dummy_enemy.tscn")

@onready var spawn_root: Node2D = $SpawnRoot
@onready var player_spawn: Marker2D = $SpawnRoot/PlayerSpawn
@onready var single_spawn: Marker2D = $SpawnRoot/SingleSpawn
@onready var aoe_center: Marker2D = $SpawnRoot/AoeCenter
@onready var single_enemies: Node2D = $SpawnRoot/SingleEnemies
@onready var aoe_enemies: Node2D = $SpawnRoot/AoeEnemies

@onready var status_label: Label = $UI/Panel/VBox/StatusLabel
@onready var weapon_label: Label = $UI/Panel/VBox/WeaponLabel
@onready var progress_label: Label = $UI/Panel/VBox/ProgressLabel
@onready var report_label: Label = $UI/Panel/VBox/ReportLabel
@onready var start_button: Button = $UI/Panel/VBox/Buttons/StartButton
@onready var stop_button: Button = $UI/Panel/VBox/Buttons/StopButton
@onready var reset_button: Button = $UI/Panel/VBox/Buttons/ResetButton
@onready var next_button: Button = $UI/Panel/VBox/Buttons/NextCaseButton

var _player: Player
var _results: Array[Dictionary] = []
var _case_queue: Array[Dictionary] = []
var _current_case_index: int = -1

var _running: bool = false
var _stop_requested: bool = false
var _in_test_phase: bool = false
var _elapsed_test_sec: float = 0.0
var _current_total_damage: int = 0
var _current_hit_count: int = 0
var _current_hit_damage_sum: int = 0
var _current_hit_damage_min: int = -1
var _current_hit_damage_max: int = 0
var _current_kill_time_sec: float = -1.0
var _alive_target_ids: Dictionary = {}
var _tracked_dummy_hp: Dictionary = {}
var _current_fire_attempts: int = 0
var _current_fire_success: int = 0
var _current_fire_no_weapon: int = 0
var _current_weapon_id: String = ""
var _current_group_type: String = "single"
var _prev_fire_success: int = 0
var _sim_targets: Array[Dictionary] = []
var _sim_beams: Array[Dictionary] = []

var _last_csv_path: String = ""
var _last_json_path: String = ""
var _current_aim_world_pos: Vector2 = Vector2.ZERO
var _original_time_scale: float = 1.0
var _time_scale_applied: bool = false

func _ready() -> void:
	if config == null:
		config = load("res://data/test/dps_benchmark_default.tres")
	_ensure_weapon_data_loaded()
	_sync_spawn_markers_from_config()
	_spawn_player()
	_bind_ui_buttons()
	_set_status("Idle")
	_update_progress_label("--")
	if config and config.auto_start_on_ready:
		call_deferred("_on_start_pressed")

func _bind_ui_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	next_button.pressed.connect(_on_next_case_pressed)

func _ensure_weapon_data_loaded() -> void:
	if GlobalVariables.weapon_list.is_empty():
		DataHandler.load_weapon_data()

func _sync_spawn_markers_from_config() -> void:
	if config == null:
		return
	player_spawn.global_position = config.player_position
	single_spawn.global_position = config.single_group_position
	aoe_center.global_position = config.aoe_group_center

func _spawn_player() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()
	PlayerData.reset_runtime_state()
	var player_instance := player_scene.instantiate()
	if not (player_instance is Player):
		push_error("dps_benchmark: player_scene is not Player")
		return
	_player = player_instance as Player
	spawn_root.add_child(_player)
	_player.global_position = player_spawn.global_position
	PlayerData.player = _player
	PlayerData.set_hp_safety_for_testing(true)

func _on_start_pressed() -> void:
	if _running:
		return
	_stop_requested = false
	_results.clear()
	_case_queue = config.build_case_queue() if config else []
	_current_case_index = -1
	_run_full_benchmark()

func _on_stop_pressed() -> void:
	if not _running:
		return
	_stop_requested = true
	_set_status("Stopping...")

func _on_reset_pressed() -> void:
	_stop_requested = true
	_running = false
	_in_test_phase = false
	Input.action_release("ATTACK")
	_restore_benchmark_time_scale()
	_cleanup_spawned_targets()
	_results.clear()
	_current_case_index = -1
	_last_csv_path = ""
	_last_json_path = ""
	report_label.text = "Report: --"
	_spawn_player()
	_set_status("Idle")
	weapon_label.text = "Weapon: --"
	_update_progress_label("--")

func _on_next_case_pressed() -> void:
	if _running:
		return
	if config == null:
		return
	if _case_queue.is_empty():
		_case_queue = config.build_case_queue()
	if _case_queue.is_empty():
		_set_status("No test cases in config")
		return
	_stop_requested = false
	var next_idx := clampi(_current_case_index + 1, 0, _case_queue.size() - 1)
	_run_single_case_entry(next_idx)

func _run_full_benchmark() -> void:
	if config == null:
		_set_status("Config missing")
		return
	if _case_queue.is_empty():
		_set_status("No test cases in config")
		return
	if _player == null or not is_instance_valid(_player):
		_spawn_player()
	_apply_benchmark_time_scale()
	_running = true
	_set_status("Running full benchmark")
	await get_tree().physics_frame
	for i in range(_case_queue.size()):
		if _stop_requested:
			break
		_current_case_index = i
		await _run_case(_case_queue[i], i + 1, _case_queue.size())
		if _stop_requested:
			break
		await get_tree().create_timer(0.25).timeout
	_running = false
	_in_test_phase = false
	Input.action_release("ATTACK")
	_restore_benchmark_time_scale()
	_write_reports()
	if _stop_requested:
		_set_status("Stopped")
	else:
		_set_status("Completed")
	if config and config.get("quit_on_completion") == true:
		get_tree().quit(0)

func _run_single_case_entry(case_index: int) -> void:
	if case_index < 0 or case_index >= _case_queue.size():
		return
	if _player == null or not is_instance_valid(_player):
		_spawn_player()
	_apply_benchmark_time_scale()
	_running = true
	_set_status("Running one case")
	await _run_case(_case_queue[case_index], case_index + 1, _case_queue.size())
	_running = false
	_in_test_phase = false
	Input.action_release("ATTACK")
	_restore_benchmark_time_scale()
	_write_reports()
	if _stop_requested:
		_set_status("Stopped")
	else:
		_set_status("Completed one case")

func _run_case(case_data: Dictionary, order_idx: int, total_cases: int) -> void:
	_prepare_case(case_data)
	var weapon_id := str(case_data.get("weapon_id", ""))
	var group_type := str(case_data.get("group_type", "single"))
	var round_idx := int(case_data.get("round", 1))
	weapon_label.text = "Weapon %s | Group %s | Round %d" % [weapon_id, group_type, round_idx]

	var warmup_left := maxf(config.warmup_sec, 0.0)
	while warmup_left > 0.0:
		if _stop_requested:
			return
		_update_mouse_aim()
		_trigger_main_weapon_fire()
		await get_tree().physics_frame
		var delta := maxf(get_physics_process_delta_time(), 0.001)
		_simulate_headless_step(delta, false)
		warmup_left -= delta
		_update_progress_label("Case %d/%d | Warmup %.2fs" % [order_idx, total_cases, maxf(warmup_left, 0.0)])

	_reset_sim_targets_for_measurement()
	_in_test_phase = true
	_elapsed_test_sec = 0.0
	_current_total_damage = 0
	_current_hit_count = 0
	_current_hit_damage_sum = 0
	_current_hit_damage_min = -1
	_current_hit_damage_max = 0
	_current_kill_time_sec = -1.0
	_current_fire_attempts = 0
	_current_fire_success = 0
	_current_fire_no_weapon = 0
	_prev_fire_success = 0
	_sim_beams.clear()

	var duration := maxf(config.test_duration_sec, 0.1)
	while _elapsed_test_sec < duration:
		if _stop_requested:
			break
		_update_mouse_aim()
		_trigger_main_weapon_fire()
		await get_tree().physics_frame
		var delta := maxf(get_physics_process_delta_time(), 0.001)
		_simulate_headless_step(delta, true)
		_elapsed_test_sec += delta
		_update_progress_label("Case %d/%d | Test %.2f/%.2fs" % [order_idx, total_cases, minf(_elapsed_test_sec, duration), duration])

	_in_test_phase = false
	Input.action_release("ATTACK")

	var measured_duration := _elapsed_test_sec if _elapsed_test_sec > 0.0 else duration
	var result := _build_result(case_data, measured_duration)
	_results.append(result)
	_cleanup_spawned_targets()

func _prepare_case(case_data: Dictionary) -> void:
	_cleanup_spawned_targets()
	_sync_spawn_markers_from_config()
	_ensure_battle_phase_for_test()
	_current_weapon_id = str(case_data.get("weapon_id", ""))
	_current_group_type = str(case_data.get("group_type", "single"))
	if _player == null or not is_instance_valid(_player):
		_spawn_player()
	_player.global_position = player_spawn.global_position
	_equip_weapon(_current_weapon_id)
	_spawn_targets(_current_group_type)
	_update_aim_target(_current_group_type)

func _ensure_battle_phase_for_test() -> void:
	if PhaseManager == null or not PhaseManager.has_method("current_state"):
		return
	if str(PhaseManager.current_state()) == str(PhaseManager.BATTLE):
		return
	if PhaseManager.has_method("enter_battle"):
		PhaseManager.enter_battle()

func _equip_weapon(weapon_id: String) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon_node := weapon_ref as Node
		if weapon_node and is_instance_valid(weapon_node):
			weapon_node.queue_free()
	PlayerData.player_weapon_list.clear()
	PlayerData.main_weapon_index = -1
	PlayerData.on_select_weapon = -1
	_player.create_weapon(weapon_id, config.weapon_level)
	PlayerData.set_main_weapon_index(0)
	_apply_benchmark_aim_meta()

func _spawn_targets(group_type: String) -> void:
	_alive_target_ids.clear()
	if group_type == "aoe":
		var count := maxi(config.aoe_target_count, 1)
		_current_aim_world_pos = aoe_center.global_position
		for i in range(count):
			var angle := TAU * float(i) / float(count)
			var pos: Vector2 = aoe_center.global_position + Vector2.RIGHT.rotated(angle) * config.aoe_cluster_radius
			_spawn_one_dummy(pos, config.aoe_target_hp, aoe_enemies)
		return
	_current_aim_world_pos = single_spawn.global_position
	_spawn_one_dummy(single_spawn.global_position, config.single_target_hp, single_enemies)

func _spawn_one_dummy(pos: Vector2, hp_value: int, parent_node: Node) -> void:
	var dummy_instance := dummy_scene.instantiate()
	var dummy := dummy_instance as Node2D
	if dummy == null:
		push_warning("dps_benchmark: dummy_scene is not Node2D")
		return
	if dummy.get("max_hp_value") != null:
		dummy.set("max_hp_value", max(1, hp_value))
	parent_node.add_child(dummy)
	dummy.global_position = pos
	if dummy.has_signal("damage_received"):
		dummy.connect("damage_received", Callable(self, "_on_dummy_damage_received"))
	if dummy.has_signal("dummy_died"):
		dummy.connect("dummy_died", Callable(self, "_on_dummy_died"))
	_alive_target_ids[dummy.get_instance_id()] = true
	var hp_variant: Variant = dummy.get("hp")
	var start_hp: int = int(hp_variant) if hp_variant != null else max(1, hp_value)
	_tracked_dummy_hp[dummy.get_instance_id()] = start_hp
	_sim_targets.append({
		"node_id": dummy.get_instance_id(),
		"position": pos,
		"hp": start_hp,
		"max_hp": start_hp,
		"alive": true,
	})

func _on_dummy_damage_received(dummy: Node, amount: int, attack: Attack, hp_after: int) -> void:
	if config and config.get("script_hit_simulation") == true:
		return
	if not _in_test_phase:
		return
	if dummy == null or not is_instance_valid(dummy):
		return
	if attack != null:
		if attack.source_player != null and attack.source_player != _player:
			return
	_record_hit_damage(amount)
	if hp_after <= 0 and _alive_target_ids.has(dummy.get_instance_id()):
		_alive_target_ids.erase(dummy.get_instance_id())
		if _alive_target_ids.is_empty() and _current_kill_time_sec < 0.0:
			_current_kill_time_sec = _elapsed_test_sec

func _on_dummy_died(dummy: Node, _killing_attack: Attack) -> void:
	if config and config.get("script_hit_simulation") == true:
		return
	if dummy == null:
		return
	if _alive_target_ids.has(dummy.get_instance_id()):
		_alive_target_ids.erase(dummy.get_instance_id())
	if _in_test_phase and _alive_target_ids.is_empty() and _current_kill_time_sec < 0.0:
		_current_kill_time_sec = _elapsed_test_sec

func _build_result(case_data: Dictionary, duration: float) -> Dictionary:
	var group_type := str(case_data.get("group_type", "single"))
	var target_count := 1 if group_type == "single" else maxi(config.aoe_target_count, 1)
	var normalized_duration := maxf(duration, 0.001)
	var dps := float(_current_total_damage) / normalized_duration
	var hit_damage_avg: float = 0.0
	if _current_hit_count > 0:
		hit_damage_avg = float(_current_hit_damage_sum) / float(_current_hit_count)
	var quality := _assess_result_quality(_current_fire_attempts, _current_fire_success, _current_hit_count)
	return {
		"weapon_id": str(case_data.get("weapon_id", "")),
		"weapon_name": _resolve_weapon_name(str(case_data.get("weapon_id", ""))),
		"weapon_level": config.weapon_level,
		"group_type": group_type,
		"round": int(case_data.get("round", 1)),
		"total_damage": _current_total_damage,
		"hit_damage_avg": snapped(hit_damage_avg, 0.001),
		"hit_damage_min": max(0, _current_hit_damage_min),
		"hit_damage_max": _current_hit_damage_max,
		"duration_sec": snapped(normalized_duration, 0.001),
		"dps": snapped(dps, 0.001),
		"hit_count": _current_hit_count,
		"kill_time_sec": snapped(_current_kill_time_sec, 0.001) if _current_kill_time_sec >= 0.0 else -1.0,
		"target_count": target_count,
		"fire_attempts": _current_fire_attempts,
		"fire_success": _current_fire_success,
		"fire_no_weapon": _current_fire_no_weapon,
		"data_quality": str(quality.get("quality", "ok")),
		"quality_reason": str(quality.get("reason", "")),
		"timestamp": Time.get_datetime_string_from_system(true, true),
	}

func _cleanup_spawned_targets() -> void:
	for child in single_enemies.get_children():
		child.queue_free()
	for child in aoe_enemies.get_children():
		child.queue_free()
	_alive_target_ids.clear()
	_tracked_dummy_hp.clear()
	_sim_targets.clear()
	_sim_beams.clear()
	_current_aim_world_pos = Vector2.ZERO

func _write_reports() -> void:
	if _results.is_empty() or config == null:
		return
	_ensure_report_dir(config.report_dir)
	var stamp := _build_file_stamp()
	var csv_path := "%s/%s_%s.csv" % [config.report_dir, config.report_file_prefix, stamp]
	var json_path := "%s/%s_%s.json" % [config.report_dir, config.report_file_prefix, stamp]
	_write_csv(csv_path)
	_write_json(json_path)
	var summary_path := ""
	if _cfg_bool("generate_summary_report", true):
		summary_path = "%s/%s_%s_summary.csv" % [config.report_dir, config.report_file_prefix, stamp]
		_write_summary_csv(summary_path)
	var regression_path := ""
	if _cfg_bool("regression_check_enabled", true):
		regression_path = "%s/%s_%s_regression_report.json" % [config.report_dir, config.report_file_prefix, stamp]
		_write_regression_report(regression_path)
	_last_csv_path = csv_path
	_last_json_path = json_path
	var label_parts: Array[String] = [csv_path, json_path]
	if summary_path != "":
		label_parts.append(summary_path)
	if regression_path != "":
		label_parts.append(regression_path)
	report_label.text = "Report: %s" % " | ".join(label_parts)

func _ensure_report_dir(dir_path: String) -> void:
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(absolute_dir)

func _build_file_stamp() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]

func _write_csv(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("dps_benchmark: failed to open csv %s" % path)
		return
	var header := [
		"weapon_id",
		"weapon_name",
		"weapon_level",
		"group_type",
		"round",
		"total_damage",
		"hit_damage_avg",
		"hit_damage_min",
		"hit_damage_max",
		"duration_sec",
		"dps",
		"hit_count",
		"kill_time_sec",
		"target_count",
		"fire_attempts",
		"fire_success",
		"fire_no_weapon",
		"data_quality",
		"quality_reason",
		"timestamp",
	]
	file.store_line(",".join(header))
	for row in _results:
		var columns: Array[String] = []
		for key in header:
			columns.append(str(row.get(key, "")))
		file.store_line(",".join(columns))
	file.flush()
	file.close()

func _write_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("dps_benchmark: failed to open json %s" % path)
		return
	file.store_string(JSON.stringify(_results, "\t"))
	file.flush()
	file.close()

func _set_status(message: String) -> void:
	status_label.text = "Status: %s" % message

func _update_progress_label(message: String) -> void:
	progress_label.text = "Progress: %s" % message

func _update_aim_target(group_type: String) -> void:
	if group_type == "aoe":
		_current_aim_world_pos = aoe_center.global_position
		_apply_benchmark_aim_meta()
		return
	_current_aim_world_pos = single_spawn.global_position
	_apply_benchmark_aim_meta()

func _update_mouse_aim() -> void:
	if config == null or not config.force_mouse_to_target:
		return
	if _current_aim_world_pos == Vector2.ZERO:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var canvas_pos: Vector2 = viewport.get_canvas_transform() * _current_aim_world_pos
	Input.warp_mouse(canvas_pos)

func _apply_benchmark_aim_meta() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.set_meta("_benchmark_mouse_target", _current_aim_world_pos)
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon_node := weapon_ref as Node
		if weapon_node == null or not is_instance_valid(weapon_node):
			continue
		weapon_node.set_meta("_benchmark_mouse_target", _current_aim_world_pos)

func _trigger_main_weapon_fire() -> void:
	if _player == null or not is_instance_valid(_player):
		_current_fire_no_weapon += 1
		return
	var main_weapon: Variant = _player.get_main_weapon()
	if main_weapon == null or not is_instance_valid(main_weapon):
		_current_fire_no_weapon += 1
		return
	_current_fire_attempts += 1
	if main_weapon.has_method("request_primary_fire"):
		var ok_variant: Variant = main_weapon.call("request_primary_fire")
		if bool(ok_variant):
			_current_fire_success += 1

func _reset_sim_targets_for_measurement() -> void:
	for i in range(_sim_targets.size()):
		var entry: Dictionary = _sim_targets[i]
		entry["hp"] = int(entry.get("max_hp", 1))
		entry["alive"] = true
		_sim_targets[i] = entry
		var node_id: int = int(entry.get("node_id", 0))
		_alive_target_ids[node_id] = true
		_tracked_dummy_hp[node_id] = int(entry.get("max_hp", 1))
		for node in _all_target_nodes():
			if node != null and is_instance_valid(node) and node.get_instance_id() == node_id:
				if node.get("hp") != null:
					node.set("hp", int(entry.get("max_hp", 1)))
				if node.get("is_dead") != null:
					node.set("is_dead", false)
				break

func _simulate_headless_step(delta: float, record_damage: bool) -> void:
	if config == null or config.get("script_hit_simulation") != true:
		return
	var new_shots: int = max(0, _current_fire_success - _prev_fire_success)
	_prev_fire_success = _current_fire_success
	for _i in range(new_shots):
		_simulate_weapon_shot(record_damage)
	_update_sim_beams(delta, record_damage)

func _simulate_weapon_shot(record_damage: bool) -> void:
	var main_weapon := _resolve_main_weapon_node()
	if main_weapon == null:
		return
	var base_damage: int = _get_runtime_damage_from_weapon(main_weapon)
	var start: Vector2 = _player.global_position
	var dir: Vector2 = (start.direction_to(_current_aim_world_pos)).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var weapon_id := _current_weapon_id
	match weapon_id:
		"4":
			_simulate_shotgun_shot(start, dir, base_damage, main_weapon, record_damage)
		"8":
			_simulate_single_ray_shot(start, dir, base_damage, main_weapon, record_damage, true)
		"9":
			_spawn_sim_beam(start, dir, base_damage, main_weapon, false)
		"21":
			_simulate_glacier_cone_shot(start, dir, base_damage, main_weapon, record_damage)
		"2":
			_spawn_sim_beam(start, dir, base_damage, main_weapon, true)
		_:
			_simulate_single_ray_shot(start, dir, base_damage, main_weapon, record_damage, false)

func _simulate_single_ray_shot(
	start: Vector2,
	dir: Vector2,
	damage_value: int,
	main_weapon: Node,
	record_damage: bool,
	with_splash: bool
) -> void:
	var max_range: float = _resolve_weapon_range(main_weapon, 1200.0)
	var end: Vector2 = start + dir * max_range
	var hit_index: int = _find_first_target_on_segment(start, end, _cfg_float("sim_target_hit_radius", 18.0))
	if hit_index < 0:
		return
	var impact_pos: Vector2 = _get_target_pos(hit_index)
	_apply_sim_damage(hit_index, damage_value, record_damage)
	if with_splash:
		var splash_radius: float = _resolve_rocket_splash_radius(main_weapon)
		_apply_sim_splash_damage(impact_pos, splash_radius, int(round(float(damage_value) * 0.8)), record_damage, hit_index)

func _simulate_shotgun_shot(start: Vector2, dir: Vector2, damage_value: int, main_weapon: Node, record_damage: bool) -> void:
	var pellet_count: int = max(1, int(main_weapon.get("bullet_count")) if main_weapon.get("bullet_count") != null else 7)
	var spread_deg: float = 24.0
	if main_weapon.get("arc") != null:
		spread_deg = maxf(absf(float(main_weapon.get("arc"))), 12.0)
	var max_range: float = _resolve_weapon_range(main_weapon, 700.0)
	var spread_rad: float = deg_to_rad(spread_deg)
	var start_offset: float = -spread_rad * 0.5
	var step: float = spread_rad / maxf(float(max(1, pellet_count - 1)), 1.0)
	for i in range(pellet_count):
		var shot_dir := dir.rotated(start_offset + step * float(i)).normalized()
		var end := start + shot_dir * max_range
		var hit_index := _find_first_target_on_segment(start, end, _cfg_float("sim_target_hit_radius", 18.0))
		if hit_index >= 0:
			_apply_sim_damage(hit_index, damage_value, record_damage)

func _simulate_glacier_cone_shot(start: Vector2, dir: Vector2, damage_value: int, main_weapon: Node, record_damage: bool) -> void:
	var max_range: float = _resolve_weapon_range(main_weapon, 350.0)
	var half_angle_deg: float = 38.0
	if main_weapon.get("cone_half_angle_deg") != null:
		half_angle_deg = float(main_weapon.get("cone_half_angle_deg"))
	var half_angle_rad: float = deg_to_rad(maxf(half_angle_deg, 1.0))
	for i in range(_sim_targets.size()):
		if not _is_target_alive(i):
			continue
		var to_target: Vector2 = _get_target_pos(i) - start
		if to_target.length() > max_range:
			continue
		var ndir := to_target.normalized()
		if absf(dir.angle_to(ndir)) > half_angle_rad:
			continue
		_apply_sim_damage(i, damage_value, record_damage)

func _spawn_sim_beam(start: Vector2, dir: Vector2, damage_value: int, main_weapon: Node, charged: bool) -> void:
	var beam_duration: float = 0.2
	var tick_hz: float = maxf(_cfg_float("sim_beam_tick_hz", 30.0), 1.0)
	var beam_range: float = _resolve_weapon_range(main_weapon, 1200.0)
	if charged:
		beam_duration = maxf(float(main_weapon.get("duration")) if main_weapon.get("duration") != null else 3.0, 0.1)
		beam_range = maxf(float(main_weapon.get("beam_range")) if main_weapon.get("beam_range") != null else 450.0, 50.0)
		var charge_level: int = int(main_weapon.get("charge_level")) if main_weapon.get("charge_level") != null else 1
		damage_value = max(1, damage_value * max(1, charge_level))
	_sim_beams.append({
		"start": start,
		"dir": dir,
		"range": beam_range,
		"damage": max(1, damage_value),
		"remaining": beam_duration,
		"tick_interval": 1.0 / tick_hz,
		"tick_left": 0.0,
	})

func _update_sim_beams(delta: float, record_damage: bool) -> void:
	if _sim_beams.is_empty():
		return
	var kept: Array[Dictionary] = []
	for beam in _sim_beams:
		var remaining: float = float(beam.get("remaining", 0.0)) - delta
		var tick_left: float = float(beam.get("tick_left", 0.0)) - delta
		while tick_left <= 0.0 and remaining > 0.0:
			_simulate_beam_tick(beam, record_damage)
			tick_left += maxf(float(beam.get("tick_interval", 0.05)), 0.005)
		if remaining > 0.0:
			beam["remaining"] = remaining
			beam["tick_left"] = tick_left
			kept.append(beam)
	_sim_beams = kept

func _simulate_beam_tick(beam: Dictionary, record_damage: bool) -> void:
	var start: Vector2 = beam.get("start", Vector2.ZERO)
	var dir: Vector2 = beam.get("dir", Vector2.UP)
	var range_value: float = float(beam.get("range", 1000.0))
	var end := start + dir * range_value
	var hit_index := _find_first_target_on_segment(start, end, _cfg_float("sim_target_hit_radius", 18.0))
	if hit_index < 0:
		return
	_apply_sim_damage(hit_index, int(beam.get("damage", 1)), record_damage)

func _apply_sim_splash_damage(
	center: Vector2,
	radius: float,
	damage_value: int,
	record_damage: bool,
	ignore_idx: int = -1
) -> void:
	var r2 := radius * radius
	for i in range(_sim_targets.size()):
		if i == ignore_idx or not _is_target_alive(i):
			continue
		if _get_target_pos(i).distance_squared_to(center) <= r2:
			_apply_sim_damage(i, damage_value, record_damage)

func _apply_sim_damage(target_idx: int, damage_value: int, record_damage: bool) -> void:
	if not record_damage:
		return
	if target_idx < 0 or target_idx >= _sim_targets.size():
		return
	var entry: Dictionary = _sim_targets[target_idx]
	if not bool(entry.get("alive", true)):
		return
	var dmg: int = max(0, damage_value)
	if dmg <= 0:
		return
	var hp_before: int = int(entry.get("hp", 0))
	var hp_after: int = max(0, hp_before - dmg)
	var dealt: int = hp_before - hp_after
	if dealt <= 0:
		return
	entry["hp"] = hp_after
	if hp_after <= 0:
		entry["alive"] = false
		var node_id: int = int(entry.get("node_id", 0))
		if _alive_target_ids.has(node_id):
			_alive_target_ids.erase(node_id)
		if _all_sim_targets_dead() and _current_kill_time_sec < 0.0:
			_current_kill_time_sec = _elapsed_test_sec
	_sim_targets[target_idx] = entry
	_record_hit_damage(dealt)

func _record_hit_damage(amount: int) -> void:
	var dealt: int = max(0, amount)
	if dealt <= 0:
		return
	_current_total_damage += dealt
	_current_hit_count += 1
	_current_hit_damage_sum += dealt
	if _current_hit_damage_min < 0 or dealt < _current_hit_damage_min:
		_current_hit_damage_min = dealt
	if dealt > _current_hit_damage_max:
		_current_hit_damage_max = dealt

func _all_sim_targets_dead() -> bool:
	for i in range(_sim_targets.size()):
		if _is_target_alive(i):
			return false
	return not _sim_targets.is_empty()

func _resolve_main_weapon_node() -> Node:
	if _player == null or not is_instance_valid(_player):
		return null
	var main_weapon: Variant = _player.get_main_weapon()
	if main_weapon == null or not is_instance_valid(main_weapon):
		return null
	return main_weapon as Node

func _get_runtime_damage_from_weapon(main_weapon: Node) -> int:
	if main_weapon.has_method("get_runtime_shot_damage"):
		return max(1, int(main_weapon.call("get_runtime_shot_damage")))
	var damage_variant: Variant = main_weapon.get("damage")
	if damage_variant != null:
		return max(1, int(damage_variant))
	return 1

func _resolve_weapon_range(main_weapon: Node, fallback: float) -> float:
	if main_weapon.get("attack_range") != null:
		return maxf(float(main_weapon.get("attack_range")), 1.0)
	if main_weapon.get("beam_range") != null:
		return maxf(float(main_weapon.get("beam_range")), 1.0)
	return maxf(fallback, 1.0)

func _resolve_rocket_splash_radius(main_weapon: Node) -> float:
	var scale: float = 2.0
	if main_weapon.get("explosion_scale") != null:
		scale = maxf(float(main_weapon.get("explosion_scale")), 0.1)
	return 26.0 * scale

func _find_first_target_on_segment(start: Vector2, end: Vector2, hit_radius: float) -> int:
	var best_idx: int = -1
	var best_dist2: float = INF
	for i in range(_sim_targets.size()):
		if not _is_target_alive(i):
			continue
		var target_pos := _get_target_pos(i)
		var seg_dist := Geometry2D.get_closest_point_to_segment(target_pos, start, end).distance_to(target_pos)
		if seg_dist > hit_radius:
			continue
		var d2 := start.distance_squared_to(target_pos)
		if d2 < best_dist2:
			best_dist2 = d2
			best_idx = i
	return best_idx

func _is_target_alive(idx: int) -> bool:
	if idx < 0 or idx >= _sim_targets.size():
		return false
	return bool(_sim_targets[idx].get("alive", false))

func _get_target_pos(idx: int) -> Vector2:
	if idx < 0 or idx >= _sim_targets.size():
		return Vector2.ZERO
	return _sim_targets[idx].get("position", Vector2.ZERO)

func _cfg_float(key: String, fallback: float) -> float:
	if config == null:
		return fallback
	var value: Variant = config.get(key)
	if value == null:
		return fallback
	return float(value)

func _cfg_bool(key: String, fallback: bool) -> bool:
	if config == null:
		return fallback
	var value: Variant = config.get(key)
	if value == null:
		return fallback
	return bool(value)

func _cfg_int(key: String, fallback: int) -> int:
	if config == null:
		return fallback
	var value: Variant = config.get(key)
	if value == null:
		return fallback
	return int(value)

func _cfg_dict(key: String) -> Dictionary:
	if config == null:
		return {}
	var value: Variant = config.get(key)
	if value == null or not (value is Dictionary):
		return {}
	return value as Dictionary

func _resolve_weapon_name(weapon_id: String) -> String:
	var def: Variant = DataHandler.read_weapon_data(weapon_id)
	if def == null:
		return "unknown"
	var localized := LocalizationManager.get_weapon_name_from_definition(def)
	if localized != "":
		return localized
	var display_variant: Variant = def.get("display_name")
	if display_variant != null and str(display_variant) != "":
		return str(display_variant)
	return "weapon_%s" % weapon_id

func _apply_benchmark_time_scale() -> void:
	if _time_scale_applied:
		return
	if not _cfg_bool("accelerated_mode", false):
		return
	_original_time_scale = Engine.time_scale
	var scale: float = _cfg_float("simulation_time_scale", 1.0)
	Engine.time_scale = clampf(scale, 0.1, 32.0)
	_time_scale_applied = true

func _restore_benchmark_time_scale() -> void:
	if not _time_scale_applied:
		return
	Engine.time_scale = _original_time_scale
	_time_scale_applied = false

func _assess_result_quality(fire_attempts: int, fire_success: int, hit_count: int) -> Dictionary:
	if fire_attempts <= 0:
		return {"quality": "invalid", "reason": "no_fire_attempts"}
	var success_ratio := float(fire_success) / float(max(1, fire_attempts))
	var min_ratio := clampf(_cfg_float("min_fire_success_ratio", 0.03), 0.0, 1.0)
	if success_ratio < min_ratio:
		return {"quality": "low_confidence", "reason": "low_fire_success_ratio"}
	var min_hits: int = maxi(0, _cfg_int("min_hit_count", 1))
	if hit_count < min_hits:
		return {"quality": "low_confidence", "reason": "low_hit_count"}
	return {"quality": "ok", "reason": ""}

func _write_summary_csv(path: String) -> void:
	var grouped: Dictionary = _group_results_by_weapon_and_group()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("dps_benchmark: failed to open summary csv %s" % path)
		return
	var header := [
		"weapon_id",
		"weapon_name",
		"group_type",
		"rounds",
		"dps_avg",
		"dps_min",
		"dps_max",
		"dps_std",
		"total_damage_avg",
		"total_damage_min",
		"total_damage_max",
		"hit_damage_avg",
		"hit_damage_min",
		"hit_damage_max",
		"hit_count_avg",
		"fire_success_avg",
		"quality_ok_count",
		"quality_low_confidence_count",
		"quality_invalid_count",
	]
	file.store_line(",".join(header))
	for key in grouped.keys():
		var rows: Array = grouped[key]
		if rows.is_empty():
			continue
		var sample: Dictionary = rows[0]
		var dps_values: Array[float] = _extract_float_values(rows, "dps")
		var dmg_values: Array[float] = _extract_float_values(rows, "total_damage")
		var per_hit_avg_values: Array[float] = _extract_float_values(rows, "hit_damage_avg")
		var per_hit_min_values: Array[float] = _extract_float_values(rows, "hit_damage_min")
		var per_hit_max_values: Array[float] = _extract_float_values(rows, "hit_damage_max")
		var hit_values: Array[float] = _extract_float_values(rows, "hit_count")
		var fire_success_values: Array[float] = _extract_float_values(rows, "fire_success")
		var quality_counts: Dictionary = _count_quality(rows)
		var line := [
			str(sample.get("weapon_id", "")),
			str(sample.get("weapon_name", "")),
			str(sample.get("group_type", "")),
			str(rows.size()),
			str(snapped(_mean(dps_values), 0.001)),
			str(snapped(_min_value(dps_values), 0.001)),
			str(snapped(_max_value(dps_values), 0.001)),
			str(snapped(_stddev(dps_values), 0.001)),
			str(snapped(_mean(dmg_values), 0.001)),
			str(snapped(_min_value(dmg_values), 0.001)),
			str(snapped(_max_value(dmg_values), 0.001)),
			str(snapped(_mean(per_hit_avg_values), 0.001)),
			str(snapped(_min_value(per_hit_min_values), 0.001)),
			str(snapped(_max_value(per_hit_max_values), 0.001)),
			str(snapped(_mean(hit_values), 0.001)),
			str(snapped(_mean(fire_success_values), 0.001)),
			str(int(quality_counts.get("ok", 0))),
			str(int(quality_counts.get("low_confidence", 0))),
			str(int(quality_counts.get("invalid", 0))),
		]
		file.store_line(",".join(line))
	file.flush()
	file.close()

func _write_regression_report(path: String) -> void:
	var grouped: Dictionary = _group_results_by_weapon_and_group()
	var expected_ranges: Dictionary = _cfg_dict("expected_dps_ranges")
	var checks: Array[Dictionary] = []
	var overall_status: String = "pass"
	for key in grouped.keys():
		var rows: Array = grouped[key]
		if rows.is_empty():
			continue
		var sample: Dictionary = rows[0]
		var weapon_id: String = str(sample.get("weapon_id", ""))
		var group_type: String = str(sample.get("group_type", ""))
		var dps_values: Array[float] = _extract_float_values(rows, "dps")
		var mean_dps: float = _mean(dps_values)
		var expected_value: Variant = expected_ranges.get(weapon_id, {})
		var expected_dict: Dictionary = expected_value if expected_value is Dictionary else {}
		var min_key: String = "%s_min" % group_type
		var max_key: String = "%s_max" % group_type
		var has_min: bool = expected_dict.has(min_key)
		var has_max: bool = expected_dict.has(max_key)
		var min_dps := float(expected_dict.get(min_key, 0.0))
		var max_dps := float(expected_dict.get(max_key, 0.0))
		var status: String = "skip"
		var reason: String = "no_threshold"
		if has_min and has_max:
			if mean_dps < min_dps:
				status = "fail"
				reason = "below_min"
				overall_status = "fail"
			elif mean_dps > max_dps:
				status = "fail"
				reason = "above_max"
				overall_status = "fail"
			else:
				status = "pass"
				reason = ""
		checks.append({
			"weapon_id": weapon_id,
			"weapon_name": str(sample.get("weapon_name", "")),
			"group_type": group_type,
			"rounds": rows.size(),
			"dps_avg": snapped(mean_dps, 0.001),
			"expected_min": min_dps if has_min else null,
			"expected_max": max_dps if has_max else null,
			"status": status,
			"reason": reason,
		})
	var payload := {
		"status": overall_status,
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"checks": checks,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("dps_benchmark: failed to open regression json %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	file.close()

func _group_results_by_weapon_and_group() -> Dictionary:
	var grouped: Dictionary = {}
	for row in _results:
		var key := "%s|%s" % [str(row.get("weapon_id", "")), str(row.get("group_type", ""))]
		if not grouped.has(key):
			grouped[key] = []
		var rows: Array = grouped[key]
		rows.append(row)
		grouped[key] = rows
	return grouped

func _extract_float_values(rows: Array, key: String) -> Array[float]:
	var values: Array[float] = []
	for row in rows:
		if row is Dictionary:
			values.append(float((row as Dictionary).get(key, 0.0)))
	return values

func _count_quality(rows: Array) -> Dictionary:
	var counts := {"ok": 0, "low_confidence": 0, "invalid": 0}
	for row in rows:
		if not (row is Dictionary):
			continue
		var quality := str((row as Dictionary).get("data_quality", "ok"))
		if not counts.has(quality):
			counts[quality] = 0
		counts[quality] = int(counts[quality]) + 1
	return counts

func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / float(values.size())

func _stddev(values: Array[float]) -> float:
	if values.size() <= 1:
		return 0.0
	var avg := _mean(values)
	var acc := 0.0
	for v in values:
		var d := v - avg
		acc += d * d
	return sqrt(acc / float(values.size()))

func _min_value(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var min_v := values[0]
	for v in values:
		if v < min_v:
			min_v = v
	return min_v

func _max_value(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var max_v := values[0]
	for v in values:
		if v > max_v:
			max_v = v
	return max_v

func _all_target_nodes() -> Array:
	var merged_nodes: Array = []
	merged_nodes.append_array(single_enemies.get_children())
	merged_nodes.append_array(aoe_enemies.get_children())
	return merged_nodes

func _poll_dummy_hp_changes(count_hits: bool) -> void:
	if config and config.get("script_hit_simulation") == true:
		return
	if _tracked_dummy_hp.is_empty():
		return
	var merged_nodes: Array = []
	merged_nodes.append_array(single_enemies.get_children())
	merged_nodes.append_array(aoe_enemies.get_children())
	for node in merged_nodes:
		if node == null or not is_instance_valid(node):
			continue
		var id: int = node.get_instance_id()
		if not _tracked_dummy_hp.has(id):
			continue
		var hp_variant: Variant = node.get("hp")
		if hp_variant == null:
			continue
		var current_hp := int(hp_variant)
		var prev_hp := int(_tracked_dummy_hp[id])
		if current_hp < prev_hp:
			var delta_damage: int = max(0, prev_hp - current_hp)
			_current_total_damage += delta_damage
			if count_hits:
				_current_hit_count += 1
				_current_hit_damage_sum += delta_damage
				if _current_hit_damage_min < 0 or delta_damage < _current_hit_damage_min:
					_current_hit_damage_min = delta_damage
				if delta_damage > _current_hit_damage_max:
					_current_hit_damage_max = delta_damage
			_tracked_dummy_hp[id] = current_hp
			if current_hp <= 0 and _alive_target_ids.has(id):
				_alive_target_ids.erase(id)
				if _alive_target_ids.is_empty() and _current_kill_time_sec < 0.0:
					_current_kill_time_sec = _elapsed_test_sec
