extends Node
class_name ObjectPoolService

const POOL_AVAILABLE_META := &"_pool_is_available"
const POOL_RELEASE_PENDING_META := &"_pool_release_pending"

@export var max_cached_per_scene: int = 128
var _in_use: Dictionary = {}
var _available_by_scene: Dictionary = {}
var _metrics := {
	"acquire_requests": 0,
	"pool_hits": 0,
	"pool_misses": 0,
	"releases": 0,
	"discarded_invalid": 0,
	"discarded_capacity": 0,
}

func acquire(scene: PackedScene) -> Node:
	if scene == null:
		return null
	_metrics.acquire_requests += 1
	var key := _scene_key(scene)
	var node: Node = null
	var available: Array = _available_by_scene.get(key, [])
	while not available.is_empty() and node == null:
		# A cached object may have been freed by legacy gameplay code. Validate the
		# untyped Variant before casting it, because casting a freed Object errors.
		var candidate: Variant = available.pop_back()
		if not is_instance_valid(candidate):
			_metrics.discarded_invalid += 1
			continue
		if not candidate is Node:
			continue
		node = candidate as Node
	_available_by_scene[key] = available
	if node == null:
		_metrics.pool_misses += 1
		node = scene.instantiate()
	else:
		_metrics.pool_hits += 1
	if node == null:
		return null
	_in_use[node.get_instance_id()] = key
	node.set_meta("_pool_scene_key", key)
	node.set_meta(POOL_AVAILABLE_META, false)
	node.set_meta(POOL_RELEASE_PENDING_META, false)
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
	if bool(node.get_meta(POOL_AVAILABLE_META, false)) \
			or bool(node.get_meta(POOL_RELEASE_PENDING_META, false)):
		return
	_metrics.releases += 1
	if node.has_method("_on_before_pooled"):
		node.call("_on_before_pooled")
	var instance_id := node.get_instance_id()
	var key := str(_in_use.get(instance_id, node.get_meta("_pool_scene_key", "")))
	_in_use.erase(instance_id)
	if key == "":
		node.queue_free()
		return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node.get_parent() != null and _is_tree_teardown_pending(node):
		# Scene teardown can call release() while the parent is propagating a tree
		# notification. Godot forbids remove_child() in that window, so do not make
		# the object acquirable until a deferred detach has actually completed.
		node.set_meta(POOL_RELEASE_PENDING_META, true)
		_finalize_release.call_deferred(node, key)
		return
	_finalize_release(node, key)

func _is_tree_teardown_pending(node: Node) -> bool:
	var ancestor: Node = node
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return true
		ancestor = ancestor.get_parent()
	return false

func _finalize_release(node: Node, key: String) -> void:
	if node == null or not is_instance_valid(node):
		_metrics.discarded_invalid += 1
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if node.get_parent() != null:
		# A new tree mutation began before this deferred callback. Retry without
		# publishing the still-parented node to the available list.
		_finalize_release.call_deferred(node, key)
		return
	node.set_meta(POOL_RELEASE_PENDING_META, false)
	var available: Array = _available_by_scene.get(key, [])
	if available.size() >= maxi(max_cached_per_scene, 0):
		_metrics.discarded_capacity += 1
		node.queue_free()
		return
	node.set_meta(POOL_AVAILABLE_META, true)
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
	_in_use.clear()

func reset_metrics() -> void:
	for key in _metrics:
		_metrics[key] = 0

func get_metrics_snapshot() -> Dictionary:
	var snapshot := _metrics.duplicate(true)
	var available_total := 0
	for available_value in _available_by_scene.values():
		available_total += (available_value as Array).size()
	snapshot["available"] = available_total
	snapshot["in_use"] = _in_use.size()
	return snapshot

func _exit_tree() -> void:
	clear()
