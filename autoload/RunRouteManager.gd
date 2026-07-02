extends Node

const RESOURCE_CATALOG := preload("res://autoload/ResourceCatalog.gd")
const ROUTE_DIRECTORY_PATH := "res://data/routes/"
const DEFAULT_ROUTE_ID := "normal"

var _routes_by_id: Dictionary = {}
var _route_history_by_level: Dictionary = {}
var _route_prepare_result: Dictionary = {"ok": false, "errors": PackedStringArray(), "count": 0}

func _ready() -> void:
	pass

func reset_runtime_state() -> void:
	_route_history_by_level.clear()

func reload_route_definitions() -> void:
	prepare_route_definitions(true)

func prepare_route_definitions(force: bool = false) -> Dictionary:
	if not force and bool(_route_prepare_result.get("ok", false)):
		return _route_prepare_result.duplicate(true)
	var catalog_result: Dictionary = RESOURCE_CATALOG.collect_startup_catalog_paths(
		"routes",
		ROUTE_DIRECTORY_PATH,
		".tres"
	)
	var errors := PackedStringArray()
	if not bool(catalog_result.get("ok", false)):
		errors.append_array(catalog_result.get("errors", PackedStringArray()))
	var loaded_routes := {}
	for path in catalog_result.get("paths", PackedStringArray()):
		_register_route_resource(load(str(path)), str(path), loaded_routes, errors)
	if loaded_routes.is_empty():
		errors.append("no route definitions were prepared")
	if not errors.is_empty():
		_route_prepare_result = _build_prepare_result(false, errors, 0)
		push_error("RunRouteManager: failed to prepare routes: %s" % "; ".join(errors))
		return _route_prepare_result.duplicate(true)
	_routes_by_id = loaded_routes
	_route_prepare_result = _build_prepare_result(true, errors, _routes_by_id.size())
	return _route_prepare_result.duplicate(true)

func get_route_prepare_result() -> Dictionary:
	return _route_prepare_result.duplicate(true)

func get_default_route_id() -> String:
	return DEFAULT_ROUTE_ID

func get_available_routes_for_level(_level_index: int) -> Array[RunRouteDefinition]:
	var routes: Array[RunRouteDefinition] = []
	for route_def_variant in _routes_by_id.values():
		var route_def := route_def_variant as RunRouteDefinition
		if route_def and route_def.battle_enabled:
			routes.append(route_def)
	routes.sort_custom(func(a: RunRouteDefinition, b: RunRouteDefinition) -> bool:
		if a.display_order == b.display_order:
			return a.route_id < b.route_id
		return a.display_order < b.display_order
	)
	if routes.is_empty():
		var fallback := RunRouteDefinition.new()
		fallback.route_id = DEFAULT_ROUTE_ID
		fallback.sanitize()
		routes.append(fallback)
	return routes

func set_route_for_level(level_index: int, route_id: String) -> RunRouteDefinition:
	var safe_level: int = max(level_index, 0)
	var route_def := _resolve_route_definition(route_id)
	_route_history_by_level[safe_level] = route_def.route_id
	return route_def

func select_route_for_current_level(route_id: String) -> RunRouteDefinition:
	return set_route_for_level(int(PhaseManager.current_level), route_id)

func get_route_for_level(level_index: int) -> RunRouteDefinition:
	var safe_level: int = max(level_index, 0)
	var stored_route_id: String = str(_route_history_by_level.get(safe_level, DEFAULT_ROUTE_ID))
	return _resolve_route_definition(stored_route_id)

func get_selected_route_id_for_level(level_index: int) -> String:
	return get_route_for_level(level_index).route_id

func should_start_battle_for_level(level_index: int) -> bool:
	return get_route_for_level(level_index).battle_enabled

func should_spawn_prepare_loot_for_level(level_index: int) -> bool:
	return get_route_for_level(level_index).grants_prepare_loot

func get_route_history_snapshot() -> Dictionary:
	return _route_history_by_level.duplicate(true)

func restore_route_history(snapshot: Dictionary) -> void:
	_route_history_by_level.clear()
	for level_variant in snapshot.keys():
		var level_index := int(level_variant)
		var route_id := str(snapshot[level_variant])
		_route_history_by_level[level_index] = _resolve_route_definition(route_id).route_id

func _resolve_route_definition(route_id: String) -> RunRouteDefinition:
	var normalized_route_id := route_id.strip_edges().to_lower()
	if _routes_by_id.has(normalized_route_id):
		var resolved := _routes_by_id[normalized_route_id] as RunRouteDefinition
		if resolved:
			return resolved
	if _routes_by_id.has(DEFAULT_ROUTE_ID):
		var default_route := _routes_by_id[DEFAULT_ROUTE_ID] as RunRouteDefinition
		if default_route:
			return default_route
	for route_def_variant in _routes_by_id.values():
		var route_def := route_def_variant as RunRouteDefinition
		if route_def:
			return route_def
	var fallback := RunRouteDefinition.new()
	fallback.route_id = DEFAULT_ROUTE_ID
	fallback.display_name = "Normal Route"
	fallback.description = "Fallback route definition"
	fallback.sanitize()
	return fallback

func _register_route_resource(resource: Resource, source_path: String, output: Dictionary, errors: PackedStringArray) -> void:
	var route_def := resource as RunRouteDefinition
	if route_def == null:
		errors.append("invalid route resource: %s" % source_path)
		return
	var raw_route_id := route_def.route_id.strip_edges().to_lower()
	if raw_route_id == "":
		errors.append("route resource missing route_id: %s" % source_path)
		return
	route_def.sanitize()
	if output.has(route_def.route_id):
		errors.append("duplicate route_id '%s': %s" % [route_def.route_id, source_path])
		return
	output[route_def.route_id] = route_def

func _build_prepare_result(ok: bool, errors: PackedStringArray, count: int) -> Dictionary:
	return {
		"ok": ok,
		"errors": errors,
		"count": count,
	}
