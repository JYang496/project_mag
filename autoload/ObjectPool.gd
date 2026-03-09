extends Node
class_name ObjectPoolService

@export var max_cached_per_scene: int = 128
var _available: Dictionary = {}
var _in_use: Dictionary = {}

func acquire(scene: PackedScene) -> Node:
	if scene == null:
		return null
	var key := _scene_key(scene)
	var cached: Array = _available.get(key, [])
	var node: Node = null
	if not cached.is_empty():
		node = cached.pop_back() as Node
		_available[key] = cached
	else:
		node = scene.instantiate()
	if node == null:
		return null
	_in_use[node.get_instance_id()] = key
	node.set_meta("_pool_scene_key", key)
	if node.has_method("_on_acquired_from_pool"):
		node.call("_on_acquired_from_pool")
	node.request_ready()
	return node

func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var instance_id := node.get_instance_id()
	var key: String = _in_use.get(instance_id, "")
	if key == "":
		key = str(node.get_meta("_pool_scene_key", ""))
		if key == "":
			node.queue_free()
			return
	if node.has_method("_on_before_pooled"):
		node.call("_on_before_pooled")
	if node.get_parent():
		node.get_parent().remove_child(node)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	var cached: Array = _available.get(key, [])
	cached.append(node)
	if cached.size() > max_cached_per_scene:
		var old_node: Node = cached.pop_front()
		if old_node and is_instance_valid(old_node):
			old_node.queue_free()
	_available[key] = cached
	_in_use.erase(instance_id)

func _scene_key(scene: PackedScene) -> String:
	var path := scene.resource_path
	if path != "":
		return path
	return "runtime_scene_%s" % str(scene.get_instance_id())
