extends Node

const MODULE_DIRECTORY_PATH := "res://Player/Weapons/Modules/"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var module_path := _find_first_module_scene_path()
	if module_path == "":
		_fail(1, "TemporaryModuleLifecycleTest: no module scene found.")
		return

	var first := _instantiate_module(module_path)
	var second := _instantiate_module(module_path)
	var third := _instantiate_module(module_path)
	var overflow := _instantiate_module(module_path)
	if first == null or second == null or third == null or overflow == null:
		_fail(2, "TemporaryModuleLifecycleTest: failed to instantiate module fixtures.")
		return

	var first_result := InventoryData.obtain_module(first)
	if str(first_result.get("result", "")) != "stored" \
			or InventoryData.temporary_modules.size() != 1:
		_fail(3, "TemporaryModuleLifecycleTest: first module was not stored.")
		return

	var second_result := InventoryData.obtain_module(second)
	if str(second_result.get("result", "")) != "upgraded" or first.module_level != 2:
		_fail(4, "TemporaryModuleLifecycleTest: duplicate did not upgrade to level 2.")
		return

	var third_result := InventoryData.obtain_module(third)
	if str(third_result.get("result", "")) != "upgraded" or first.module_level != 3:
		_fail(5, "TemporaryModuleLifecycleTest: duplicate did not upgrade to level 3.")
		return

	var starting_gold := int(PlayerData.player_gold)
	var overflow_result := InventoryData.obtain_module(overflow)
	if str(overflow_result.get("result", "")) != "converted_to_gold" \
			or int(PlayerData.player_gold) <= starting_gold:
		_fail(6, "TemporaryModuleLifecycleTest: level-3 overflow was not sold.")
		return
	if InventoryData.temporary_modules.size() != 1:
		_fail(7, "TemporaryModuleLifecycleTest: duplicate instances remained in temporary storage.")
		return

	InventoryData.begin_pending_transaction({
		"id": "module:test",
		"type": "module_assignment",
		"scene_path": module_path,
	})
	InventoryData.save_runtime_state()
	first.queue_free()
	InventoryData.temporary_modules.clear()
	InventoryData.pending_transactions.clear()
	await get_tree().process_frame
	InventoryData.load_runtime_state()
	if InventoryData.temporary_modules.size() != 1 \
			or InventoryData.temporary_modules[0].module_level != 3:
		_fail(8, "TemporaryModuleLifecycleTest: temporary module state did not restore.")
		return
	if InventoryData.pending_transactions.size() != 1 \
			or str(InventoryData.pending_transactions[0].get("id", "")) != "module:test":
		_fail(9, "TemporaryModuleLifecycleTest: pending transaction did not restore.")
		return

	InventoryData.reset_runtime_state()
	print("TemporaryModuleLifecycleTest: PASS")
	get_tree().quit(0)

func _instantiate_module(path: String) -> Module:
	var scene := load(path) as PackedScene
	return scene.instantiate() as Module if scene else null

func _find_first_module_scene_path() -> String:
	var directory := DirAccess.open(MODULE_DIRECTORY_PATH)
	if directory == null:
		return ""
	var paths: PackedStringArray = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() \
				and file_name.ends_with(".tscn") \
				and file_name != "wmod_base.tscn":
			paths.append(MODULE_DIRECTORY_PATH + file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths[0] if not paths.is_empty() else ""

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
