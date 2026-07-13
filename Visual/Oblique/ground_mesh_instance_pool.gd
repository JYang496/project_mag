class_name GroundMeshInstancePool
extends RefCounted

var _root: Node3D
var _available: Dictionary = {}
var _in_use: Dictionary = {}
var created_count: int = 0
var reused_count: int = 0

func setup(root: Node3D) -> void:
	_root = root

func acquire(pool_key: StringName, mesh_resource: Mesh = null) -> MeshInstance3D:
	var bucket := _available.get(pool_key, []) as Array
	var instance: MeshInstance3D
	while not bucket.is_empty() and instance == null:
		var candidate := bucket.pop_back() as MeshInstance3D
		if candidate != null and is_instance_valid(candidate):
			instance = candidate
	_available[pool_key] = bucket
	if instance == null:
		instance = MeshInstance3D.new()
		instance.set_meta(&"hybrid_pool_key", pool_key)
		_root.add_child(instance)
		created_count += 1
	else:
		reused_count += 1
	if mesh_resource != null:
		instance.mesh = mesh_resource
	instance.transform = Transform3D.IDENTITY
	instance.scale = Vector3.ONE
	instance.visible = false
	_in_use[instance.get_instance_id()] = instance
	return instance

func release(instance: MeshInstance3D) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	var instance_id := instance.get_instance_id()
	if not _in_use.has(instance_id):
		return
	_in_use.erase(instance_id)
	instance.visible = false
	instance.transform = Transform3D.IDENTITY
	instance.scale = Vector3.ONE
	var pool_key := instance.get_meta(&"hybrid_pool_key", &"default") as StringName
	var bucket := _available.get(pool_key, []) as Array
	bucket.append(instance)
	_available[pool_key] = bucket

func available_count(pool_key: StringName) -> int:
	return (_available.get(pool_key, []) as Array).size()

func clear() -> void:
	for instance in _in_use.values():
		if instance is MeshInstance3D and is_instance_valid(instance):
			(instance as MeshInstance3D).queue_free()
	for bucket_variant in _available.values():
		for instance in bucket_variant as Array:
			if instance is MeshInstance3D and is_instance_valid(instance):
				(instance as MeshInstance3D).queue_free()
	_in_use.clear()
	_available.clear()
