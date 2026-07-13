class_name AreaEffectRenderer
extends RefCounted

var _view: Node
var shadow_meshes: Dictionary = {}
var area_meshes: Dictionary = {}
var dash_telegraph_meshes: Dictionary = {}

func setup(view: Node) -> void:
	_view = view
	_view._shadow_meshes = shadow_meshes
	_view._area_meshes = area_meshes
	_view._dash_telegraph_meshes = dash_telegraph_meshes

func register_shadow(shadow: CanvasItem) -> void:
	if _is_ready():
		_view._register_shadow(shadow)

func register_area_effect(area: Node2D) -> void:
	if _is_ready():
		_view._register_area_effect(area)

func register_warning_circle(warning: Node2D) -> void:
	if _is_ready():
		_view._register_warning_circle(warning)

func register_dash_telegraph(source: Node2D) -> void:
	if _is_ready():
		_view._register_dash_telegraph(source)

func sync_late(_delta: float) -> void:
	if not _is_ready():
		return
	_view._sync_shadow_meshes()
	_view._sync_area_meshes()
	_view._sync_dash_telegraph_meshes()

func clear() -> void:
	shadow_meshes.clear()
	area_meshes.clear()
	dash_telegraph_meshes.clear()

func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view)
