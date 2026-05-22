extends RealCombatDpsBenchmark
class_name RealCombatSingleWeaponRepeatBenchmark

const SINGLE_REPORT_FILE_PREFIX := "real_combat_single_weapon_repeat"

@export var target_weapon_id: String = "1"
@export_range(1, 100, 1) var repeat_count: int = 5

var _current_repeat_index: int = 1

func _build_case_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var weapon_id := target_weapon_id.strip_edges()
	if weapon_id == "":
		return queue
	var weapon_max_level := _get_weapon_max_benchmark_level(weapon_id)
	for repeat_index in range(1, repeat_count + 1):
		for level_value in range(min_weapon_level, weapon_max_level + 1):
			queue.append({
				"weapon_id": weapon_id,
				"level": level_value,
				"max_level": weapon_max_level,
				"repeat_index": repeat_index,
			})
	return queue

func _prepare_case(case_data: Dictionary) -> void:
	_current_repeat_index = int(case_data.get("repeat_index", 1))
	await super._prepare_case(case_data)

func _build_result() -> Dictionary:
	var result := super._build_result()
	result["repeat_index"] = _current_repeat_index
	return result

func _write_html_report() -> String:
	_ensure_report_dir(report_dir)
	var stamp := _build_file_stamp()
	var path := "%s/%s_%s_%s.html" % [
		report_dir,
		SINGLE_REPORT_FILE_PREFIX,
		_sanitize_file_part(target_weapon_id),
		stamp,
	]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("real_combat_single_weapon_repeat_benchmark: failed to open HTML report %s" % path)
		return ""
	file.store_string(_build_html(stamp))
	file.flush()
	file.close()
	return path

func _build_html(stamp: String) -> String:
	var rows := PackedStringArray()
	for result in _results:
		rows.append(
			"<tr><td>%d</td><td>%s</td><td>%s</td><td>%d</td><td>%.3f</td><td>%d</td><td>%.3f</td><td>%d</td><td>%.3f</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td></tr>" % [
				int(result.get("repeat_index", 0)),
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
	var summary_rows := _build_summary_rows()
	return """<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Real Combat Single Weapon Repeat Benchmark</title>
  <style>
    body { margin: 0; padding: 32px; background: #f5f7fb; color: #1f2937; font-family: Arial, "Microsoft YaHei", sans-serif; }
    h1 { margin: 0 0 8px; font-size: 28px; }
    h2 { margin: 24px 0 10px; font-size: 20px; }
    .meta { margin: 0 0 20px; color: #64748b; }
    table { width: 100%%; border-collapse: collapse; background: #fff; border: 1px solid #d8dee9; margin-bottom: 20px; }
    th, td { padding: 9px 10px; border-bottom: 1px solid #e5eaf1; text-align: left; font-size: 13px; }
    th { background: #eef2f7; position: sticky; top: 0; }
    tr:nth-child(even) td { background: #fafbfd; }
  </style>
</head>
<body>
  <h1>Real Combat Single Weapon Repeat Benchmark</h1>
  <p class="meta">Generated: %s | Weapon: %s | Repeats: %d | Cases: %d | Duration: %.1fs | Player: %s | Target: %s</p>
  <h2>Summary By Level</h2>
  <table>
    <thead>
      <tr>
        <th>Level</th><th>Samples</th><th>Avg DPS</th><th>Min DPS</th><th>Max DPS</th><th>Avg Damage</th><th>Damage Delta</th><th>Min Damage</th><th>Max Damage</th><th>Avg Hits</th><th>Avg Fire Success</th>
      </tr>
    </thead>
    <tbody>
      %s
    </tbody>
  </table>
  <h2>Raw Repeats</h2>
  <table>
    <thead>
      <tr>
        <th>Repeat</th><th>Weapon ID</th><th>Weapon</th><th>Level</th><th>DPS</th><th>Total Damage</th><th>Duration</th><th>Hit Count</th><th>Avg Hit</th><th>Min Hit</th><th>Max Hit</th><th>Fire Attempts</th><th>Fire Success</th><th>Reload Started</th><th>Reload Finished</th>
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
		_html_escape(target_weapon_id),
		repeat_count,
		_results.size(),
		test_duration_sec,
		_html_escape(str(player_position)),
		_html_escape(str(target_position)),
		"\n      ".join(summary_rows),
		"\n      ".join(rows),
	]

func _build_summary_rows() -> PackedStringArray:
	var by_level := {}
	for result in _results:
		var level_value := int(result.get("level", 0))
		if not by_level.has(level_value):
			by_level[level_value] = []
		var level_samples: Array = by_level[level_value]
		level_samples.append(result)
	var levels := by_level.keys()
	levels.sort()
	var rows := PackedStringArray()
	var previous_avg_damage := 0.0
	var has_previous := false
	for level_value in levels:
		var samples: Array = by_level[level_value]
		var summary := _build_summary(int(level_value), samples)
		var avg_damage := float(summary.get("avg_damage", 0.0))
		var damage_delta_text := "--"
		if has_previous:
			var damage_delta := avg_damage - previous_avg_damage
			damage_delta_text = "%+.1f" % damage_delta
		rows.append(_build_summary_row(summary, damage_delta_text))
		previous_avg_damage = avg_damage
		has_previous = true
	return rows

func _build_summary(level_value: int, samples: Array) -> Dictionary:
	var count := samples.size()
	var dps_sum := 0.0
	var dps_min := INF
	var dps_max := 0.0
	var damage_sum := 0
	var damage_min := 9223372036854775807
	var damage_max := 0
	var hit_sum := 0
	var fire_success_sum := 0
	for sample in samples:
		var result := sample as Dictionary
		var dps := float(result.get("dps", 0.0))
		var damage := int(result.get("total_damage", 0))
		dps_sum += dps
		dps_min = minf(dps_min, dps)
		dps_max = maxf(dps_max, dps)
		damage_sum += damage
		damage_min = mini(damage_min, damage)
		damage_max = maxi(damage_max, damage)
		hit_sum += int(result.get("hit_count", 0))
		fire_success_sum += int(result.get("fire_success", 0))
	var safe_count: int = max(1, count)
	return {
		"level": level_value,
		"count": count,
		"avg_dps": dps_sum / float(safe_count),
		"min_dps": dps_min if count > 0 else 0.0,
		"max_dps": dps_max,
		"avg_damage": float(damage_sum) / float(safe_count),
		"min_damage": damage_min if count > 0 else 0,
		"max_damage": damage_max,
		"avg_hits": float(hit_sum) / float(safe_count),
		"avg_fire_success": float(fire_success_sum) / float(safe_count),
	}

func _build_summary_row(summary: Dictionary, damage_delta_text: String) -> String:
	return "<tr><td>%d</td><td>%d</td><td>%.3f</td><td>%.3f</td><td>%.3f</td><td>%.1f</td><td>%s</td><td>%d</td><td>%d</td><td>%.1f</td><td>%.1f</td></tr>" % [
		int(summary.get("level", 0)),
		int(summary.get("count", 0)),
		float(summary.get("avg_dps", 0.0)),
		float(summary.get("min_dps", 0.0)),
		float(summary.get("max_dps", 0.0)),
		float(summary.get("avg_damage", 0.0)),
		_html_escape(damage_delta_text),
		int(summary.get("min_damage", 0)),
		int(summary.get("max_damage", 0)),
		float(summary.get("avg_hits", 0.0)),
		float(summary.get("avg_fire_success", 0.0)),
	]

func _sanitize_file_part(value: String) -> String:
	var result := value.strip_edges()
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		result = result.replace(character, "_")
	if result == "":
		return "weapon"
	return result
