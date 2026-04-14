extends Node2D

const MODULE_DIR := "res://Player/Weapons/Modules"
const DUMMY_SCENE := preload("res://Utility/tests/benchmark_dummy_enemy.tscn")
const REPORT_CSV_PATH := "res://docs/weapon_module_dps_report.csv"
const REPORT_MD_PATH := "res://docs/weapon_module_dps_summary.md"

const WINDOW_SEC: float = 10.0
const REPEATS: int = 3
const BASE_SEED: int = 424242
const DT_SEC: float = 0.1
const MAX_PAIR_CASES_PER_BRANCH: int = 24
const MAX_BUDGET_SEC: float = 30.0 * 60.0
const PROGRESS_LOG_EVERY_CASES: int = 10
const PARTIAL_MD_EVERY_CASES: int = 50

@onready var result_label: Label = $ResultLabel

var _rows: Array[Dictionary] = []
var _logs: PackedStringArray = []
var _timed_out: bool = false
var _start_msec: int = 0
var _run_end_msec: int = 0
var _case_counter: int = 0
var _csv_initialized: bool = false
var _last_scope: String = ""

class MockBenchmarkPlayer:
	extends Node2D
	var _move_speed_mul_modifiers: Dictionary = {}
	var _damage_mul_modifiers: Dictionary = {}
	var _bonus_hit_modifiers: Dictionary = {}

	func apply_move_speed_mul(source_id: StringName, mul: float) -> void:
		if source_id == StringName():
			return
		_move_speed_mul_modifiers[source_id] = clampf(mul, 0.05, 10.0)

	func remove_move_speed_mul(source_id: StringName) -> void:
		if _move_speed_mul_modifiers.has(source_id):
			_move_speed_mul_modifiers.erase(source_id)

	func apply_damage_mul(source_id: StringName, mul: float) -> void:
		if source_id == StringName():
			return
		_damage_mul_modifiers[source_id] = maxf(mul, 0.05)

	func remove_damage_mul(source_id: StringName) -> void:
		if _damage_mul_modifiers.has(source_id):
			_damage_mul_modifiers.erase(source_id)

	func compute_outgoing_damage(base_damage: int) -> int:
		var total_mul_delta := 0.0
		for mul in _damage_mul_modifiers.values():
			total_mul_delta += (float(mul) - 1.0)
		var final_mul := maxf(0.05, 1.0 + total_mul_delta)
		return max(1, int(round(float(base_damage) * final_mul)))

	func register_bonus_hit(source_id: StringName, chance: float, damage: int) -> void:
		if source_id == StringName():
			return
		_bonus_hit_modifiers[source_id] = {
			"chance": clampf(chance, 0.0, 1.0),
			"damage": max(1, damage),
		}

	func remove_bonus_hit(source_id: StringName) -> void:
		if _bonus_hit_modifiers.has(source_id):
			_bonus_hit_modifiers.erase(source_id)

	func apply_bonus_hit_if_needed(target: Node) -> void:
		if target == null or not is_instance_valid(target):
			return
		if not target.has_method("damaged"):
			return
		for data in _bonus_hit_modifiers.values():
			var chance := float(data.get("chance", 0.0))
			var bonus_damage := int(data.get("damage", 1))
			if randf() > chance:
				continue
			var attack := Attack.new()
			attack.damage = bonus_damage
			attack.damage_type = Attack.TYPE_PHYSICAL
			attack.source_node = self
			attack.source_player = self
			target.call("damaged", attack)

func _ready() -> void:
	result_label.text = "Running weapon/module DPS benchmark..."
	DataHandler.load_weapon_data()
	DataHandler.load_weapon_branch_data()
	_start_msec = Time.get_ticks_msec()
	_init_csv_report()
	_log("benchmark start, budget_sec=%.1f, pair_cap=%d" % [MAX_BUDGET_SEC, MAX_PAIR_CASES_PER_BRANCH])
	await _run_benchmark()
	_run_end_msec = Time.get_ticks_msec()
	_write_csv_report()
	_write_markdown_report(false)
	var status: String = "TIMEOUT" if _timed_out else "PASS"
	_log("==== Weapon/Module DPS Benchmark: %s ====" % status)
	result_label.text = "\n".join(_logs)
	get_tree().quit(0)

func _run_benchmark() -> void:
	var weapon_defs := _get_weapon_definitions()
	var module_defs := _get_module_scene_defs()
	_log("weapons loaded: %d" % weapon_defs.size())
	_log("modules loaded: %d" % module_defs.size())
	for weapon_def in weapon_defs:
		var branch_ids := _get_branch_ids(weapon_def)
		_log("weapon '%s' branches: %d" % [weapon_def.display_name, branch_ids.size()])
		for branch_id in branch_ids:
			if _is_budget_exceeded():
				_timed_out = true
				return
			await _run_branch_benchmark(weapon_def, branch_id, module_defs)

func _run_branch_benchmark(weapon_def: WeaponDefinition, branch_id: String, module_defs: Array[Dictionary]) -> void:
	var branch_name := branch_id if branch_id != "" else "base"
	_last_scope = "%s/%s" % [weapon_def.display_name, branch_name]
	_log("branch start: %s" % _last_scope)
	var weapon := await _spawn_weapon_instance(weapon_def, branch_id)
	if weapon == null:
		_log("branch skip (weapon spawn failed): %s" % _last_scope)
		return
	var compatible_modules := _get_compatible_module_defs(weapon, module_defs)
	compatible_modules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	var pair_combos := _build_pair_combos(compatible_modules)
	var pair_total: int = pair_combos.size()
	var pair_tested: int = mini(pair_total, MAX_PAIR_CASES_PER_BRANCH)
	pair_combos = pair_combos.slice(0, pair_tested)

	var all_combos: Array[Array] = [[]]
	for module_def in compatible_modules:
		all_combos.append([module_def])
	for pair in pair_combos:
		all_combos.append(pair)

	for combo in all_combos:
		if _is_budget_exceeded():
			_timed_out = true
			_log("budget exceeded during %s" % _last_scope)
			break
		var combo_name := _combo_to_name(combo)
		for profile in [&"single", &"group5"]:
			var run_ms_start := Time.get_ticks_msec()
			var total_damage_accum: float = 0.0
			var dps_accum: float = 0.0
			for repeat_idx in range(REPEATS):
				var repeat_seed: int = BASE_SEED + repeat_idx * 7919 + hash("%s|%s|%s|%s" % [
					weapon_def.display_name,
					branch_id if branch_id != "" else "base",
					combo_name,
					String(profile),
				])
				seed(repeat_seed)
				var run_damage: float = await _run_single_measurement(weapon_def, branch_id, combo, profile)
				total_damage_accum += run_damage
				dps_accum += run_damage / WINDOW_SEC
			var row := {
				"weapon": weapon_def.display_name,
				"branch": branch_id if branch_id != "" else "base",
				"module_combo": combo_name,
				"target_profile": String(profile),
				"window_sec": WINDOW_SEC,
				"repeats": REPEATS,
				"seed": BASE_SEED,
				"avg_dps": dps_accum / float(REPEATS),
				"total_damage_avg": total_damage_accum / float(REPEATS),
				"run_ms": Time.get_ticks_msec() - run_ms_start,
				"compatible_pair_total": pair_total,
				"compatible_pair_tested": pair_tested,
				"pair_coverage_ratio": float(pair_tested) / float(pair_total) if pair_total > 0 else 1.0,
			}
			_rows.append(row)
			_append_csv_row(row)
			_case_counter += 1
			if _case_counter % PROGRESS_LOG_EVERY_CASES == 0:
				_log("cases finished: %d (latest: %s / %s / %s)" % [
					_case_counter,
					weapon_def.display_name,
					branch_name,
					combo_name,
				])
			if _case_counter % PARTIAL_MD_EVERY_CASES == 0:
				_write_markdown_report(true)
		await get_tree().process_frame
	weapon.queue_free()
	await get_tree().process_frame

func _run_single_measurement(weapon_def: WeaponDefinition, branch_id: String, combo: Array, profile: StringName) -> float:
	PlayerData.reset_runtime_state()
	PlayerData.player_max_hp = 1000
	PlayerData.player_hp = 1000

	var root := Node2D.new()
	add_child(root)
	var player: MockBenchmarkPlayer = MockBenchmarkPlayer.new()
	root.add_child(player)
	PlayerData.set("player", player)

	var weapon: Weapon = await _spawn_weapon_instance(weapon_def, branch_id, player)
	if weapon == null:
		root.queue_free()
		await get_tree().process_frame
		return 0.0
	_set_subtree_process_enabled(weapon, false)
	PlayerData.player_weapon_list = [weapon]
	PlayerData.set_main_weapon_index(0)
	if weapon.has_method("set_weapon_role"):
		weapon.call("set_weapon_role", "main")

	await _equip_modules(weapon, combo)
	weapon.calculate_status()
	await get_tree().process_frame

	var enemies := _spawn_dummy_targets(root, profile)
	var sim_time: float = 0.0
	var next_fire_time: float = 0.0
	while sim_time < WINDOW_SEC:
		_tick_module_nodes(weapon, DT_SEC)
		for enemy_variant in enemies:
			var enemy: Node = enemy_variant as Node
			if enemy != null and is_instance_valid(enemy) and enemy.has_method("tick_benchmark"):
				enemy.call("tick_benchmark", DT_SEC)
		if sim_time + 0.0001 >= next_fire_time:
			_simulate_hit(weapon, enemies)
			next_fire_time += _resolve_fire_interval(weapon)
		sim_time += DT_SEC

	var total_damage := 0.0
	for enemy_variant in enemies:
		var enemy: Node = enemy_variant as Node
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("get_total_damage_taken"):
			total_damage += float(enemy.call("get_total_damage_taken"))
	root.queue_free()
	await get_tree().process_frame
	return total_damage

func _spawn_dummy_targets(parent: Node, profile: StringName) -> Array:
	var output: Array = []
	var positions: Array[Vector2] = [Vector2(180.0, 0.0)]
	if profile == &"group5":
		positions = [
			Vector2(180.0, 0.0),
			Vector2(205.0, -18.0),
			Vector2(205.0, 18.0),
			Vector2(230.0, 0.0),
			Vector2(185.0, 30.0),
		]
	for pos in positions:
		var enemy: Node = DUMMY_SCENE.instantiate()
		if enemy == null:
			continue
		parent.add_child(enemy)
		if enemy is Node2D:
			(enemy as Node2D).global_position = pos
		if enemy.has_method("reset_runtime"):
			enemy.call("reset_runtime")
		output.append(enemy)
	return output

func _equip_modules(weapon: Weapon, combo: Array) -> void:
	if weapon == null or weapon.modules == null:
		return
	for module_def in combo:
		var scene := module_def.get("scene") as PackedScene
		if scene == null:
			continue
		var module_instance := scene.instantiate() as Module
		if module_instance == null:
			continue
		module_instance.set_module_level(1)
		weapon.modules.add_child(module_instance)
	await get_tree().process_frame
	weapon.calculate_status()

func _simulate_hit(source_weapon: Weapon, enemies: Array) -> void:
	if source_weapon == null or enemies.is_empty():
		return
	var primary: Node = enemies[0] as Node
	if primary == null or not is_instance_valid(primary):
		return
	var base_damage: int = 1
	if source_weapon.has_method("get_runtime_shot_damage"):
		base_damage = max(1, int(source_weapon.call("get_runtime_shot_damage")))
	elif source_weapon.get("damage") != null:
		base_damage = max(1, int(source_weapon.get("damage")))
	var damage_type := _resolve_damage_type(source_weapon)
	var damage_data := DamageManager.build_damage_data(
		source_weapon,
		base_damage,
		damage_type,
		{"amount": 0, "angle": Vector2.ZERO}
	)
	DamageManager.apply_to_target(primary, damage_data)
	source_weapon.on_hit_target(primary)
	if PlayerData.player != null and is_instance_valid(PlayerData.player) and PlayerData.player.has_method("apply_bonus_hit_if_needed"):
		PlayerData.player.call("apply_bonus_hit_if_needed", primary)

func _resolve_damage_type(weapon: Weapon) -> StringName:
	if weapon == null:
		return Attack.TYPE_PHYSICAL
	if weapon.has_method("has_weapon_trait"):
		if bool(weapon.call("has_weapon_trait", CombatTrait.FREEZE)):
			return Attack.TYPE_FREEZE
		if bool(weapon.call("has_weapon_trait", CombatTrait.FIRE)):
			return Attack.TYPE_FIRE
		if bool(weapon.call("has_weapon_trait", CombatTrait.ENERGY)):
			return Attack.TYPE_ENERGY
	if weapon.get("branch_behavior") != null:
		var branch_behavior: Node = weapon.get("branch_behavior")
		if branch_behavior != null and is_instance_valid(branch_behavior) and branch_behavior.has_method("get_damage_type_override"):
			return Attack.normalize_damage_type(branch_behavior.call("get_damage_type_override"))
	return Attack.TYPE_PHYSICAL

func _resolve_fire_interval(weapon: Weapon) -> float:
	var cooldown := 0.3
	if weapon.get("attack_cooldown") != null:
		cooldown = maxf(float(weapon.get("attack_cooldown")), 0.02)
	var hit_cd := -1.0
	if weapon.get("hit_cd") != null:
		hit_cd = maxf(float(weapon.get("hit_cd")), 0.01)
	if weapon.has_method("get_effective_cooldown"):
		cooldown = maxf(float(weapon.call("get_effective_cooldown", cooldown)), 0.01)
	if hit_cd > 0.0:
		return maxf(minf(cooldown, hit_cd), 0.01)
	return maxf(cooldown, 0.01)

func _tick_module_nodes(weapon: Weapon, delta: float) -> void:
	if weapon == null or weapon.modules == null:
		return
	for child in weapon.modules.get_children():
		if child != null and is_instance_valid(child) and child.has_method("_physics_process"):
			child.call("_physics_process", delta)

func _set_subtree_process_enabled(node: Node, enabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_process(enabled)
	node.set_physics_process(enabled)
	for child in node.get_children():
		if child is Node:
			_set_subtree_process_enabled(child as Node, enabled)

func _get_weapon_definitions() -> Array[WeaponDefinition]:
	var output: Array[WeaponDefinition] = []
	for key_variant in GlobalVariables.weapon_list.keys():
		var def := DataHandler.read_weapon_data(str(key_variant)) as WeaponDefinition
		if def == null or def.scene == null:
			continue
		output.append(def)
	output.sort_custom(func(a: WeaponDefinition, b: WeaponDefinition) -> bool:
		return a.display_name < b.display_name
	)
	return output

func _get_branch_ids(weapon_def: WeaponDefinition) -> PackedStringArray:
	var ids: PackedStringArray = [""]
	if weapon_def == null or weapon_def.scene == null:
		return ids
	var scene_path := weapon_def.scene.resource_path
	if scene_path == "":
		return ids
	var branch_defs := DataHandler.read_weapon_branch_options(scene_path, 999)
	for branch_def in branch_defs:
		if branch_def == null:
			continue
		var branch_id := str(branch_def.branch_id).strip_edges()
		if branch_id == "":
			continue
		ids.append(branch_id)
	return ids

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
			if scene != null:
				output.append({
					"name": file_name.trim_suffix(".tscn"),
					"path": path,
					"scene": scene,
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return output

func _get_compatible_module_defs(weapon: Weapon, module_defs: Array[Dictionary]) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for module_def in module_defs:
		var scene := module_def.get("scene") as PackedScene
		if scene == null:
			continue
		var module_instance := scene.instantiate() as Module
		if module_instance == null:
			continue
		if module_instance.can_apply_to_weapon(weapon):
			output.append(module_def)
		module_instance.free()
	return output

func _build_pair_combos(module_defs: Array[Dictionary]) -> Array[Array]:
	var output: Array[Array] = []
	for i in range(module_defs.size()):
		for j in range(i + 1, module_defs.size()):
			output.append([module_defs[i], module_defs[j]])
	output.sort_custom(func(a: Array, b: Array) -> bool:
		return _combo_to_name(a) < _combo_to_name(b)
	)
	return output

func _combo_to_name(combo: Array) -> String:
	if combo.is_empty():
		return "base"
	var names: PackedStringArray = []
	for module_def in combo:
		names.append(str(module_def.get("name", "")))
	names.sort()
	return "+".join(names)

func _spawn_weapon_instance(weapon_def: WeaponDefinition, branch_id: String, parent: Node = null) -> Weapon:
	if weapon_def == null or weapon_def.scene == null:
		return null
	var weapon := weapon_def.scene.instantiate() as Weapon
	if weapon == null:
		return null
	if parent == null:
		add_child(weapon)
	else:
		parent.add_child(weapon)
	await get_tree().process_frame
	if weapon.has_method("set_level"):
		weapon.call("set_level", 1)
	if branch_id != "":
		weapon.fuse = maxi(weapon.fuse, 3)
		weapon.set_branch(branch_id)
		await get_tree().process_frame
		if weapon.has_method("set_level"):
			weapon.call("set_level", 1)
	weapon.calculate_status()
	return weapon

func _is_budget_exceeded() -> bool:
	var elapsed_sec := float(Time.get_ticks_msec() - _start_msec) / 1000.0
	return elapsed_sec >= MAX_BUDGET_SEC

func _write_csv_report() -> void:
	var file := FileAccess.open(REPORT_CSV_PATH, FileAccess.WRITE)
	if file == null:
		_log("failed to write csv report: %s" % REPORT_CSV_PATH)
		return
	file.store_line("weapon,branch,module_combo,target_profile,window_sec,repeats,seed,avg_dps,total_damage_avg,run_ms,compatible_pair_total,compatible_pair_tested,pair_coverage_ratio")
	for row in _rows:
		file.store_line(_csv_line([
			row.get("weapon", ""),
			row.get("branch", ""),
			row.get("module_combo", ""),
			row.get("target_profile", ""),
			"%.1f" % float(row.get("window_sec", WINDOW_SEC)),
			str(int(row.get("repeats", REPEATS))),
			str(int(row.get("seed", BASE_SEED))),
			"%.3f" % float(row.get("avg_dps", 0.0)),
			"%.2f" % float(row.get("total_damage_avg", 0.0)),
			str(int(row.get("run_ms", 0))),
			str(int(row.get("compatible_pair_total", 0))),
			str(int(row.get("compatible_pair_tested", 0))),
			"%.3f" % float(row.get("pair_coverage_ratio", 1.0)),
		]))
	file.close()
	_log("csv report: %s" % REPORT_CSV_PATH)

func _write_markdown_report(silent: bool = false) -> void:
	var grouped_by_branch: Dictionary = {}
	for row in _rows:
		var key := "%s|%s" % [row.get("weapon", ""), row.get("branch", "")]
		if not grouped_by_branch.has(key):
			grouped_by_branch[key] = []
		grouped_by_branch[key].append(row)

	var lines: PackedStringArray = []
	lines.append("# Weapon/Module DPS Benchmark Summary")
	lines.append("")
	lines.append("- Window: %.1fs" % WINDOW_SEC)
	lines.append("- Repeats: %d" % REPEATS)
	lines.append("- Base Seed: %d" % BASE_SEED)
	lines.append("- Pair Cap Per Branch: %d" % MAX_PAIR_CASES_PER_BRANCH)
	lines.append("- Cases Finished: %d" % _rows.size())
	var runtime_msec := _run_end_msec if _run_end_msec > 0 else Time.get_ticks_msec()
	lines.append("- Runtime: %.2fs" % (float(runtime_msec - _start_msec) / 1000.0))
	lines.append("- Timeout: %s" % ("YES" if _timed_out else "NO"))
	lines.append("- Last Scope: %s" % (_last_scope if _last_scope != "" else "N/A"))
	lines.append("")
	lines.append("## Per Weapon/Branch")
	lines.append("")

	var keys := grouped_by_branch.keys()
	keys.sort()
	for key_variant in keys:
		var key := str(key_variant)
		var parts := key.split("|")
		if parts.size() < 2:
			continue
		var rows: Array = grouped_by_branch[key]
		var single_rows: Array = []
		var group_rows: Array = []
		for row_variant in rows:
			var row: Dictionary = row_variant as Dictionary
			if str(row.get("target_profile", "")) == "single":
				single_rows.append(row)
			elif str(row.get("target_profile", "")) == "group5":
				group_rows.append(row)
		single_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("avg_dps", 0.0)) > float(b.get("avg_dps", 0.0))
		)
		group_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("avg_dps", 0.0)) > float(b.get("avg_dps", 0.0))
		)
		var source_rows := single_rows if not single_rows.is_empty() else group_rows
		if source_rows.is_empty():
			continue
		var coverage := float((source_rows[0] as Dictionary).get("pair_coverage_ratio", 1.0))
		var pair_total := int((source_rows[0] as Dictionary).get("compatible_pair_total", 0))
		var pair_tested := int((source_rows[0] as Dictionary).get("compatible_pair_tested", 0))
		lines.append("### %s / %s" % [parts[0], parts[1]])
		lines.append("- Pair coverage: %d/%d (%.1f%%)" % [pair_tested, pair_total, coverage * 100.0])
		if not single_rows.is_empty():
			var top_single: Dictionary = single_rows[0] as Dictionary
			var bottom_single: Dictionary = single_rows[single_rows.size() - 1] as Dictionary
			lines.append("- Single top/bottom: `%s` (%.3f) / `%s` (%.3f)" % [
				top_single.get("module_combo", "base"),
				float(top_single.get("avg_dps", 0.0)),
				bottom_single.get("module_combo", "base"),
				float(bottom_single.get("avg_dps", 0.0)),
			])
		if not group_rows.is_empty():
			var top_group: Dictionary = group_rows[0] as Dictionary
			var bottom_group: Dictionary = group_rows[group_rows.size() - 1] as Dictionary
			lines.append("- Group(5) top/bottom: `%s` (%.3f) / `%s` (%.3f)" % [
				top_group.get("module_combo", "base"),
				float(top_group.get("avg_dps", 0.0)),
				bottom_group.get("module_combo", "base"),
				float(bottom_group.get("avg_dps", 0.0)),
			])
		var single_map: Dictionary = {}
		for row_variant in single_rows:
			var single_row: Dictionary = row_variant as Dictionary
			single_map[str(single_row.get("module_combo", "base"))] = float(single_row.get("avg_dps", 0.0))
		var diff_rows: Array[Dictionary] = []
		for row_variant in group_rows:
			var group_row: Dictionary = row_variant as Dictionary
			var combo_name := str(group_row.get("module_combo", "base"))
			if not single_map.has(combo_name):
				continue
			var single_dps := float(single_map[combo_name])
			var group_dps := float(group_row.get("avg_dps", 0.0))
			diff_rows.append({
				"combo": combo_name,
				"delta": group_dps - single_dps,
			})
		diff_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return absf(float(a.get("delta", 0.0))) > absf(float(b.get("delta", 0.0)))
		)
		if not diff_rows.is_empty():
			lines.append("- Largest single/group deltas:")
			for i in range(mini(3, diff_rows.size())):
				var diff_row: Dictionary = diff_rows[i] as Dictionary
				lines.append("  - `%s`: %+0.3f DPS" % [
					diff_row.get("combo", "base"),
					float(diff_row.get("delta", 0.0)),
				])
		lines.append("")

	if _timed_out:
		lines.append("## Timeout Note")
		lines.append("")
		lines.append("- Benchmark stopped early due to time budget.")
		lines.append("- CSV contains partial data completed before timeout.")
		lines.append("")

	var file := FileAccess.open(REPORT_MD_PATH, FileAccess.WRITE)
	if file == null:
		_log("failed to write markdown summary: %s" % REPORT_MD_PATH)
		return
	file.store_string("\n".join(lines))
	file.close()
	if not silent:
		_log("markdown summary: %s" % REPORT_MD_PATH)

func _init_csv_report() -> void:
	var file := FileAccess.open(REPORT_CSV_PATH, FileAccess.WRITE)
	if file == null:
		_log("failed to init csv report: %s" % REPORT_CSV_PATH)
		_csv_initialized = false
		return
	file.store_line("weapon,branch,module_combo,target_profile,window_sec,repeats,seed,avg_dps,total_damage_avg,run_ms,compatible_pair_total,compatible_pair_tested,pair_coverage_ratio")
	file.close()
	_csv_initialized = true

func _append_csv_row(row: Dictionary) -> void:
	if not _csv_initialized:
		return
	var file := FileAccess.open(REPORT_CSV_PATH, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(_csv_line([
		row.get("weapon", ""),
		row.get("branch", ""),
		row.get("module_combo", ""),
		row.get("target_profile", ""),
		"%.1f" % float(row.get("window_sec", WINDOW_SEC)),
		str(int(row.get("repeats", REPEATS))),
		str(int(row.get("seed", BASE_SEED))),
		"%.3f" % float(row.get("avg_dps", 0.0)),
		"%.2f" % float(row.get("total_damage_avg", 0.0)),
		str(int(row.get("run_ms", 0))),
		str(int(row.get("compatible_pair_total", 0))),
		str(int(row.get("compatible_pair_tested", 0))),
		"%.3f" % float(row.get("pair_coverage_ratio", 1.0)),
	]))
	file.close()

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

func _log(message: String) -> void:
	print(message)
	_logs.append(message)
