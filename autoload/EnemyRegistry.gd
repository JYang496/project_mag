extends Node

var _enemies: Array[Node2D] = []
var _enemy_ids: Dictionary = {}

func _ready() -> void:
	_rebuild_from_group()

func register_enemy(enemy: Node) -> void:
	var enemy2d := enemy as Node2D
	if enemy2d == null:
		return
	var instance_id := enemy2d.get_instance_id()
	if _enemy_ids.has(instance_id):
		return
	_enemy_ids[instance_id] = true
	_enemies.append(enemy2d)
	if not enemy2d.tree_exiting.is_connected(_on_enemy_tree_exiting.bind(instance_id)):
		enemy2d.tree_exiting.connect(_on_enemy_tree_exiting.bind(instance_id), CONNECT_ONE_SHOT)

func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	_unregister_enemy_id(enemy.get_instance_id())

func get_enemy_count() -> int:
	_prune_invalid()
	return _enemies.size()

func get_enemies() -> Array[Node2D]:
	_prune_invalid()
	return _enemies.duplicate()

func get_enemies_in_radius(origin: Vector2, radius: float, excluded: Node = null) -> Array[Node2D]:
	var output: Array[Node2D] = []
	var max_radius_sq := maxf(radius, 0.0)
	max_radius_sq *= max_radius_sq
	var excluded_id := excluded.get_instance_id() if excluded != null else 0
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if excluded_id != 0 and enemy.get_instance_id() == excluded_id:
			continue
		if enemy.global_position.distance_squared_to(origin) > max_radius_sq:
			continue
		output.append(enemy)
	return output

func get_enemies_in_rect(world_rect: Rect2, excluded: Node = null) -> Array[Node2D]:
	var output: Array[Node2D] = []
	var excluded_id := excluded.get_instance_id() if excluded != null else 0
	for enemy in _enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if excluded_id != 0 and enemy.get_instance_id() == excluded_id:
			continue
		if not world_rect.has_point(enemy.global_position):
			continue
		output.append(enemy)
	return output

func _rebuild_from_group() -> void:
	_enemies.clear()
	_enemy_ids.clear()
	var tree := get_tree()
	if tree == null:
		return
	for enemy in tree.get_nodes_in_group("enemies"):
		register_enemy(enemy)

func _on_enemy_tree_exiting(instance_id: int) -> void:
	_unregister_enemy_id(instance_id)

func _unregister_enemy_id(instance_id: int) -> void:
	if not _enemy_ids.erase(instance_id):
		return
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		if enemy == null or not is_instance_valid(enemy) or enemy.get_instance_id() == instance_id:
			_enemies.remove_at(i)

func _prune_invalid() -> void:
	for i in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[i]
		if enemy == null or not is_instance_valid(enemy):
			_enemies.remove_at(i)
