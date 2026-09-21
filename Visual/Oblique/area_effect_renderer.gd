class_name AreaEffectRenderer
extends RefCounted

var _view: Node
var shadow_meshes: Dictionary = {}
var affiliation_marker_meshes: Dictionary = {}
var area_meshes: Dictionary = {}
var dash_telegraph_meshes: Dictionary = {}
var _shadow_total_usec := 0
var _marker_total_usec := 0
var _area_total_usec := 0
var _dash_total_usec := 0
var _dense_enemy_sync_accumulator := 1.0 / 30.0

func setup(view: Node) -> void:
	_view = view
	_view._shadow_meshes = shadow_meshes
	_view._affiliation_marker_meshes = affiliation_marker_meshes
	_view._area_meshes = area_meshes
	_view._dash_telegraph_meshes = dash_telegraph_meshes

func register_shadow(shadow: CanvasItem) -> void:
	if _is_ready():
		_view._register_shadow(shadow)

func register_affiliation_marker(marker: Node2D) -> void:
	if _is_ready():
		_view._register_affiliation_marker(marker)

func register_area_effect(area: Node2D) -> void:
	if _is_ready():
		_view._register_area_effect(area)

func register_warning_circle(warning: Node2D) -> void:
	if _is_ready():
		_view._register_warning_circle(warning)

func register_dash_telegraph(source: Node2D) -> void:
	if _is_ready():
		_view._register_dash_telegraph(source)

func sync_late(delta: float) -> void:
	if not _is_ready():
		return
	var dense_crowd := EnemySimulationSystem.get_registered_enemy_count() >= EnemySimulationSystem.DENSE_CROWD_THRESHOLD
	_dense_enemy_sync_accumulator += delta
	var sync_dense_enemies := not dense_crowd or _dense_enemy_sync_accumulator >= 1.0 / 30.0
	if sync_dense_enemies:
		_dense_enemy_sync_accumulator = fmod(_dense_enemy_sync_accumulator, 1.0 / 30.0)
	var started := Time.get_ticks_usec()
	_view._sync_shadow_meshes(sync_dense_enemies)
	_shadow_total_usec += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	_view._sync_affiliation_marker_meshes(sync_dense_enemies, dense_crowd)
	_marker_total_usec += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	_view._sync_area_meshes()
	_area_total_usec += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	_view._sync_dash_telegraph_meshes()
	_dash_total_usec += Time.get_ticks_usec() - started

func reset_timing_metrics() -> void:
	_shadow_total_usec = 0
	_marker_total_usec = 0
	_area_total_usec = 0
	_dash_total_usec = 0

func get_timing_metrics() -> Dictionary:
	return {
		"shadows_ms": float(_shadow_total_usec) / 1000.0,
		"markers_ms": float(_marker_total_usec) / 1000.0,
		"areas_ms": float(_area_total_usec) / 1000.0,
		"dash_ms": float(_dash_total_usec) / 1000.0,
		"shadow_count": shadow_meshes.size(),
		"marker_count": affiliation_marker_meshes.size(),
		"area_count": area_meshes.size(),
		"dash_count": dash_telegraph_meshes.size(),
	}

func clear() -> void:
	shadow_meshes.clear()
	affiliation_marker_meshes.clear()
	area_meshes.clear()
	dash_telegraph_meshes.clear()

func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view)
