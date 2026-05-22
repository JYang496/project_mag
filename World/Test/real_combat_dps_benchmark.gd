extends Node2D
class_name RealCombatDpsBenchmark

const DEFAULT_REPORT_DIR := "res://docs/dps_reports"
const REPORT_FILE_PREFIX := "real_combat_dps"

@export var player_scene: PackedScene = preload("res://Player/Mechas/scenes/Player.tscn")
@export var dummy_scene: PackedScene = preload("res://World/Test/dps_test_dummy_enemy.tscn")
@export var auto_start_on_ready: bool = true
@export var quit_on_completion: bool = true
@export var test_duration_sec: float = 10.0
@export var warmup_sec: float = 0.0
@export var min_weapon_level: int = 1
@export var max_weapon_level: int = 7
@export var player_position: Vector2 = Vector2(360.0, 360.0)
@export var target_position: Vector2 = Vector2(620.0, 360.0)
@export var target_hp: int = 1000000000
@export var force_mouse_to_target: bool = true
@export var accelerated_mode: bool = true
@export_range(0.1, 32.0, 0.1) var simulation_time_scale: float = 8.0
@export var report_dir: String = DEFAULT_REPORT_DIR

@onready var spawn_root: Node2D = $SpawnRoot
@onready var player_spawn: Marker2D = $SpawnRoot/PlayerSpawn
@onready var target_spawn: Marker2D = $SpawnRoot/TargetSpawn
@onready var target_root: Node2D = $SpawnRoot/TargetRoot
@onready var status_label: Label = $UI/Panel/VBox/StatusLabel
@onready var weapon_label: Label = $UI/Panel/VBox/WeaponLabel
@onready var progress_label: Label = $UI/Panel/VBox/ProgressLabel
@onready var report_label: Label = $UI/Panel/VBox/ReportLabel

var _player: Player
var _target: Node
var _case_queue: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _elapsed_test_sec: float = 0.0
var _current_total_damage: int = 0
var _current_hit_count: int = 0
var _current_hit_damage_sum: int = 0
var _current_hit_damage_min: int = -1
var _current_hit_damage_max: int = 0
var _current_fire_attempts: int = 0
var _current_fire_success: int = 0
var _current_reload_started: int = 0
var _current_reload_finished: int = 0
var _previous_reloading: bool = false
var _current_weapon_id: String = ""
var _current_weapon_level: int = 1
var _last_html_path: String = ""
var _original_time_scale: float = 1.0
var _time_scale_applied: bool = false
var _measurement_active: bool = false

func _ready() -> void:
	_set_status("Idle")
	player_spawn.global_position = player_position
	target_spawn.global_position = target_position
	if auto_start_on_ready:
		call_deferred("_run_benchmark")

func _run_benchmark() -> void:
	_ensure_weapon_data_loaded()
	_case_queue = _build_case_queue()
	_results.clear()
	print("RealCombatDpsBenchmark: cases=%d" % _case_queue.size())
	if _case_queue.is_empty():
		_set_status("No weapons found")
		if quit_on_completion:
			get_tree().quit(1)
		return
	_apply_benchmark_time_scale()
	_set_status("Running")
	await get_tree().physics_frame
	for i in range(_case_queue.size()):
		var case_data: Dictionary = _case_queue[i]
		print("RealCombatDpsBenchmark: case %d/%d weapon=%s level=%s" % [
			i + 1,
			_case_queue.size(),
			str(case_data.get("weapon_id", "")),
			str(case_data.get("level", "")),
		])
		await _run_case(case_data, i + 1, _case_queue.size())
		await get_tree().create_timer(0.05).timeout
	_restore_benchmark_time_scale()
	_last_html_path = _write_html_report()
	_set_status("Completed")
	report_label.text = "Report: %s" % _last_html_path
	if quit_on_completion:
		print("RealCombatDpsBenchmark: completed report=%s rows=%d" % [_last_html_path, _results.size()])
		get_tree().quit(0)

func _ensure_weapon_data_loaded() -> void:
	if GlobalVariables.weapon_list.is_empty():
		DataHandler.load_weapon_data()

func _build_case_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var ids := DataHandler.get_weapon_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(a) < int(b)
	)
	for weapon_id in ids:
		for level_value in range(min_weapon_level, max_weapon_level + 1):
			queue.append({
				"weapon_id": weapon_id,
				"level": level_value,
			})
	return queue

func _run_case(case_data: Dictionary, case_index: int, total_cases: int) -> void:
	await _prepare_case(case_data)
	weapon_label.text = "Weapon %s | Lv.%d" % [_current_weapon_id, _current_weapon_level]
	_update_progress(case_index, total_cases, "Warmup")
	var warmup_left := maxf(warmup_sec, 0.0)
	while warmup_left > 0.0:
		_step_weapon(false)
		await get_tree().physics_frame
		var delta := _get_benchmark_delta()
		warmup_left -= delta

	_reset_measurement_state()
	_measurement_active = true
	while _elapsed_test_sec < test_duration_sec:
		_step_weapon(true)
		await get_tree().physics_frame
		var delta := _get_benchmark_delta()
		_elapsed_test_sec += delta
		_update_progress(case_index, total_cases, "%.2f / %.2fs" % [minf(_elapsed_test_sec, test_duration_sec), test_duration_sec])
	_measurement_active = false

	_results.append(_build_result())
	_cleanup_case()

func _prepare_case(case_data: Dictionary) -> void:
	_cleanup_case()
	_ensure_battle_phase_for_test()
	_current_weapon_id = str(case_data.get("weapon_id", ""))
	_current_weapon_level = clampi(int(case_data.get("level", min_weapon_level)), min_weapon_level, max_weapon_level)
	_spawn_player()
	_spawn_target()
	_equip_weapon(_current_weapon_id, _current_weapon_level)
	_apply_benchmark_aim_meta()
	await get_tree().physics_frame

func _ensure_battle_phase_for_test() -> void:
	if PhaseManager == null or not PhaseManager.has_method("current_state"):
		return
	if str(PhaseManager.current_state()) == str(PhaseManager.BATTLE):
		return
	if PhaseManager.has_method("enter_battle"):
		PhaseManager.enter_battle()

func _spawn_player() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var player_instance := player_scene.instantiate()
	if not (player_instance is Player):
		push_error("real_combat_dps_benchmark: player_scene is not Player.")
		return
	_player = player_instance as Player
	spawn_root.add_child(_player)
	_player.global_position = player_spawn.global_position
	PlayerData.player = _player
	PlayerData.set_hp_safety_for_testing(true)

func _spawn_target() -> void:
	var dummy_instance := dummy_scene.instantiate()
	var dummy := dummy_instance as Node2D
	if dummy == null:
		push_error("real_combat_dps_benchmark: dummy_scene is not Node2D.")
		return
	if dummy.get("max_hp_value") != null:
		dummy.set("max_hp_value", max(1, target_hp))
	target_root.add_child(dummy)
	dummy.global_position = target_spawn.global_position
	if dummy.has_signal("damage_received"):
		dummy.connect("damage_received", Callable(self, "_on_dummy_damage_received"))
	if dummy.has_signal("dummy_died"):
		dummy.connect("dummy_died", Callable(self, "_on_dummy_died"))
	_target = dummy

func _equip_weapon(weapon_id: String, level_value: int) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_clear_player_weapons_for_case()
	_player.create_weapon(weapon_id, level_value)
	PlayerData.set_main_weapon_index(0)
	var weapon := _resolve_main_weapon_node()
	if weapon != null and weapon.has_method("set_level"):
		weapon.call("set_level", level_value)
	if weapon != null and weapon.has_signal("weapon_reload_completed"):
		weapon.connect("weapon_reload_completed", Callable(self, "_on_weapon_reload_completed"))
	_previous_reloading = _is_weapon_reloading(weapon)

func _clear_player_weapons_for_case() -> void:
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon_node := weapon_ref as Node
		if weapon_node != null and is_instance_valid(weapon_node):
			weapon_node.queue_free()
	PlayerData.player_weapon_list.clear()
	PlayerData.set_main_weapon_index(-1)
	var weapon_root := _player.get_node_or_null("EquippedWeapons")
	if weapon_root == null:
		return
	for child in weapon_root.get_children():
		child.queue_free()

func _reset_measurement_state() -> void:
	_measurement_active = false
	_elapsed_test_sec = 0.0
	_current_total_damage = 0
	_current_hit_count = 0
	_current_hit_damage_sum = 0
	_current_hit_damage_min = -1
	_current_hit_damage_max = 0
	_current_fire_attempts = 0
	_current_fire_success = 0
	_current_reload_started = 0
	_current_reload_finished = 0
	var weapon := _resolve_main_weapon_node()
	_previous_reloading = _is_weapon_reloading(weapon)
	if _target != null and is_instance_valid(_target):
		if _target.get("hp") != null:
			_target.set("hp", max(1, target_hp))
		if _target.get("is_dead") != null:
			_target.set("is_dead", false)

func _step_weapon(record_stats: bool) -> void:
	_update_mouse_aim()
	var weapon := _resolve_main_weapon_node()
	if weapon == null:
		return
	var skip_forced_fire := _should_skip_forced_fire(weapon)
	if record_stats and not skip_forced_fire:
		_current_fire_attempts += 1
	if not skip_forced_fire and weapon.has_method("request_primary_fire"):
		var ok := bool(weapon.call("request_primary_fire"))
		if ok and record_stats:
			_current_fire_success += 1
	_track_reload_state(weapon, record_stats)
	_apply_benchmark_aim_meta()

func _should_skip_forced_fire(weapon: Node) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if not weapon.has_method("should_skip_benchmark_forced_fire"):
		return false
	return bool(weapon.call("should_skip_benchmark_forced_fire"))

func _track_reload_state(weapon: Node, record_stats: bool) -> void:
	if weapon == null:
		return
	var is_reloading_now := _is_weapon_reloading(weapon)
	if record_stats and is_reloading_now and not _previous_reloading:
		_current_reload_started += 1
	_previous_reloading = is_reloading_now

func _is_weapon_reloading(weapon: Node) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if weapon.get("is_reloading") == null:
		return false
	return bool(weapon.get("is_reloading"))

func _on_weapon_reload_completed(_weapon: Weapon) -> void:
	_current_reload_finished += 1

func _on_dummy_damage_received(_dummy: Node, amount: int, attack: Attack, _hp_after: int) -> void:
	if not _measurement_active:
		return
	if attack != null and attack.source_player != null and attack.source_player != _player:
		return
	var dealt: int = max(0, int(amount))
	if dealt <= 0:
		return
	_current_total_damage += dealt
	_current_hit_count += 1
	_current_hit_damage_sum += dealt
	if _current_hit_damage_min < 0 or dealt < _current_hit_damage_min:
		_current_hit_damage_min = dealt
	if dealt > _current_hit_damage_max:
		_current_hit_damage_max = dealt

func _on_dummy_died(dummy: Node, _attack: Attack) -> void:
	if dummy == null or not is_instance_valid(dummy):
		return
	if dummy.get("hp") != null:
		dummy.set("hp", max(1, target_hp))
	if dummy.get("is_dead") != null:
		dummy.set("is_dead", false)

func _build_result() -> Dictionary:
	var duration := maxf(_elapsed_test_sec, 0.001)
	var avg_hit := 0.0
	if _current_hit_count > 0:
		avg_hit = float(_current_hit_damage_sum) / float(_current_hit_count)
	return {
		"weapon_id": _current_weapon_id,
		"weapon_name": _resolve_weapon_name(_current_weapon_id),
		"level": _current_weapon_level,
		"duration_sec": snapped(duration, 0.001),
		"total_damage": _current_total_damage,
		"dps": snapped(float(_current_total_damage) / duration, 0.001),
		"hit_count": _current_hit_count,
		"avg_hit": snapped(avg_hit, 0.001),
		"min_hit": max(0, _current_hit_damage_min),
		"max_hit": _current_hit_damage_max,
		"fire_attempts": _current_fire_attempts,
		"fire_success": _current_fire_success,
		"reload_started": _current_reload_started,
		"reload_finished": _current_reload_finished,
	}

func _cleanup_case() -> void:
	Input.action_release("ATTACK")
	PlayerData.player = null
	if target_root != null and is_instance_valid(target_root):
		for child in target_root.get_children():
			child.queue_free()
	for child in spawn_root.get_children():
		if child is Marker2D or child == target_root:
			continue
		child.queue_free()
	for child in get_children():
		if child == spawn_root or child.name == "UI":
			continue
		child.queue_free()
	_player = null
	_target = null

func _resolve_main_weapon_node() -> Node:
	if _player == null or not is_instance_valid(_player):
		return null
	var main_weapon: Variant = _player.get_main_weapon()
	if main_weapon == null or not is_instance_valid(main_weapon):
		return null
	return main_weapon as Node

func _apply_benchmark_aim_meta() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.set_meta("_benchmark_mouse_target", target_spawn.global_position)
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon_node := weapon_ref as Node
		if weapon_node == null or not is_instance_valid(weapon_node):
			continue
		weapon_node.set_meta("_benchmark_mouse_target", target_spawn.global_position)

func _update_mouse_aim() -> void:
	if not force_mouse_to_target:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var canvas_pos: Vector2 = viewport.get_canvas_transform() * target_spawn.global_position
	Input.warp_mouse(canvas_pos)

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

func _write_html_report() -> String:
	_ensure_report_dir(report_dir)
	var stamp := _build_file_stamp()
	var path := "%s/%s_%s.html" % [report_dir, REPORT_FILE_PREFIX, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("real_combat_dps_benchmark: failed to open HTML report %s" % path)
		return ""
	file.store_string(_build_html(stamp))
	file.flush()
	file.close()
	return path

func _build_html(stamp: String) -> String:
	var rows := PackedStringArray()
	for result in _results:
		rows.append(
			"<tr><td>%s</td><td>%s</td><td>%d</td><td>%.3f</td><td>%d</td><td>%.3f</td><td>%d</td><td>%.3f</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td></tr>" % [
				_html_escape(str(result.get("weapon_id", ""))),
				_html_escape(str(result.get("weapon_name", ""))),
				int(result.get("level", 0)),
				float(result.get("dps", 0.0)),
				int(result.get("total_damage", 0)),
				float(result.get("duration_sec", 0.0)),
				int(result.get("hit_count", 0)),
				float(result.get("avg_hit", 0.0)),
				int(result.get("min_hit", 0)),
				int(result.get("max_hit", 0)),
				int(result.get("fire_attempts", 0)),
				int(result.get("fire_success", 0)),
				int(result.get("reload_started", 0)),
				int(result.get("reload_finished", 0)),
			]
		)
	return """<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Real Combat DPS Benchmark</title>
  <style>
    body { margin: 0; padding: 32px; background: #f5f7fb; color: #1f2937; font-family: Arial, "Microsoft YaHei", sans-serif; }
    h1 { margin: 0 0 8px; font-size: 28px; }
    .meta { margin: 0 0 20px; color: #64748b; }
    table { width: 100%%; border-collapse: collapse; background: #fff; border: 1px solid #d8dee9; }
    th, td { padding: 9px 10px; border-bottom: 1px solid #e5eaf1; text-align: left; font-size: 13px; }
    th { background: #eef2f7; position: sticky; top: 0; }
    tr:nth-child(even) td { background: #fafbfd; }
    .num { text-align: right; }
  </style>
</head>
<body>
  <h1>Real Combat DPS Benchmark</h1>
  <p class="meta">Generated: %s | Cases: %d | Duration: %.1fs | Player: %s | Target: %s</p>
  <table>
    <thead>
      <tr>
        <th>Weapon ID</th><th>Weapon</th><th>Level</th><th>DPS</th><th>Total Damage</th><th>Duration</th><th>Hit Count</th><th>Avg Hit</th><th>Min Hit</th><th>Max Hit</th><th>Fire Attempts</th><th>Fire Success</th><th>Reload Started</th><th>Reload Finished</th>
      </tr>
    </thead>
    <tbody>
      %s
    </tbody>
  </table>
</body>
</html>
""" % [
		_html_escape(stamp),
		_results.size(),
		test_duration_sec,
		_html_escape(str(player_position)),
		_html_escape(str(target_position)),
		"\n      ".join(rows),
	]

func _html_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")

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

func _get_benchmark_delta() -> float:
	var delta := maxf(get_physics_process_delta_time(), 0.001)
	return delta

func _apply_benchmark_time_scale() -> void:
	if _time_scale_applied or not accelerated_mode:
		return
	_original_time_scale = Engine.time_scale
	Engine.time_scale = clampf(simulation_time_scale, 0.1, 32.0)
	_time_scale_applied = true

func _restore_benchmark_time_scale() -> void:
	if not _time_scale_applied:
		return
	Engine.time_scale = _original_time_scale
	_time_scale_applied = false

func _set_status(message: String) -> void:
	if status_label:
		status_label.text = "Status: %s" % message

func _update_progress(case_index: int, total_cases: int, phase_text: String) -> void:
	if progress_label:
		progress_label.text = "Progress: Case %d/%d | %s" % [case_index, total_cases, phase_text]
