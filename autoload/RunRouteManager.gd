extends Node

const RESOURCE_CATALOG := preload("res://autoload/ResourceCatalog.gd")
const ROUTE_DIRECTORY_PATH := "res://data/routes/"
const ROUTE_RESOURCE_PATHS := [
	"res://data/routes/normal_route.tres",
	"res://data/routes/bonus_route.tres",
	"res://data/routes/difficult_route.tres",
]
const DEFAULT_ROUTE_ID := "normal"

var _routes_by_id: Dictionary = {}
var _route_history_by_level: Dictionary = {}

func _ready() -> void:
	reload_route_definitions()

func reset_runtime_state() -> void:
	_route_history_by_level.clear()

func reload_route_definitions() -> void:
	_routes_by_id.clear()
	for path in RESOURCE_CATALOG.collect_resource_paths(ROUTE_DIRECTORY_PATH, ".tres", ROUTE_RESOURCE_PATHS):
		_register_route_resource(load(path), path)
	if _routes_by_id.is_empty():
		var fallback := RunRouteDefinition.new()
		fallback.route_id = DEFAULT_ROUTE_ID
		fallback.display_name = "Normal Route"
		fallback.description = "Fallback route definition"
		fallback.sanitize()
		_routes_by_id[fallback.route_id] = fallback

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

func _register_route_resource(resource: Resource, source_path: String) -> void:
	var route_def := resource as RunRouteDefinition
	if route_def == null:
		push_warning("Invalid route resource skipped: %s" % source_path)
		return
	route_def.sanitize()
	if route_def.route_id == "":
		push_warning("Route resource missing route_id: %s" % source_path)
		return
	_routes_by_id[route_def.route_id] = route_def
