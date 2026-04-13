extends Node2D

const MODULE_DIR := "res://Player/Weapons/Modules"
const REPORT_PATH := "res://docs/weapon_module_regression_report.csv"
const BALANCE_PATH := "res://docs/weapon_balance_snapshot.csv"
const EPSILON := 0.0001

@onready var result_label: Label = $ResultLabel

var _logs: PackedStringArray = []
var _failure_count: int = 0
var _warning_count: int = 0
var _compat_rows: Array[Dictionary] = []
var _balance_rows: Array[Dictionary] = []

func _ready() -> void:
	DataHandler.load_weapon_data()
	DataHandler.load_weapon_branch_data()
	await _run_all()
	var status: String = "PASS" if _failure_count == 0 else "FAIL (%d)" % _failure_count
	_log("==== Weapon/Module Regression: %s; warnings=%d ====" % [status, _warning_count])
	_write_reports()
	result_label.text = "\n".join(_logs)
	get_tree().quit(1 if _failure_count > 0 else 0)

func _run_all() -> void:
	var weapon_defs := _get_weapon_definitions()
	var module_defs := _get_module_scene_defs()
	_expect(not weapon_defs.is_empty(), "weapon definitions loaded")
	_expect(not module_defs.is_empty(), "module scenes loaded")
	if weapon_defs.is_empty() or module_defs.is_empty():
		return
	await _test_compatibility_matrix(weapon_defs, module_defs)
	await _test_stability_smoke(weapon_defs, module_defs)
	await _test_balance_sanity(weapon_defs)

func _test_compatibility_matrix(weapon_defs: Array[WeaponDefinition], module_defs: Array[Dictionary]) -> void:
	for weapon_def in weapon_defs:
		var weapon := await _spawn_weapon(weapon_def)
		if weapon == null:
			continue
		await _scan_weapon_module_compatibility(weapon, module_defs, "")
		var branch_options: Array[WeaponBranchDefinition] = DataHandler.read_weapon_branch_options(weapon.scene_file_path, 999)
		for branch_def in branch_options:
			weapon.fuse = maxi(weapon.fuse, int(branch_def.unlock_fuse))
			var applied: bool = weapon.set_branch(branch_def.branch_id)
			_expect(applied, "%s set_branch(%s) succeeds" % [weapon_def.display_name, branch_def.branch_id])
			if not applied:
				continue
			await get_tree().process_frame
			await _scan_weapon_module_compatibility(weapon, module_defs, branch_def.branch_id)
		weapon.queue_free()
		await get_tree().process_frame

func _scan_weapon_module_compatibility(weapon: Weapon, module_defs: Array[Dictionary], branch_id: String) -> void:
	for module_def in module_defs:
		var module_node := _new_module_instance(module_def)
		if module_node == null:
			continue
		var reason := module_node.get_incompatibility_reason(weapon)
		var compatible := reason == ""
		var feedback := InventoryData.get_weapon_module_assignment_feedback(module_node, weapon)
		var feedback_ok := bool(feedback.get("ok", false))
		_expect(
			feedback_ok == compatible,
			"feedback consistency %s/%s/%s" % [_weapon_name(weapon), branch_id if branch_id != "" else "base", str(module_def.get("name", ""))]
		)
		_compat_rows.append({
			"weapon": _weapon_name(weapon),
			"branch": branch_id if branch_id != "" else "base",
			"module": str(module_def.get("name", "")),
			"compatible": "1" if compatible else "0",
			"reason": reason if reason != "" else "-",
		})
		module_node.free()

func _test_stability_smoke(weapon_defs: Array[WeaponDefinition], module_defs: Array[Dictionary]) -> void:
	for weapon_def in weapon_defs:
		var weapon := await _spawn_weapon(weapon_def)
		if weapon == null:
			continue
		var max_level := _get_defined_max_level(weapon)
		if weapon.has_method("set_level"):
			weapon.call("set_level", max_level)
		weapon.calculate_status()
		await get_tree().process_frame
		var equipped := 0
		for module_def in module_defs:
			if equipped >= int(weapon.MAX_MODULE_NUMBER):
				break
			var module_node := _new_module_instance(module_def)
			if module_node == null:
				continue
			if not module_node.can_apply_to_weapon(weapon):
				module_node.free()
				continue
			var before_snapshot: Dictionary = weapon.build_stat_snapshot()
			weapon.modules.add_child(module_node)
			await get_tree().process_frame
			weapon.calculate_status()
			await get_tree().process_frame
			_validate_module_stat_expectation(module_node, before_snapshot, weapon.build_stat_snapshot(), weapon)
			equipped += 1
		_expect(weapon.get_module_count() <= int(weapon.MAX_MODULE_NUMBER), "%s module slot cap honored" % weapon_def.display_name)
		var branch_options: Array[WeaponBranchDefinition] = DataHandler.read_weapon_branch_options(weapon.scene_file_path, 999)
		for branch_def in branch_options:
			weapon.fuse = maxi(weapon.fuse, int(branch_def.unlock_fuse))
			var applied: bool = weapon.set_branch(branch_def.branch_id)
			_expect(applied, "%s branch %s can apply in smoke test" % [weapon_def.display_name, branch_def.branch_id])
			if not applied:
				continue
			if weapon.has_method("set_level"):
				weapon.call("set_level", max_level)
			weapon.calculate_status()
			await get_tree().process_frame
		weapon.queue_free()
		await get_tree().process_frame

func _validate_module_stat_expectation(module_node: Module, before_snapshot: Dictionary, after_snapshot: Dictionary, weapon: Weapon) -> void:
	module_node.configure_stat_modifiers()
	var changed := false
	for key_variant in module_node.stat_multipliers.keys():
		var key := str(key_variant)
		if not before_snapshot.has(key) or not after_snapshot.has(key):
			continue
		var before_value := float(before_snapshot[key])
		var after_value := float(after_snapshot[key])
		if absf(after_value - before_value) > EPSILON:
			changed = true
			break
	for key_variant in module_node.stat_additives.keys():
		var key := str(key_variant)
		if not before_snapshot.has(key) or not after_snapshot.has(key):
			continue
		var before_value := float(before_snapshot[key])
		var after_value := float(after_snapshot[key])
		if absf(after_value - before_value) > EPSILON:
			changed = true
			break
	if not module_node.stat_multipliers.is_empty() or not module_node.stat_additives.is_empty():
		_expect(changed, "%s stat modifiers affect %s snapshot" % [module_node.get_module_display_name(), _weapon_name(weapon)])

func _test_balance_sanity(weapon_defs: Array[WeaponDefinition]) -> void:
	for weapon_def in weapon_defs:
		var weapon := await _spawn_weapon(weapon_def)
		if weapon == null:
			continue
		var max_level := _get_defined_max_level(weapon)
		var base_metrics := _capture_metrics(weapon, 1, "base")
		var max_metrics := _capture_metrics(weapon, max_level, "base")
		_validate_metrics(weapon_def.display_name, "base", base_metrics)
		_validate_metrics(weapon_def.display_name, "base", max_metrics)
		_validate_growth_reasonable(weapon_def.display_name, base_metrics, max_metrics)
		_balance_rows.append(base_metrics)
		_balance_rows.append(max_metrics)
		var branch_options: Array[WeaponBranchDefinition] = DataHandler.read_weapon_branch_options(weapon.scene_file_path, 999)
		for branch_def in branch_options:
			weapon.fuse = maxi(weapon.fuse, int(branch_def.unlock_fuse))
			var applied := weapon.set_branch(branch_def.branch_id)
			_expect(applied, "%s branch %s can apply in balance test" % [weapon_def.display_name, branch_def.branch_id])
			if not applied:
				continue
			var branch_metrics := _capture_metrics(weapon, max_level, branch_def.branch_id)
			_validate_metrics(weapon_def.display_name, branch_def.branch_id, branch_metrics)
			_balance_rows.append(branch_metrics)
		weapon.queue_free()
		await get_tree().process_frame

func _capture_metrics(weapon: Weapon, level: int, branch_id: String) -> Dictionary:
	if weapon.has_method("set_level"):
		weapon.call("set_level", maxi(level, 1))
	weapon.calculate_status()
	var damage := 0.0
	if weapon.has_method("get_runtime_shot_damage"):
		damage = float(weapon.call("get_runtime_shot_damage"))
	elif weapon.get("damage") != null:
		damage = float(weapon.get("damage"))
	elif weapon.get("base_damage") != null:
		damage = float(weapon.get("base_damage"))
	var cooldown := 0.0
	if weapon.get("attack_cooldown") != null:
		cooldown = float(weapon.get("attack_cooldown"))
	elif weapon.get("base_attack_cooldown") != null:
		cooldown = float(weapon.get("base_attack_cooldown"))
	var hit_cd := 0.0
	if weapon.get("hit_cd") != null:
		hit_cd = float(weapon.get("hit_cd"))
	var range_value := 0.0
	if weapon.get("attack_range") != null:
		range_value = float(weapon.get("attack_range"))
	elif weapon.get("beam_range") != null:
		range_value = float(weapon.get("beam_range"))
	var shot_dps := damage / cooldown if cooldown > EPSILON else 0.0
	var tick_dps := damage / hit_cd if hit_cd > EPSILON else 0.0
	return {
		"weapon": _weapon_name(weapon),
		"branch": branch_id,
		"level": str(maxi(level, 1)),
		"damage": "%.3f" % damage,
		"cooldown": "%.4f" % cooldown,
		"hit_cd": "%.4f" % hit_cd,
		"shot_dps_proxy": "%.3f" % shot_dps,
		"tick_dps_proxy": "%.3f" % tick_dps,
		"range": "%.2f" % range_value,
	}

func _validate_metrics(weapon_name: String, branch_id: String, metrics: Dictionary) -> void:
	var suffix := "%s/%s" % [weapon_name, branch_id]
	var damage := float(metrics.get("damage", "0"))
	var cooldown := float(metrics.get("cooldown", "0"))
	var hit_cd := float(metrics.get("hit_cd", "0"))
	var shot_dps := float(metrics.get("shot_dps_proxy", "0"))
	var tick_dps := float(metrics.get("tick_dps_proxy", "0"))
	var range_value := float(metrics.get("range", "0"))
	_expect(damage > 0.0 and damage <= 10000.0, "%s damage in sane range" % suffix)
	_expect(cooldown > 0.0 and cooldown <= 30.0, "%s cooldown in sane range" % suffix)
	if hit_cd > 0.0:
		_expect(hit_cd >= 0.01 and hit_cd <= 5.0, "%s hit_cd in sane range" % suffix)
	_expect(shot_dps >= 0.0 and shot_dps <= 100000.0, "%s shot DPS proxy sane" % suffix)
	if tick_dps > 0.0:
		_expect(tick_dps <= 100000.0, "%s tick DPS proxy sane" % suffix)
	if range_value > 0.0:
		_expect(range_value <= 5000.0, "%s range sane" % suffix)

func _validate_growth_reasonable(weapon_name: String, base_metrics: Dictionary, max_metrics: Dictionary) -> void:
	var base_damage := float(base_metrics.get("damage", "0"))
	var max_damage := float(max_metrics.get("damage", "0"))
	if base_damage > 0.0 and max_damage < base_damage * 0.5:
		_warn("%s max damage significantly below lv1 (%.2f -> %.2f)" % [weapon_name, base_damage, max_damage])
	var base_dps := float(base_metrics.get("shot_dps_proxy", "0"))
	var max_dps := float(max_metrics.get("shot_dps_proxy", "0"))
	if base_dps > 0.0 and max_dps < base_dps * 0.5:
		_warn("%s max shot DPS proxy significantly below lv1 (%.2f -> %.2f)" % [weapon_name, base_dps, max_dps])

func _get_weapon_definitions() -> Array[WeaponDefinition]:
	var output: Array[WeaponDefinition] = []
	for key_variant in GlobalVariables.weapon_list.keys():
		var weapon_def := DataHandler.read_weapon_data(str(key_variant)) as WeaponDefinition
		if weapon_def == null or weapon_def.scene == null:
			continue
		output.append(weapon_def)
	return output

func _get_module_scene_defs() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var dir := DirAccess.open(MODULE_DIR)
	if dir == null:
		return output
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn") and file_name != "wmod_base.tscn":
			var path := "%s/%s" % [MODULE_DIR, file_name]
			var scene := load(path) as PackedScene
			if scene:
				output.append({
					"name": file_name.trim_suffix(".tscn"),
					"path": path,
					"scene": scene,
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	return output

func _new_module_instance(module_def: Dictionary) -> Module:
	var scene := module_def.get("scene") as PackedScene
	if scene == null:
		_fail("module scene missing: %s" % str(module_def.get("path", "")))
		return null
	var instance := scene.instantiate() as Module
	if instance == null:
		_fail("module instantiate failed: %s" % str(module_def.get("path", "")))
		return null
	return instance

func _spawn_weapon(weapon_def: WeaponDefinition) -> Weapon:
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		_fail("weapon instantiate failed: %s" % weapon_def.display_name)
		return null
	add_child(weapon)
	await get_tree().process_frame
	return weapon

func _get_defined_max_level(weapon: Weapon) -> int:
	var max_level := 1
	var data_variant: Variant = weapon.get("weapon_data")
	if data_variant is Dictionary:
		var data: Dictionary = data_variant
		for key_variant in data.keys():
			var lv := int(str(key_variant))
			max_level = maxi(max_level, lv)
	return max_level

func _weapon_name(weapon: Weapon) -> String:
	var item_name: Variant = weapon.get("ITEM_NAME")
	if item_name != null and str(item_name) != "":
		return str(item_name)
	return weapon.name

func _write_reports() -> void:
	_write_compat_report()
	_write_balance_report()

func _write_compat_report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_warn("failed to write report: %s" % REPORT_PATH)
		return
	file.store_line("weapon,branch,module,compatible,reason")
	for row in _compat_rows:
		file.store_line(_csv_line([
			row.get("weapon", ""),
			row.get("branch", ""),
			row.get("module", ""),
			row.get("compatible", ""),
			row.get("reason", ""),
		]))
	file.close()
	_log("compatibility report: %s" % REPORT_PATH)

func _write_balance_report() -> void:
	var file := FileAccess.open(BALANCE_PATH, FileAccess.WRITE)
	if file == null:
		_warn("failed to write report: %s" % BALANCE_PATH)
		return
	file.store_line("weapon,branch,level,damage,cooldown,hit_cd,shot_dps_proxy,tick_dps_proxy,range")
	for row in _balance_rows:
		file.store_line(_csv_line([
			row.get("weapon", ""),
			row.get("branch", ""),
			row.get("level", ""),
			row.get("damage", ""),
			row.get("cooldown", ""),
			row.get("hit_cd", ""),
			row.get("shot_dps_proxy", ""),
			row.get("tick_dps_proxy", ""),
			row.get("range", ""),
		]))
	file.close()
	_log("balance report: %s" % BALANCE_PATH)

func _csv_line(values: Array) -> String:
	var escaped: PackedStringArray = []
	for value in values:
		escaped.append(_csv_cell(str(value)))
	return ",".join(escaped)

func _csv_cell(raw: String) -> String:
	var needs_quotes := raw.contains(",") or raw.contains("\"") or raw.contains("\n") or raw.contains("\r")
	var normalized := raw.replace("\"", "\"\"")
	if needs_quotes:
		return "\"%s\"" % normalized
	return normalized

func _expect(condition: bool, message: String) -> void:
	if condition:
		_log("[PASS] %s" % message)
		return
	_fail(message)

func _warn(message: String) -> void:
	_warning_count += 1
	_log("[WARN] %s" % message)

func _fail(message: String) -> void:
	_failure_count += 1
	_log("[FAIL] %s" % message)

func _log(message: String) -> void:
	print(message)
	_logs.append(message)
