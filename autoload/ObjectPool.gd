extends Node
class_name ObjectPoolService

@export var max_cached_per_scene: int = 128
var _available: Dictionary = {}
var _in_use: Dictionary = {}

func acquire(scene: PackedScene) -> Node:
	if scene == null:
		return null
	var key := _scene_key(scene)
	var node: Node = scene.instantiate()
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
	# Pooling disabled: always free instead of caching for reuse.
	if node.has_method("_on_before_pooled"):
		node.call("_on_before_pooled")
	node.queue_free()
	_in_use.erase(node.get_instance_id())

func _scene_key(scene: PackedScene) -> String:
	var path := scene.resource_path
	if path != "":
		return path
	return "runtime_scene_%s" % str(scene.get_instance_id())
