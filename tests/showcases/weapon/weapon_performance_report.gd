extends RefCounted
class_name WeaponPerformanceReport

const SUITE_SCHEMA_VERSION := 2
const BASE_DIRECTORY := "user://performance/weapon_lab"
const BASELINE_PATH := "user://performance/weapon_lab/baseline.json"
const DOCS_DIRECTORY := "res://docs/performance/weapon_lab"


static func build_suite(suite_id: String, results: Array[Dictionary], started_at: String) -> Dictionary:
	return {
		"schema_version": SUITE_SCHEMA_VERSION,
		"suite_id": suite_id,
		"started_at": started_at,
		"completed_at": Time.get_datetime_string_from_system(false, true),
		"environment": _environment(),
		"scenario_count": results.size(),
		"results": results,
		"aggregates": _aggregate_repeats(results),
		"comparison": compare_with_baseline(results),
	}


static func save_suite(report: Dictionary) -> String:
	var suite_id := str(report.get("suite_id", ""))
	var base_directory := get_base_directory(suite_id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_directory)) != OK:
		push_error("Could not create performance report directory: %s" % base_directory)
		return ""
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var run_directory := "%s/run_%s_%d" % [base_directory, stamp, Time.get_ticks_msec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run_directory)) != OK:
		push_error("Could not create performance run directory: %s" % run_directory)
		return ""
	var path := "%s/suite_summary.json" % run_directory
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	if suite_id == "extreme_performance":
		_save_markdown_summary(report, run_directory)
	for result in report.get("results", []) as Array:
		var scenario_id := str((result as Dictionary).get("scenario_id", "scenario"))
		var scenario_file := FileAccess.open("%s/%s.json" % [run_directory, scenario_id], FileAccess.WRITE)
		if scenario_file != null:
			scenario_file.store_string(JSON.stringify(result, "  "))
			scenario_file.close()
	return ProjectSettings.globalize_path(path)


static func get_base_directory(suite_id: String) -> String:
	return DOCS_DIRECTORY if suite_id == "extreme_performance" else BASE_DIRECTORY


static func _save_markdown_summary(report: Dictionary, run_directory: String) -> void:
	var lines: Array[String] = [
		"# 武器技能测试场 · 性能测试",
		"",
		"时间：%s" % str(report.get("completed_at", "")),
		"",
		"固定负载：每项 120 个真实敌人；全部武器依次自动移动、持续攻击并周期性释放技能。每项预热 3 秒、采样 10 秒。",
		"",
		"| 武器 | 平均帧时间 (ms) | P95 (ms) | P99 (ms) | 最高敌人 | 敌人模拟累计 (ms) | 分离查询累计 (ms) |",
		"| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
	]
	for entry in report.get("results", []) as Array:
		var result := entry as Dictionary
		var query_profile := result.get("enemy_registry_query_profile", {}) as Dictionary
		var peaks := result.get("peaks", {}) as Dictionary
		lines.append("| %s | %.2f | %.2f | %.2f | %d | %.2f | %.2f |" % [
			str(result.get("weapon_label", result.get("scenario_id", ""))),
			float(result.get("average_frame_ms", 0.0)),
			float(result.get("p95_frame_ms", 0.0)),
			float(result.get("p99_frame_ms", 0.0)),
			int(peaks.get("enemies", 0)),
			float(result.get("enemy_simulation_total_ms", 0.0)),
			float(query_profile.get("separation_query_ms", 0.0)),
		])
	lines.append_array([
		"",
		"详细逐帧数据和环境信息见 `suite_summary.json`，各武器单项数据见同目录 JSON。",
		"",
		"注意：累计敌人模拟包含分离查询，不能把两列相加。它们记录的是整个采样窗口的 CPU 耗时，而不是单帧耗时；报告 JSON 同时提供物理 tick 数和测量时长。引擎物理、武器、特效、渲染与测试场开销未被精确拆分，监视器不能相加当作耗时占比。",
	])
	var file := FileAccess.open("%s/summary.md" % run_directory, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write performance Markdown summary: %s" % run_directory)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()


static func save_baseline(report: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE_DIRECTORY))
	var file := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	return true


static func compare_with_baseline(results: Array[Dictionary]) -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		return {"status": "no_baseline", "scenarios": {}}
	var file := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	if file == null:
		return {"status": "baseline_unreadable", "scenarios": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"status": "baseline_invalid", "scenarios": {}}
	var baseline_by_id := {}
	for entry in (parsed as Dictionary).get("results", []) as Array:
		if entry is Dictionary:
			baseline_by_id[str(entry.get("scenario_id", ""))] = entry
	var comparisons := {}
	for result in results:
		var scenario_id := str(result.get("scenario_id", ""))
		if not baseline_by_id.has(scenario_id):
			continue
		var baseline: Dictionary = baseline_by_id[scenario_id]
		var p99_change := _relative_change(float(result.get("p99_frame_ms", 0.0)), float(baseline.get("p99_frame_ms", 0.0)))
		var current_hitches := int((result.get("hitch_counts", {}) as Dictionary).get("33_33_ms", 0))
		var baseline_hitches := int((baseline.get("hitch_counts", {}) as Dictionary).get("33_33_ms", 0))
		var hitch_change := _relative_change(float(current_hitches), float(baseline_hitches))
		comparisons[scenario_id] = {
			"p99_change_ratio": p99_change,
			"hitch_change_ratio": hitch_change,
			"warning": p99_change > 0.15 or hitch_change > 0.25,
		}
	return {"status": "compared", "scenarios": comparisons}


static func _relative_change(current: float, baseline: float) -> float:
	if baseline <= 0.0:
		return 0.0 if current <= 0.0 else 1.0
	return (current - baseline) / baseline


static func _aggregate_repeats(results: Array[Dictionary]) -> Array[Dictionary]:
	var grouped := {}
	for result in results:
		var scenario_id := str(result.get("scenario_id", ""))
		if not grouped.has(scenario_id):
			grouped[scenario_id] = []
		(grouped[scenario_id] as Array).append(result)
	var aggregates: Array[Dictionary] = []
	for scenario_id in grouped:
		var entries := grouped[scenario_id] as Array
		var aggregate := {"scenario_id": scenario_id, "run_count": entries.size()}
		for metric in ["average_frame_ms", "p50_frame_ms", "p95_frame_ms", "p99_frame_ms", "maximum_frame_ms", "one_percent_low_fps"]:
			var values: Array[float] = []
			for entry in entries:
				values.append(float((entry as Dictionary).get(metric, 0.0)))
			values.sort()
			aggregate["median_%s" % metric] = values[values.size() / 2] if not values.is_empty() else 0.0
		aggregates.append(aggregate)
	return aggregates


static func _environment() -> Dictionary:
	return {
		"godot_version": Engine.get_version_info(),
		"os": OS.get_name(),
		"processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"viewport_size": [ProjectSettings.get_setting("display/window/size/viewport_width", 0), ProjectSettings.get_setting("display/window/size/viewport_height", 0)],
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
	}
