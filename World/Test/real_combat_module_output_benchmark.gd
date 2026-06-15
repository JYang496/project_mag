extends RealCombatDpsBenchmark
class_name RealCombatModuleOutputBenchmark

const MODULE_DIR := "res://Player/Weapons/Modules/"
const MODULE_REPORT_FILE_PREFIX := "real_combat_module_output"
const PREFERRED_WEAPON_IDS := [
	"5", "1", "4", "8", "17", "9", "21", "25", "26", "13", "2", "3", "10", "7", "11",
]
const FROST_STATE := {
	"scorch_stacks": 0,
	"scorch_expires_at_msec": 0,
	"scorch_dot_damage_per_stack": 1,
	"scorch_dot_accum_sec": 0.0,
	"scorch_source_node": null,
	"scorch_source_player": null,
	"processing_scorch_dot": false,
	"frost_stacks": 5,
	"frost_expires_at_msec": 2147483647,
	"frost_next_stack_at_msec": 2147483647,
	"energy_damage_recorded": 0,
	"scorch_max_hp": 1000000000,
}
const OUTPUT_CAPABLE_MODULE_IDS := {
	"wmod_battle_focus_buff": true,
	"wmod_bleed_edge_physical": true,
	"wmod_brittle_trigger_freeze": true,
	"wmod_corrosive_touch_energy": true,
	"wmod_cryo_infuser_freeze": true,
	"wmod_damage_up_stat": true,
	"wmod_dot_on_hit": true,
	"wmod_ember_mark_fire": true,
	"wmod_heat_capacity_heat": true,
	"wmod_heat_concentration_heat": true,
	"wmod_heat_vent_heat": true,
	"wmod_lightning_chain_on_hit": true,
	"wmod_molten_splash_fire": true,
	"wmod_momentum_haste": true,
	"wmod_overheat_boost_heat": true,
	"wmod_permafrost_field_freeze": true,
	"wmod_pierce_stat": true,
	"wmod_plague_seed_dot": true,
	"wmod_reload_blast_damage": true,
	"wmod_reload_damage_boost": true,
	"wmod_reload_speed_link": true,
	"wmod_shatter_strike_freeze": true,
	"wmod_trail_aoe_freeze": true,
}

@export_range(1, 12, 1) var target_count: int = 5
@export var target_spacing: float = 42.0
@export_range(0.0, 100.0, 0.1) var minimum_positive_percent: float = 0.1

var _current_module_path: String = ""
var _current_module_id: String = ""
var _current_module_name: String = ""
var _current_module_level: int = 0
var _current_condition: String = ""
var _all_targets: Array[Node] = []
var _movement_direction: float = 1.0
var _special_condition_primed: bool = false
var _reload_condition_requested: bool = false

func _build_case_queue() -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	var modules := _load_module_summaries()
	for module_data in modules:
		var module_path := str(module_data.get("path", ""))
		var weapon_id := _find_compatible_weapon_id(module_path)
		if weapon_id == "":
			push_warning("Module output benchmark: no compatible weapon for %s" % module_path)
			continue
		var common := {
			"weapon_id": weapon_id,
			"level": 1,
			"max_level": _get_weapon_max_benchmark_level(weapon_id),
			"module_path": module_path,
			"module_id": str(module_data.get("id", "")),
			"module_name": str(module_data.get("name", "")),
			"condition": str(module_data.get("condition", "")),
		}
		var baseline := common.duplicate(true)
		baseline["module_level"] = 0
		queue.append(baseline)
		for module_level in range(1, Module.MAX_LEVEL + 1):
			var module_case := common.duplicate(true)
			module_case["module_level"] = module_level
			queue.append(module_case)
	return queue

func _prepare_case(case_data: Dictionary) -> void:
	_current_module_path = str(case_data.get("module_path", ""))
	_current_module_id = str(case_data.get("module_id", ""))
	_current_module_name = str(case_data.get("module_name", ""))
	_current_module_level = int(case_data.get("module_level", 0))
	_current_condition = str(case_data.get("condition", ""))
	_special_condition_primed = false
	_reload_condition_requested = false
	await super._prepare_case(case_data)
	_prime_condition_state()

func _equip_weapon(weapon_id: String, level_value: int) -> void:
	super._equip_weapon(weapon_id, level_value)
	var weapon := _resolve_main_weapon_node() as Weapon
	if weapon == null:
		return
	_clear_weapon_modules(weapon)
	if _current_module_level > 0:
		var module_scene := load(_current_module_path) as PackedScene
		var module_instance := module_scene.instantiate() as Module if module_scene != null else null
		if module_instance == null:
			push_warning("Module output benchmark: cannot instantiate %s" % _current_module_path)
		else:
			module_instance.set_module_level(_current_module_level)
			weapon.modules.add_child(module_instance)
	weapon.calculate_status()

func _clear_weapon_modules(weapon: Weapon) -> void:
	if weapon.modules == null:
		return
	for child in weapon.modules.get_children():
		weapon.modules.remove_child(child)
		child.free()

func _spawn_target() -> void:
	_all_targets.clear()
	var offsets := [
		Vector2.ZERO,
		Vector2(target_spacing, 0.0),
		Vector2(-target_spacing, 0.0),
		Vector2(0.0, target_spacing),
		Vector2(0.0, -target_spacing),
		Vector2(target_spacing, target_spacing),
		Vector2(-target_spacing, target_spacing),
		Vector2(target_spacing, -target_spacing),
		Vector2(-target_spacing, -target_spacing),
	]
	for index in range(target_count):
		var dummy_instance := dummy_scene.instantiate()
		var dummy := dummy_instance as Node2D
		if dummy == null:
			continue
		if dummy.get("max_hp_value") != null:
			dummy.set("max_hp_value", max(1, target_hp))
		target_root.add_child(dummy)
		dummy.global_position = target_spawn.global_position + offsets[index % offsets.size()]
		if dummy.has_signal("damage_received"):
			dummy.connect("damage_received", Callable(self, "_on_dummy_damage_received"))
		if dummy.has_signal("dummy_died"):
			dummy.connect("dummy_died", Callable(self, "_on_dummy_died"))
		_all_targets.append(dummy)
		if _target == null:
			_target = dummy

func _prime_condition_state() -> void:
	for target in _all_targets:
		if target != null and is_instance_valid(target):
			target.set_meta("_incoming_damage_state", FROST_STATE.duplicate(true))
			if _current_module_id == "wmod_bleed_edge_physical" and target is Node2D:
				(target as Node2D).global_position.x += 8.0 * _movement_direction
	_movement_direction *= -1.0
	var weapon := _resolve_main_weapon_node()
	if weapon != null and weapon.has_method("lock_heat_value") and _current_module_id == "wmod_overheat_boost_heat":
		var heat_max := float(weapon.get("heat_max_value")) if weapon.get("heat_max_value") != null else 100.0
		weapon.call("lock_heat_value", heat_max, 30.0)
	elif weapon != null and weapon.has_method("lock_heat_value") and _current_module_id == "wmod_heat_concentration_heat":
		var heat_max := float(weapon.get("heat_max_value")) if weapon.get("heat_max_value") != null else 100.0
		weapon.call("lock_heat_value", heat_max * 0.9, 30.0)

func _step_weapon(record_stats: bool) -> void:
	_prime_condition_state()
	super._step_weapon(record_stats)
	_force_reload_condition()
	_prime_kill_condition()

func _force_reload_condition() -> void:
	if not _current_module_id.begins_with("wmod_reload_") or _reload_condition_requested or not _measurement_active:
		return
	var weapon := _resolve_main_weapon_node()
	if weapon == null or not weapon.has_method("request_reload"):
		return
	if bool(weapon.get("is_reloading")):
		return
	var capacity := int(weapon.get("magazine_capacity")) if weapon.get("magazine_capacity") != null else 0
	if capacity <= 0:
		return
	weapon.set("current_ammo", 0)
	weapon.set("reload_duration_sec", 0.25)
	_reload_condition_requested = bool(weapon.call("request_reload"))

func _prime_kill_condition() -> void:
	if _special_condition_primed or _current_module_level <= 0:
		return
	if _current_module_id != "wmod_permafrost_field_freeze":
		return
	var weapon := _resolve_main_weapon_node() as Weapon
	if weapon == null or weapon.modules == null or _all_targets.is_empty():
		return
	var target := _all_targets[0]
	if target == null or not is_instance_valid(target):
		return
	target.set("is_dead", true)
	for module_node in weapon.get_equipped_modules():
		if module_node.has_method("apply_on_hit"):
			module_node.call("apply_on_hit", weapon, target)
	target.set("is_dead", false)
	_special_condition_primed = true

func _build_result() -> Dictionary:
	var result := super._build_result()
	result["module_path"] = _current_module_path
	result["module_id"] = _current_module_id
	result["module_name"] = _current_module_name
	result["module_level"] = _current_module_level
	result["condition"] = _current_condition
	print("ModuleOutputResult: module=%s level=%d weapon=%s dps=%.3f damage=%d hits=%d" % [
		_current_module_id,
		_current_module_level,
		_current_weapon_id,
		float(result.get("dps", 0.0)),
		int(result.get("total_damage", 0)),
		int(result.get("hit_count", 0)),
	])
	return result

func _cleanup_case() -> void:
	_all_targets.clear()
	super._cleanup_case()

func _load_module_summaries() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var dir := DirAccess.open(MODULE_DIR)
	if dir == null:
		return output
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("wmod_") and file_name.ends_with(".tscn") \
				and file_name != "wmod_base.tscn":
			var path := MODULE_DIR + file_name
			var scene := load(path) as PackedScene
			var instance := scene.instantiate() as Module if scene != null else null
			if instance != null:
				output.append({
					"path": path,
					"id": file_name.get_basename(),
					"name": instance.get_module_display_name(),
					"condition": _describe_condition(instance),
				})
				instance.free()
		file_name = dir.get_next()
	dir.list_dir_end()
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")).naturalnocasecmp_to(str(b.get("id", ""))) < 0
	)
	return output

func _describe_condition(module: Module) -> String:
	var id := module.scene_file_path.get_file().get_basename()
	if id.contains("reload"):
		return "Continuous firing; reload trigger occurs naturally"
	if id == "wmod_overheat_boost_heat":
		return "Weapon held in overheated state"
	if id == "wmod_heat_concentration_heat":
		return "Heat locked at 90%"
	if id == "wmod_bleed_edge_physical":
		return "Continuous hits while targets move"
	if id == "wmod_permafrost_field_freeze":
		return "A frosted target is killed beside the target cluster"
	if id.contains("freeze") or id.contains("brittle") or id.contains("shatter") or id.contains("subzero") or id.contains("ice_prison"):
		return "Targets held at 5 frost stacks"
	if id.contains("battle_focus") or id.contains("momentum"):
		return "Continuous hits maintain maximum practical stacks"
	if id.contains("corrosive"):
		return "Continuous hits maintain corrosion stacks"
	return "Continuous fire into a five-target cluster"

func _find_compatible_weapon_id(module_path: String) -> String:
	var module_scene := load(module_path) as PackedScene
	var module := module_scene.instantiate() as Module if module_scene != null else null
	if module == null:
		return ""
	var ids := DataHandler.get_weapon_ids()
	var ordered_ids: Array[String] = []
	for preferred_id in PREFERRED_WEAPON_IDS:
		if ids.has(preferred_id):
			ordered_ids.append(preferred_id)
	for id in ids:
		if not ordered_ids.has(id):
			ordered_ids.append(id)
	for weapon_id in ordered_ids:
		var definition: Variant = DataHandler.read_weapon_data(weapon_id)
		var scene := definition.get("scene") as PackedScene if definition != null else null
		var weapon := scene.instantiate() as Weapon if scene != null else null
		if weapon == null:
			continue
		var compatible := module.can_apply_to_weapon(weapon)
		weapon.free()
		if compatible:
			module.free()
			return weapon_id
	module.free()
	return ""

func _write_html_report() -> String:
	_ensure_report_dir(report_dir)
	var stamp := _build_file_stamp()
	var path := "%s/%s_%s.html" % [report_dir, MODULE_REPORT_FILE_PREFIX, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Module output benchmark: failed to open %s" % path)
		return ""
	file.store_string(_build_module_html(stamp))
	file.close()
	if not quit_on_completion:
		call_deferred("_quit_after_report_cleanup")
	return path

func _quit_after_report_cleanup() -> void:
	_cleanup_case()
	for _index in range(4):
		await get_tree().physics_frame
	get_tree().quit(0)

func _build_module_html(stamp: String) -> String:
	var baseline_by_module: Dictionary = {}
	for result in _results:
		if int(result.get("module_level", 0)) == 0:
			baseline_by_module[str(result.get("module_id", ""))] = float(result.get("dps", 0.0))
	var rows := PackedStringArray()
	var positive_modules: Dictionary = {}
	for result in _results:
		var module_level := int(result.get("module_level", 0))
		if module_level <= 0:
			continue
		var module_id := str(result.get("module_id", ""))
		if not OUTPUT_CAPABLE_MODULE_IDS.has(module_id):
			continue
		var baseline := float(baseline_by_module.get(module_id, 0.0))
		var module_dps := float(result.get("dps", 0.0))
		var delta := module_dps - baseline
		var percent := (delta / baseline * 100.0) if baseline > 0.0 else INF
		if delta <= 0.0 or (baseline > 0.0 and percent < minimum_positive_percent):
			continue
		positive_modules[module_id] = true
	for result in _results:
		var module_level := int(result.get("module_level", 0))
		var module_id := str(result.get("module_id", ""))
		if module_level <= 0 or not positive_modules.has(module_id):
			continue
		var baseline := float(baseline_by_module.get(module_id, 0.0))
		var module_dps := float(result.get("dps", 0.0))
		var delta := module_dps - baseline
		var percent := (delta / baseline * 100.0) if baseline > 0.0 else INF
		var percent_text := "%+.2f%%" % percent if baseline > 0.0 else "Baseline 0"
		rows.append("<tr><td>%s</td><td>%s</td><td>%s</td><td>%d</td><td>%.3f</td><td>%.3f</td><td>%+.3f</td><td>%s</td><td>%s</td></tr>" % [
			_html_escape(module_id),
			_html_escape(str(result.get("module_name", ""))),
			_html_escape("%s · %s" % [str(result.get("weapon_name", "")), str(result.get("weapon_id", ""))]),
			module_level,
			baseline,
			module_dps,
			delta,
			_html_escape(percent_text),
			_html_escape(str(result.get("condition", ""))),
		])
	return """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>模组实际输出提升测试</title>
<style>body{margin:0;padding:32px;background:#f5f7fb;color:#1f2937;font-family:Arial,"Microsoft YaHei",sans-serif}h1{margin:0 0 8px}.meta{color:#64748b;margin-bottom:20px}table{width:100%%;border-collapse:collapse;background:#fff}th,td{padding:9px 10px;border:1px solid #e5eaf1;text-align:left;font-size:13px}th{background:#eef2f7;position:sticky;top:0}tr:nth-child(even) td{background:#fafbfd}</style>
</head><body><h1>模组实际输出提升测试</h1>
<p class="meta">生成时间：%s | 测试模组：%d | 实际提升输出的模组：%d | 每档测试时长：%.1fs | 目标数：%d。仅显示相对无模组基线产生正向实际伤害提升的结果。</p>
<table><thead><tr><th>模组 ID</th><th>模组</th><th>测试武器</th><th>模组等级</th><th>基线 DPS</th><th>模组 DPS</th><th>DPS 提升</th><th>提升比例</th><th>满足条件</th></tr></thead>
<tbody>%s</tbody></table></body></html>""" % [
		_html_escape(stamp),
		baseline_by_module.size(),
		positive_modules.size(),
		test_duration_sec,
		target_count,
		"\n".join(rows),
	]
