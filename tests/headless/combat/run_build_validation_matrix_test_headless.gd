extends SceneTree

const MatrixScript := preload("res://data/test/build_validation_matrix.gd")
const MATRIX_PATH := "res://data/test/build_validation_matrix_default.tres"
const REQUIRED_ENCOUNTERS := [
	"swarm_60s",
	"elite_high_hp",
	"support_shield_core",
	"ranged_siege",
	"close_pressure",
	"task_objective_combat",
]
const MIN_BUILD_CASES := 6

var _data_handler: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := PackedStringArray()
	var matrix := load(MATRIX_PATH)
	if matrix == null or not (matrix is MatrixScript):
		_fail(PackedStringArray(["cannot load BuildValidationMatrix at %s" % MATRIX_PATH]))
		return
	_data_handler = root.get_node_or_null("/root/DataHandler")
	if _data_handler == null:
		_fail(PackedStringArray(["missing DataHandler autoload"]))
		return
	_data_handler.call("load_weapon_data")
	_data_handler.call("load_weapon_branch_data")
	failures.append_array(_validate_encounters(matrix))
	failures.append_array(_validate_build_cases(matrix))
	failures.append_array(_validate_matrix_balance_contract(matrix))
	if failures.is_empty():
		print("PASS: build validation matrix contract (%d builds, %d encounters)" % [
			matrix.build_cases.size(),
			matrix.encounter_types.size(),
		])
		quit(0)
		return
	_fail(failures)

func _validate_encounters(matrix: Resource) -> PackedStringArray:
	var failures := PackedStringArray()
	var seen := {}
	for encounter in matrix.encounter_types:
		var encounter_id := str(encounter.get("id", "")).strip_edges()
		if encounter_id == "":
			failures.append("encounter has empty id")
			continue
		if seen.has(encounter_id):
			failures.append("duplicate encounter id: %s" % encounter_id)
		seen[encounter_id] = true
		var tags: PackedStringArray = _to_string_array(encounter.get("pressure_tags", PackedStringArray()))
		if tags.is_empty():
			failures.append("%s: missing pressure_tags" % encounter_id)
		if str(encounter.get("primary_question", "")).strip_edges() == "":
			failures.append("%s: missing primary_question" % encounter_id)
	for required_id in REQUIRED_ENCOUNTERS:
		if not seen.has(required_id):
			failures.append("missing required encounter: %s" % required_id)
	return failures

func _validate_build_cases(matrix: Resource) -> PackedStringArray:
	var failures := PackedStringArray()
	var encounter_ids := _dictionary_from_ids(matrix.call("get_encounter_ids"))
	var seen_builds := {}
	if matrix.build_cases.size() < MIN_BUILD_CASES:
		failures.append("expected at least %d build cases, got %d" % [MIN_BUILD_CASES, matrix.build_cases.size()])
	for build_case in matrix.build_cases:
		var build_id := str(build_case.get("id", "")).strip_edges()
		if build_id == "":
			failures.append("build case has empty id")
			continue
		if seen_builds.has(build_id):
			failures.append("duplicate build id: %s" % build_id)
		seen_builds[build_id] = true
		var weapons := _to_string_array(build_case.get("weapons", PackedStringArray()))
		if weapons.size() < 2:
			failures.append("%s: expected at least 2 weapons" % build_id)
		failures.append_array(_validate_weapons(build_id, weapons))
		failures.append_array(_validate_branches(build_id, weapons, build_case.get("branches", {})))
		failures.append_array(_validate_modules(build_id, _to_string_array(build_case.get("modules", PackedStringArray()))))
		failures.append_array(_validate_encounter_refs(build_id, "target_encounters", _to_string_array(build_case.get("target_encounters", PackedStringArray())), encounter_ids, true))
		failures.append_array(_validate_encounter_refs(build_id, "expected_strengths", _to_string_array(build_case.get("expected_strengths", PackedStringArray())), encounter_ids, true))
		failures.append_array(_validate_encounter_refs(build_id, "expected_weaknesses", _to_string_array(build_case.get("expected_weaknesses", PackedStringArray())), encounter_ids, true))
		var strengths := _to_string_array(build_case.get("expected_strengths", PackedStringArray()))
		var weaknesses := _to_string_array(build_case.get("expected_weaknesses", PackedStringArray()))
		if strengths.size() >= REQUIRED_ENCOUNTERS.size():
			failures.append("%s: expected_strengths covers every encounter; matrix must not define an omnibuild" % build_id)
		if _has_overlap(strengths, weaknesses):
			failures.append("%s: expected_strengths and expected_weaknesses overlap" % build_id)
		if str(build_case.get("notes", "")).strip_edges() == "":
			failures.append("%s: missing notes" % build_id)
	return failures

func _validate_weapons(build_id: String, weapons: PackedStringArray) -> PackedStringArray:
	var failures := PackedStringArray()
	for weapon_id in weapons:
		var weapon_def := _data_handler.call("read_weapon_data", weapon_id) as WeaponDefinition
		if weapon_def == null:
			failures.append("%s: unknown weapon id %s" % [build_id, weapon_id])
			continue
		if weapon_def.scene_path == "":
			failures.append("%s: weapon %s has empty scene_path" % [build_id, weapon_id])
	return failures

func _validate_branches(build_id: String, weapons: PackedStringArray, branches_variant: Variant) -> PackedStringArray:
	var failures := PackedStringArray()
	if not (branches_variant is Dictionary):
		failures.append("%s: branches must be a Dictionary" % build_id)
		return failures
	var branches: Dictionary = branches_variant
	var weapon_lookup := _dictionary_from_ids(weapons)
	for key_variant in branches.keys():
		var weapon_id := str(key_variant)
		var branch_id := str(branches.get(key_variant, "")).strip_edges()
		if not weapon_lookup.has(weapon_id):
			failures.append("%s: branch weapon %s is not listed in weapons" % [build_id, weapon_id])
			continue
		if branch_id == "":
			failures.append("%s: empty branch id for weapon %s" % [build_id, weapon_id])
			continue
		var weapon_def := _data_handler.call("read_weapon_data", weapon_id) as WeaponDefinition
		if weapon_def == null:
			continue
		var branch_def: Variant = _data_handler.call("read_weapon_branch_definition", str(weapon_def.scene_path), branch_id)
		if branch_def == null:
			failures.append("%s: branch %s not found for weapon %s (%s)" % [
				build_id,
				branch_id,
				weapon_id,
				str(weapon_def.scene_path),
			])
	return failures

func _validate_modules(build_id: String, modules: PackedStringArray) -> PackedStringArray:
	var failures := PackedStringArray()
	if modules.is_empty():
		failures.append("%s: expected at least one module path" % build_id)
	for module_path in modules:
		if not module_path.begins_with("res://Player/Weapons/Modules/"):
			failures.append("%s: module path outside module directory: %s" % [build_id, module_path])
			continue
		if not ResourceLoader.exists(module_path):
			failures.append("%s: missing module resource: %s" % [build_id, module_path])
	return failures

func _validate_encounter_refs(
	build_id: String,
	field: String,
	refs: PackedStringArray,
	encounter_ids: Dictionary,
	require_non_empty: bool
) -> PackedStringArray:
	var failures := PackedStringArray()
	if require_non_empty and refs.is_empty():
		failures.append("%s: %s is empty" % [build_id, field])
	for encounter_id in refs:
		if not encounter_ids.has(encounter_id):
			failures.append("%s: %s references unknown encounter %s" % [build_id, field, encounter_id])
	return failures

func _validate_matrix_balance_contract(matrix: Resource) -> PackedStringArray:
	var failures := PackedStringArray()
	var strength_coverage := {}
	var weakness_coverage := {}
	for encounter_id in REQUIRED_ENCOUNTERS:
		strength_coverage[encounter_id] = 0
		weakness_coverage[encounter_id] = 0
	for build_case in matrix.build_cases:
		for encounter_id in _to_string_array(build_case.get("expected_strengths", PackedStringArray())):
			if strength_coverage.has(encounter_id):
				strength_coverage[encounter_id] = int(strength_coverage[encounter_id]) + 1
		for encounter_id in _to_string_array(build_case.get("expected_weaknesses", PackedStringArray())):
			if weakness_coverage.has(encounter_id):
				weakness_coverage[encounter_id] = int(weakness_coverage[encounter_id]) + 1
	for encounter_id in REQUIRED_ENCOUNTERS:
		if int(strength_coverage.get(encounter_id, 0)) <= 0:
			failures.append("%s: no build lists this encounter as a strength" % encounter_id)
		if int(weakness_coverage.get(encounter_id, 0)) <= 0:
			failures.append("%s: no build lists this encounter as a weakness" % encounter_id)
	return failures

func _dictionary_from_ids(ids: PackedStringArray) -> Dictionary:
	var output := {}
	for id_value in ids:
		output[str(id_value)] = true
	return output

func _to_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var output := PackedStringArray()
	if value is Array:
		for item in value:
			output.append(str(item))
	return output

func _has_overlap(left: PackedStringArray, right: PackedStringArray) -> bool:
	var right_lookup := _dictionary_from_ids(right)
	for item in left:
		if right_lookup.has(item):
			return true
	return false

func _fail(failures: PackedStringArray) -> void:
	for failure in failures:
		push_error("FAIL: build validation matrix: %s" % failure)
	quit(1)
