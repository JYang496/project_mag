extends SceneTree

const RESOURCE_CATALOG := preload("res://autoload/ResourceCatalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var weapon_paths := RESOURCE_CATALOG.collect_resource_paths("res://data/weapons/", ".tres")
	if weapon_paths.is_empty():
		_fail("ResourceCatalogTest: expected weapon resource paths.")
		return
	var sorted_paths := PackedStringArray(weapon_paths)
	sorted_paths.sort()
	if weapon_paths != sorted_paths:
		_fail("ResourceCatalogTest: resource paths are not sorted.")
		return

	var data_handler := root.get_node_or_null("/root/DataHandler")
	var cell_effect_runtime := root.get_node_or_null("/root/CellEffectRuntime")
	var cell_task_runtime := root.get_node_or_null("/root/CellTaskModuleRuntime")
	var route_manager := root.get_node_or_null("/root/RunRouteManager")
	if data_handler == null or cell_effect_runtime == null or cell_task_runtime == null or route_manager == null:
		_fail("ResourceCatalogTest: missing required autoloads.")
		return

	data_handler.call("load_weapon_data")
	var weapon_ids: Array = data_handler.call("get_weapon_ids")
	if weapon_ids.is_empty():
		_fail("ResourceCatalogTest: weapon definitions did not load.")
		return
	var weapon_id := str(weapon_ids[0])
	var weapon_def: Variant = data_handler.call("read_weapon_data", weapon_id)
	if weapon_def == null:
		_fail("ResourceCatalogTest: failed to read loaded weapon definition.")
		return
	var scene_path := str(weapon_def.get("scene_path"))
	if data_handler.call("get_weapon_id_from_scene_path", scene_path) != weapon_id:
		_fail("ResourceCatalogTest: weapon scene_path reverse index failed.")
		return

	cell_effect_runtime.call("load_definitions")
	var effects: Array = cell_effect_runtime.call("get_all_definitions")
	if effects.is_empty():
		_fail("ResourceCatalogTest: cell effect definitions did not load.")
		return

	cell_task_runtime.call("load_definitions")
	var tasks: Array = cell_task_runtime.call("get_all_definitions")
	if tasks.is_empty():
		_fail("ResourceCatalogTest: task module definitions did not load.")
		return

	route_manager.call("reload_route_definitions")
	var routes: Array = route_manager.call("get_available_routes_for_level", 0)
	if routes.is_empty():
		_fail("ResourceCatalogTest: route definitions did not load.")
		return

	print("PASS: ResourceCatalog stable paths, definitions, and weapon reverse index")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
