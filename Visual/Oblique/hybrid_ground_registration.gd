class_name HybridGroundRegistration
extends RefCounted

static var _pending: Dictionary = {}

static func register(source: Node, method: StringName) -> bool:
	var view := find_view(source)
	if view == null:
		queue_registration(source, method)
		return false
	if not view.has_method(method):
		return false
	view.call(method, source)
	_pending.erase(source.get_instance_id())
	return true

static func queue_registration(source: Node, method: StringName) -> void:
	if source == null:
		return
	_pending[source.get_instance_id()] = {"source": weakref(source), "method": method}

static func unregister(source: Node) -> void:
	if source == null:
		return
	_pending.erase(source.get_instance_id())
	var view := find_view(source)
	if view != null and view.has_method("unregister_ground_visual"):
		view.call("unregister_ground_visual", source)

static func flush_pending(view: Node) -> void:
	if view == null:
		return
	for source_id in _pending.keys():
		var entry := _pending.get(source_id) as Dictionary
		var source_ref := entry.get("source") as WeakRef
		var source := source_ref.get_ref() as Node if source_ref != null else null
		var method := entry.get("method", &"") as StringName
		if source == null or not is_instance_valid(source) or not source.is_inside_tree():
			_pending.erase(source_id)
			continue
		if view.has_method(method):
			view.call(method, source)
			_pending.erase(source_id)

static func pending_count() -> int:
	return _pending.size()

static func find_view(source: Node) -> Node:
	if source == null or not source.is_inside_tree():
		return null
	var views := source.get_tree().get_nodes_in_group(&"hybrid_ground_view_3d")
	return views[0] as Node if not views.is_empty() else null
