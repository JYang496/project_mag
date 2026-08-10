extends Node

var _projectiles: Array[Node] = []
var _ids: Dictionary = {}
var _last_step_usec := 0
var _peak_step_usec := 0

func register_projectile(projectile: Node) -> bool:
	if projectile == null or not projectile.has_method("batch_simulation_step"):
		return false
	var instance_id := projectile.get_instance_id()
	if _ids.has(instance_id):
		return true
	_ids[instance_id] = true
	_projectiles.append(projectile)
	projectile.set_physics_process(false)
	return true

func unregister_projectile(projectile: Node, restore_processing := false) -> void:
	if projectile == null:
		return
	if _ids.erase(projectile.get_instance_id()):
		_projectiles.erase(projectile)
	if restore_processing and is_instance_valid(projectile):
		projectile.set_physics_process(true)

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	for index in range(_projectiles.size() - 1, -1, -1):
		var projectile := _projectiles[index]
		if projectile == null or not is_instance_valid(projectile) or not projectile.is_inside_tree():
			_projectiles.remove_at(index)
			continue
		projectile.call("batch_simulation_step", delta)
	_rebuild_ids_if_needed()
	_last_step_usec = Time.get_ticks_usec() - started
	_peak_step_usec = maxi(_peak_step_usec, _last_step_usec)

func get_metrics_snapshot() -> Dictionary:
	return {
		"registered": _projectiles.size(),
		"last_step_ms": float(_last_step_usec) / 1000.0,
		"peak_step_ms": float(_peak_step_usec) / 1000.0,
	}

func _rebuild_ids_if_needed() -> void:
	if _ids.size() == _projectiles.size():
		return
	_ids.clear()
	for projectile in _projectiles:
		_ids[projectile.get_instance_id()] = true
