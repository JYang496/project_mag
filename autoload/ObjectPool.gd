extends Node
class_name ObjectPoolService

@export var max_cached_per_scene: int = 128
var _in_use: Dictionary = {}
var _available_by_scene: Dictionary = {}

func acquire(scene: PackedScene) -> Node:
	if scene == null:
		return null
	var key := _scene_key(scene)
	var node: Node
	var available: Array = _available_by_scene.get(key, [])
	while not available.is_empty() and node == null:
		# A cached object may have been freed by legacy gameplay code. Validate the
		# untyped Variant before casting it, because casting a freed Object errors.
		var candidate: Variant = available.pop_back()
		if not is_instance_valid(candidate):
			continue
		if not candidate is Node:
			continue
		node = candidate as Node
	_available_by_scene[key] = available
	if node == null:
		node = scene.instantiate()
	if node == null:
		return null
	_in_use[node.get_instance_id()] = key
	node.set_meta("_pool_scene_key", key)
	node.set_meta("_pool_is_available", false)
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node.has_method("_on_acquired_from_pool"):
		node.call("_on_acquired_from_pool")
	node.request_ready()
	return node

func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	# Multiple hits/timeouts can schedule despawn() in the same frame. A second
	# release must not append the same object to the available list again.
	if bool(node.get_meta("_pool_is_available", false)):
		return
	if node.has_method("_on_before_pooled"):
		node.call("_on_before_pooled")
	var instance_id := node.get_instance_id()
	var key := str(_in_use.get(instance_id, node.get_meta("_pool_scene_key", "")))
	_in_use.erase(instance_id)
	if key == "":
		node.queue_free()
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	var available: Array = _available_by_scene.get(key, [])
	if available.size() >= maxi(max_cached_per_scene, 0):
		node.queue_free()
		return
	node.set_meta("_pool_is_available", true)
	available.append(node)
	_available_by_scene[key] = available

func _scene_key(scene: PackedScene) -> String:
	var path := scene.resource_path
	if path != "":
		return path
	return "runtime_scene_%s" % str(scene.get_instance_id())

func clear() -> void:
	for available_value in _available_by_scene.values():
		for node_value in available_value as Array:
			if not is_instance_valid(node_value) or not node_value is Node:
				continue
			var node := node_value as Node
			if node != null:
				node.free()
	_available_by_scene.clear()

func _exit_tree() -> void:
	clear()
