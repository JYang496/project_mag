extends Node

var _failures := PackedStringArray()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_reset_datahandler_globals()
	_assert_catalog_paths("weapons", "res://data/weapons/", 15)
	_assert_catalog_paths("mechas", "res://data/mechas/", 5)
	_assert_catalog_paths("economy", "res://data/economy/", 1)
	_assert_catalog_paths("routes", "res://data/routes/", 3)
	_assert_catalog_paths("cell_effects", "res://data/cell_effects/", 21)
	_assert_catalog_paths("task_modules", "res://data/task_modules/", 5)
	_assert_catalog_paths("weapon_branches", "res://data/weapon_branches/", 28)
	_assert_catalog_paths("weapon_passives", "res://data/weapon_passives/", 15)

	_assert_prepare_result(
		"routes",
		RunRouteManager.prepare_route_definitions(true),
		3
	)
	_assert_prepare_result(
		"routes idempotent",
		RunRouteManager.prepare_route_definitions(),
		3
	)
	if RunRouteManager.get_route_for_level(0).route_id != RunRouteManager.get_default_route_id():
		_record("default route was not preserved after manifest preparation")
	var difficult_route := RunRouteManager.set_route_for_level(0, "difficult")
	if difficult_route == null or difficult_route.route_id != "difficult":
		_record("difficult route was not available after manifest preparation")

	_assert_prepare_result(
		"cell effects",
		CellEffectRuntime.prepare_definitions(true),
		21
	)
	_assert_prepare_result(
		"cell effects idempotent",
		CellEffectRuntime.prepare_definitions(),
		21
	)
	if CellEffectRuntime.get_definition("speed_1") == null:
		_record("speed_1 cell effect was not available after manifest preparation")
	if CellEffectRuntime.get_all_definitions().size() != 21:
		_record("cell effect definition count mismatch after preparation")

	_assert_prepare_result(
		"task modules",
		CellTaskModuleRuntime.prepare_definitions(true),
		5
	)
	_assert_prepare_result(
		"task modules idempotent",
		CellTaskModuleRuntime.prepare_definitions(),
		5
	)
	if CellTaskModuleRuntime.get_definition("task_kill_common") == null:
		_record("task_kill_common module was not available after manifest preparation")
	if CellTaskModuleRuntime.get_all_definitions().size() != 5:
		_record("task module definition count mismatch after preparation")

	_assert_prepare_result("weapons", DataHandler.prepare_weapon_data(true), 15)
	_assert_prepare_result("weapons idempotent", DataHandler.prepare_weapon_data(), 15)
	if DataHandler.read_weapon_data("1") == null:
		_record("machine gun weapon data was not available after manifest preparation")
	if DataHandler.get_weapon_id_from_scene_path("res://Player/Weapons/Instances/machine_gun.tscn") != "1":
		_record("weapon scene path index was not available after manifest preparation")

	_assert_prepare_result("mechas", DataHandler.prepare_mecha_data(true), 5)
	_assert_prepare_result("mechas idempotent", DataHandler.prepare_mecha_data(), 5)
	if DataHandler.read_mecha_data("2") == null:
		_record("Ranger mecha data was not available after manifest preparation")

	_assert_prepare_result("economy", DataHandler.prepare_economy_data(true), 1)
	_assert_prepare_result("economy idempotent", DataHandler.prepare_economy_data(), 1)
	if GlobalVariables.economy_data == null:
		_record("economy config was not available after manifest preparation")

	_assert_prepare_result("weapon branches", DataHandler.prepare_weapon_branch_data(true), 28)
	_assert_prepare_result("weapon branches idempotent", DataHandler.prepare_weapon_branch_data(), 28)
	if DataHandler.read_weapon_branch_definition("res://Player/Weapons/Instances/machine_gun.tscn", "shield_mg") == null:
		_record("machine gun shield branch was not available after manifest preparation")

	_assert_prepare_result("weapon passives", DataHandler.prepare_weapon_passive_branch_data(true), 15)
	_assert_prepare_result("weapon passives idempotent", DataHandler.prepare_weapon_passive_branch_data(), 15)
	if DataHandler.read_weapon_passive_branch_definition("pistol_continuous_move_triggered") == null:
		_record("pistol passive branch was not available after manifest preparation")

	_assert_prepare_result("world aggregate", DataHandler.prepare_world_data(true), 0)

	_finish()

func _assert_catalog_paths(domain: String, directory: String, expected_count: int) -> void:
	var result: Dictionary = ResourceCatalog.collect_startup_catalog_paths(domain, directory, ".tres")
	if not bool(result.get("ok", false)):
		_record("%s catalog path collection failed: %s" % [domain, str(result.get("errors", []))])
		return
	var paths: PackedStringArray = result.get("paths", PackedStringArray())
	if paths.size() != expected_count:
		_record("%s catalog path count mismatch: expected=%d actual=%d" % [domain, expected_count, paths.size()])

func _assert_prepare_result(label: String, result: Dictionary, expected_count: int) -> void:
	if not bool(result.get("ok", false)):
		_record("%s prepare failed: %s" % [label, str(result.get("errors", []))])
		return
	var count := int(result.get("count", 0))
	if count != expected_count:
		_record("%s prepare count mismatch: expected=%d actual=%d" % [label, expected_count, count])

func _record(message: String) -> void:
	_failures.append(message)
	push_error("StartupManifestRuntimeConsumptionTest: " + message)

func _finish() -> void:
	_reset_datahandler_globals()
	RunRouteManager.reset_runtime_state()
	CellTaskModuleRuntime.reset_runtime_state()
	CellEffectRuntime.reset_runtime_state()
	if _failures.is_empty():
		print("StartupManifestRuntimeConsumptionTest: PASS")
		get_tree().quit(0)
		return
	print("StartupManifestRuntimeConsumptionTest: FAIL count=%d" % _failures.size())
	for failure in _failures:
		print(" - " + failure)
	get_tree().quit(1)

func _reset_datahandler_globals() -> void:
	GlobalVariables.weapon_list = {}
	GlobalVariables.mecha_list = {}
	GlobalVariables.weapon_branch_list = {}
	GlobalVariables.weapon_passive_branch_list = {}
	GlobalVariables.economy_data = null
