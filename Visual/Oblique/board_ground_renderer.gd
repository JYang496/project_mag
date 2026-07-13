class_name BoardGroundRenderer
extends RefCounted

var _view: Node
var activation_meshes: Dictionary = {}
var cell_meshes: Dictionary = {}
var rest_zone_meshes: Dictionary = {}

func setup(view: Node) -> void:
	_view = view
	_view._activation_meshes = activation_meshes
	_view._cell_meshes = cell_meshes
	_view._rest_zone_meshes = rest_zone_meshes

func rebuild() -> void:
	if _is_ready():
		_view._rebuild_ground()

func setup_rest_area() -> void:
	if _is_ready():
		_view._setup_rest_area_ground()

func hide_legacy_boundaries() -> void:
	if _is_ready():
		_view._hide_legacy_board_boundary_visuals()

func sync_late(_delta: float) -> void:
	if not _is_ready():
		return
	_view._sync_cell_meshes()
	_view._sync_activation_visuals()
	_view._sync_rest_ground_mesh()
	_view._sync_rest_zone_meshes()

func clear() -> void:
	activation_meshes.clear()
	cell_meshes.clear()
	rest_zone_meshes.clear()

func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view)
