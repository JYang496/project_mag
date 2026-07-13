class_name HybridGroundLateSync
extends Node

var _view: Node

func setup(view: Node) -> void:
	_view = view
	process_priority = 100

func _process(delta: float) -> void:
	if _view == null or not is_instance_valid(_view):
		return
	_view.sync_late_visuals(delta)

func _exit_tree() -> void:
	_view = null
