class_name AuraRenderer
extends RefCounted

var _view: Node
var aura_meshes: Dictionary = {}
var link_sources: Dictionary = {}
var link_meshes: Dictionary = {}

func setup(view: Node) -> void:
	_view = view
	_view._enemy_aura_meshes = aura_meshes
	_view._enemy_link_sources = link_sources
	_view._enemy_link_meshes = link_meshes

func register_source(source: Node2D) -> void:
	if _is_ready():
		_view._register_enemy_support_visual(source)

func sync_late(_delta: float) -> void:
	if not _is_ready():
		return
	_view._sync_enemy_aura_meshes()
	_view._sync_enemy_link_meshes()

func clear() -> void:
	aura_meshes.clear()
	link_sources.clear()
	link_meshes.clear()

func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view)
