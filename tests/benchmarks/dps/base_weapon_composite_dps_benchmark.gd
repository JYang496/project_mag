extends "res://tests/benchmarks/dps/real_combat_dps_benchmark.gd"

const COMPOSITE_REPORT_PREFIX := "base_weapon_composite_dps"
const CHECKPOINT_LEVELS := [1, 5, 9]
const SCENARIOS := [&"single", &"cluster", &"line"]
const TARGET_WEAPON_IDS := ["8", "9", "26"]
const MAX_ACCEPTED_RANK := 7
const EIGHTH_PLACE_MARGIN := 1.10

@export_range(1, 10, 1) var repeat_count: int = 5
@export var cluster_spacing_px: float = 100.0
@export var line_spacing_px: float = 150.0

var _current_scenario: StringName = &"single"
var _current_repeat: int = 1
var _acceptance_passed: bool = false
var _allow_failed_acceptance: bool = false
var _composite_rows: Array[Dictionary] = []
var _weapon_filter: PackedStringArray = PackedStringArray()
var _original_physics_ticks_per_second: int = 60

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-repeats="):
			repeat_count = clampi(int(argument.get_slice("=", 1)), 1, 10)
		elif argument.begins_with("--benchmark-weapons="):
			_weapon_filter = PackedStringArray(argument.get_slice("=", 1).split(",", false))
		elif argument == "--benchmark-no-fail":
			_allow_failed_acceptance = true
	super._ready()

func _run_benchmark() -> void:
	_ensure_weapon_data_loaded()
	_case_queue = _build_case_queue()
	_results.clear()
	print("BaseWeaponCompositeDpsBenchmark: cases=%d repeats=%d" % [_case_queue.size(), repeat_count])
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
		print("BaseWeaponCompositeDpsBenchmark: case %d/%d weapon=%s level=%s scenario=%s repeat=%s" % [
			i + 1,
			_case_queue.size(),
			str(case_data.get("weapon_id", "")),
			str(case_data.get("level", "")),
			str(case_data.get("scenario", "")),
			str(case_data.get("repeat", "")),
		])
		await _run_case(case_data, i + 1, _case_queue.size())
		await get_tree().create_timer(0.05).timeout
	_restore_benchmark_time_scale()
	_last_html_path = _write_html_report()
	_set_status("Completed" if _acceptance_passed else "Acceptance failed")
	report_label.text = "Report: %s" % _last_html_path
	if quit_on_completion:
		print("BaseWeaponCompositeDpsBenchmark: completed report=%s rows=%d accepted=%s" % [
			_last_html_path,
			_composite_rows.size(),
			str(_acceptance_passed),
		])
		get_tree().quit(0 if _acceptance_passed or _allow_failed_acceptance else 1)

func _build_case_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var ids := DataHandler.get_weapon_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(a) < int(b)
	)
	for level_value in CHECKPOINT_LEVELS:
		for weapon_id in ids:
			if not _weapon_filter.is_empty() and not _weapon_filter.has(weapon_id):
				continue
			var max_level_value := _get_weapon_max_benchmark_level(weapon_id)
			if level_value > max_level_value:
				continue
			for scenario in SCENARIOS:
				for repeat_index in range(1, maxi(repeat_count, 1) + 1):
					queue.append({
						"weapon_id": weapon_id,
						"level": level_value,
						"max_level": max_level_value,
						"scenario": scenario,
						"repeat": repeat_index,
					})
	return queue

func _apply_benchmark_time_scale() -> void:
	_original_physics_ticks_per_second = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 480
	super._apply_benchmark_time_scale()

func _restore_benchmark_time_scale() -> void:
	super._restore_benchmark_time_scale()
	Engine.physics_ticks_per_second = _original_physics_ticks_per_second

func _prepare_case(case_data: Dictionary) -> void:
	_current_scenario = StringName(case_data.get("scenario", &"single"))
	_current_repeat = int(case_data.get("repeat", 1))
	_cleanup_case()
	await get_tree().physics_frame
	DamageManager.set("_source_player_cache", {})
	DamageManager.set("_dedupe_until_msec", {})
	_ensure_battle_phase_for_test()
	_current_weapon_id = str(case_data.get("weapon_id", ""))
	var case_max_level := int(case_data.get("max_level", _get_weapon_max_benchmark_level(_current_weapon_id)))
	_current_weapon_level = clampi(int(case_data.get("level", min_weapon_level)), min_weapon_level, case_max_level)
	_spawn_player()
	_spawn_target()
	_equip_weapon(_current_weapon_id, _current_weapon_level)
	_apply_benchmark_aim_meta()
	await get_tree().physics_frame

func _spawn_target() -> void:
	var offsets := _get_target_offsets(_current_scenario)
	for offset in offsets:
		var dummy_instance := dummy_scene.instantiate()
		var dummy := dummy_instance as Node2D
		if dummy == null:
			push_error("base_weapon_composite_dps_benchmark: dummy_scene is not Node2D.")
			continue
		if dummy.get("max_hp_value") != null:
			dummy.set("max_hp_value", max(1, target_hp))
		target_root.add_child(dummy)
		dummy.global_position = target_spawn.global_position + offset
		if dummy.has_signal("damage_received"):
			dummy.connect("damage_received", Callable(self, "_on_dummy_damage_received"))
		if dummy.has_signal("dummy_died"):
			dummy.connect("dummy_died", Callable(self, "_on_dummy_died"))
		if _target == null:
			_target = dummy

func _get_target_offsets(scenario: StringName) -> Array[Vector2]:
	match scenario:
		&"cluster":
			var spacing := maxf(cluster_spacing_px, 1.0)
			return [
				Vector2.ZERO,
				Vector2(spacing, 0.0),
				Vector2(-spacing, 0.0),
				Vector2(0.0, spacing),
				Vector2(0.0, -spacing),
			]
		&"line":
			var spacing := maxf(line_spacing_px, 1.0)
			return [
				Vector2.ZERO,
				Vector2(spacing, 0.0),
				Vector2(spacing * 2.0, 0.0),
				Vector2(spacing * 3.0, 0.0),
				Vector2(spacing * 4.0, 0.0),
			]
		_:
			return [Vector2.ZERO]

func _build_result() -> Dictionary:
	var result := super._build_result()
	result["scenario"] = str(_current_scenario)
	result["repeat"] = _current_repeat
	return result

func _step_weapon(record_stats: bool) -> void:
	_update_mouse_aim()
	var weapon := _resolve_main_weapon_node()
	if weapon == null:
		return
	if record_stats:
		_current_fire_attempts += 1
	_apply_benchmark_aim_meta()
	var delta := _get_benchmark_delta()
	if weapon.has_method("handle_primary_input"):
		weapon.call("handle_primary_input", true, false, false, delta)
	elif weapon.has_method("request_primary_fire"):
		weapon.call("request_primary_fire")

func _cleanup_case() -> void:
	Input.action_release("ATTACK")
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
	# Keep the outgoing player reference valid until queued projectile effects have
	# completed this frame. _spawn_player() replaces it after the cleanup frame.
	_player = null
	_target = null

func _write_html_report() -> String:
	_composite_rows = _build_composite_rows()
	_acceptance_passed = _evaluate_acceptance(_composite_rows)
	_ensure_report_dir(report_dir)
	var stamp := _build_file_stamp()
	var path := "%s/%s_%s.html" % [report_dir, COMPOSITE_REPORT_PREFIX, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("base_weapon_composite_dps_benchmark: failed to open HTML report %s" % path)
		return ""
	file.store_string(_build_composite_html(stamp, _composite_rows))
	file.flush()
	file.close()
	return path

func _build_composite_rows() -> Array[Dictionary]:
	var samples: Dictionary = {}
	for result in _results:
		var key := "%s|%d" % [str(result.get("weapon_id", "")), int(result.get("level", 0))]
		if not samples.has(key):
			samples[key] = {
				"weapon_id": str(result.get("weapon_id", "")),
				"weapon_name": str(result.get("weapon_name", "")),
				"level": int(result.get("level", 0)),
				"single": [],
				"cluster": [],
				"line": [],
			}
		var scenario := str(result.get("scenario", "single"))
		var entry: Dictionary = samples[key]
		var scenario_samples: Array = entry.get(scenario, [])
		scenario_samples.append(float(result.get("dps", 0.0)))
		entry[scenario] = scenario_samples
		samples[key] = entry

	var rows: Array[Dictionary] = []
	for entry_variant in samples.values():
		var entry: Dictionary = entry_variant
		var single_dps := _median(entry.get("single", []))
		var cluster_dps := _median(entry.get("cluster", []))
		var line_dps := _median(entry.get("line", []))
		var group_dps := (cluster_dps + line_dps) * 0.5
		rows.append({
			"weapon_id": str(entry.get("weapon_id", "")),
			"weapon_name": str(entry.get("weapon_name", "")),
			"level": int(entry.get("level", 0)),
			"single_dps": snapped(single_dps, 0.001),
			"cluster_dps": snapped(cluster_dps, 0.001),
			"line_dps": snapped(line_dps, 0.001),
			"group_dps": snapped(group_dps, 0.001),
			"composite_dps": snapped(single_dps * 0.5 + group_dps * 0.5, 0.001),
			"rank": 0,
			"eighth_place_dps": 0.0,
			"margin_pass": false,
		})

	for level_value in CHECKPOINT_LEVELS:
		var level_rows: Array[Dictionary] = []
		for row in rows:
			if int(row.get("level", 0)) == level_value:
				level_rows.append(row)
		level_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("composite_dps", 0.0)) > float(b.get("composite_dps", 0.0))
		)
		var eighth_place_dps := 0.0
		if level_rows.size() >= 8:
			eighth_place_dps = float(level_rows[7].get("composite_dps", 0.0))
		for index in range(level_rows.size()):
			level_rows[index]["rank"] = index + 1
			level_rows[index]["eighth_place_dps"] = eighth_place_dps
			level_rows[index]["margin_pass"] = (
				int(level_rows[index].get("rank", 999)) <= MAX_ACCEPTED_RANK
				and float(level_rows[index].get("composite_dps", 0.0)) >= eighth_place_dps * EIGHTH_PLACE_MARGIN
			)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var level_a := int(a.get("level", 0))
		var level_b := int(b.get("level", 0))
		if level_a != level_b:
			return level_a < level_b
		return int(a.get("rank", 999)) < int(b.get("rank", 999))
	)
	return rows

func _evaluate_acceptance(rows: Array[Dictionary]) -> bool:
	var passed := true
	for level_value in CHECKPOINT_LEVELS:
		for weapon_id in TARGET_WEAPON_IDS:
			var row := _find_composite_row(rows, weapon_id, level_value)
			if row.is_empty() or not bool(row.get("margin_pass", false)):
				passed = false
				push_error("Composite DPS acceptance failed: weapon=%s level=%d rank=%d score=%.3f eighth=%.3f" % [
					weapon_id,
					level_value,
					int(row.get("rank", 0)),
					float(row.get("composite_dps", 0.0)),
					float(row.get("eighth_place_dps", 0.0)),
				])
	return passed

func _find_composite_row(rows: Array[Dictionary], weapon_id: String, level_value: int) -> Dictionary:
	for row in rows:
		if str(row.get("weapon_id", "")) == weapon_id and int(row.get("level", 0)) == level_value:
			return row
	return {}

func _median(values_variant: Variant) -> float:
	if not (values_variant is Array):
		return 0.0
	var values: Array = values_variant.duplicate()
	if values.is_empty():
		return 0.0
	values.sort()
	var middle := values.size() / 2
	if values.size() % 2 == 1:
		return float(values[middle])
	return (float(values[middle - 1]) + float(values[middle])) * 0.5

func _build_composite_html(stamp: String, rows: Array[Dictionary]) -> String:
	var html_rows := PackedStringArray()
	for row in rows:
		var is_target := TARGET_WEAPON_IDS.has(str(row.get("weapon_id", "")))
		html_rows.append(
			"<tr class=\"%s\"><td>%d</td><td>%d</td><td>%s</td><td>%s</td><td>%.3f</td><td>%.3f</td><td>%.3f</td><td>%.3f</td><td>%.3f</td><td>%s</td></tr>" % [
				"target" if is_target else "",
				int(row.get("level", 0)),
				int(row.get("rank", 0)),
				_html_escape(str(row.get("weapon_id", ""))),
				_html_escape(str(row.get("weapon_name", ""))),
				float(row.get("single_dps", 0.0)),
				float(row.get("cluster_dps", 0.0)),
				float(row.get("line_dps", 0.0)),
				float(row.get("group_dps", 0.0)),
				float(row.get("composite_dps", 0.0)),
				"PASS" if bool(row.get("margin_pass", false)) else "",
			]
		)
	return """<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Base Weapon Composite DPS Benchmark</title>
  <style>
    body { margin: 0; padding: 32px; background: #f5f7fb; color: #1f2937; font-family: Arial, "Microsoft YaHei", sans-serif; }
    h1 { margin: 0 0 8px; font-size: 28px; }
    .meta { margin: 0 0 20px; color: #64748b; }
    table { width: 100%%; border-collapse: collapse; background: #fff; border: 1px solid #d8dee9; }
    th, td { padding: 9px 10px; border-bottom: 1px solid #e5eaf1; text-align: right; font-size: 13px; }
    th { background: #eef2f7; position: sticky; top: 0; }
    th:nth-child(3), th:nth-child(4), td:nth-child(3), td:nth-child(4) { text-align: left; }
    tr.target td { background: #fff7d6; font-weight: 600; }
  </style>
</head>
<body>
  <h1>Base Weapon Composite DPS Benchmark</h1>
  <p class="meta">Generated: %s | Result: %s | Formula: 50%% single + 25%% cluster total + 25%% line total | 10s | 260 px | %d repeats, median | Pass: rank ≤ 7 and score ≥ 110%% of rank 8.</p>
  <table>
    <thead><tr><th>Level</th><th>Rank</th><th>Weapon ID</th><th>Weapon</th><th>Single</th><th>Cluster</th><th>Line</th><th>Group Avg</th><th>Composite</th><th>Target Gate</th></tr></thead>
    <tbody>%s</tbody>
  </table>
</body>
</html>
""" % [
		_html_escape(stamp),
		"PASS" if _acceptance_passed else "FAIL",
		repeat_count,
		"\n".join(html_rows),
	]
