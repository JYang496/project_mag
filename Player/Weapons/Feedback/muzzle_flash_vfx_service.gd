class_name MuzzleFlashVfxService
extends Node

const MAX_ACTIVE_EFFECTS := 12

var _entries: Array[Dictionary] = []
var _serial := 0

static func ensure(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	var existing := tree.get_first_node_in_group(&"muzzle_flash_vfx_service")
	if existing != null:
		return existing
	var service = load("res://Player/Weapons/Feedback/muzzle_flash_vfx_service.gd").new()
	service.name = "MuzzleFlashVfxService"
	service.add_to_group(&"muzzle_flash_vfx_service")
	tree.root.add_child(service)
	return service

func play(scene: PackedScene, visual_position: Vector2, visual_direction: Vector2, signature: Dictionary = {}) -> bool:
	if scene == null:
		return false
	var entry := _acquire_entry(scene)
	if entry.is_empty():
		return false
	var visual := entry.get("visual") as Node2D
	_serial += 1
	entry["serial"] = _serial
	entry["active"] = true
	visual.global_position = visual_position
	visual.visible = true
	if visual.has_method("apply_signature"):
		visual.call("apply_signature", signature)
	if visual.has_method("setup"):
		visual.call("setup", visual_direction)
	else:
		visual.global_rotation = visual_direction.angle()
	return true

func get_pool_metrics() -> Dictionary:
	var active := 0
	for entry in _entries:
		if bool(entry.get("active", false)):
			active += 1
	return {"pooled": _entries.size(), "active": active, "limit": MAX_ACTIVE_EFFECTS}

func _acquire_entry(scene: PackedScene) -> Dictionary:
	var scene_id := scene.get_instance_id()
	for entry in _entries:
		if not bool(entry.get("active", false)) and int(entry.get("scene_id", 0)) == scene_id:
			return entry
	if _entries.size() < MAX_ACTIVE_EFFECTS:
		return _create_entry(scene, scene_id)
	var oldest := _entries[0]
	for entry in _entries:
		if int(entry.get("serial", 0)) < int(oldest.get("serial", 0)):
			oldest = entry
	if int(oldest.get("scene_id", 0)) != scene_id:
		var existing_visual := oldest.get("visual") as Node2D
		if existing_visual != null:
			existing_visual.queue_free()
		var replacement := _instantiate_visual(scene)
		if replacement == null:
			return {}
		oldest["visual"] = replacement
		oldest["scene_id"] = scene_id
	return oldest

func _create_entry(scene: PackedScene, scene_id: int) -> Dictionary:
	var visual := _instantiate_visual(scene)
	if visual == null:
		return {}
	var entry := {"visual": visual, "scene_id": scene_id, "active": false, "serial": 0}
	_entries.append(entry)
	return entry

func _instantiate_visual(scene: PackedScene) -> Node2D:
	var visual := scene.instantiate() as Node2D
	if visual == null:
		return null
	add_child(visual)
	visual.visible = false
	if visual.has_method("prepare_for_pool"):
		visual.call("prepare_for_pool")
	if visual.has_signal("finished"):
		visual.connect("finished", _on_visual_finished.bind(visual.get_instance_id()))
	return visual

func _on_visual_finished(visual_id: int) -> void:
	for entry in _entries:
		var visual := entry.get("visual") as Node2D
		if visual != null and visual.get_instance_id() == visual_id:
			entry["active"] = false
			return

func _exit_tree() -> void:
	_entries.clear()
