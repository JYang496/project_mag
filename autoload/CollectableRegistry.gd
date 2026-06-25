extends Node

var _collectables: Array[Node2D] = []
var _collectable_ids: Dictionary = {}

func _ready() -> void:
	_rebuild_from_group()

func register_collectable(collectable: Node) -> void:
	var collectable_2d := collectable as Node2D
	if collectable_2d == null:
		return
	var instance_id := collectable_2d.get_instance_id()
	if _collectable_ids.has(instance_id):
		return
	_collectable_ids[instance_id] = true
	_collectables.append(collectable_2d)
	if not collectable_2d.tree_exiting.is_connected(_on_collectable_tree_exiting.bind(instance_id)):
		collectable_2d.tree_exiting.connect(_on_collectable_tree_exiting.bind(instance_id), CONNECT_ONE_SHOT)

func unregister_collectable(collectable: Node) -> void:
	if collectable == null:
		return
	_unregister_collectable_id(collectable.get_instance_id())

func get_collectables() -> Array[Node2D]:
	_prune_invalid()
	return _collectables.duplicate()

func get_coins() -> Array[Coin]:
	var output: Array[Coin] = []
	_prune_invalid()
	for collectable in _collectables:
		var coin := collectable as Coin
		if coin != null and is_instance_valid(coin):
			output.append(coin)
	return output

func _rebuild_from_group() -> void:
	_collectables.clear()
	_collectable_ids.clear()
	var tree := get_tree()
	if tree == null:
		return
	for collectable in tree.get_nodes_in_group("collectables"):
		register_collectable(collectable)

func _on_collectable_tree_exiting(instance_id: int) -> void:
	_unregister_collectable_id(instance_id)

func _unregister_collectable_id(instance_id: int) -> void:
	if not _collectable_ids.erase(instance_id):
		return
	for i in range(_collectables.size() - 1, -1, -1):
		var collectable := _collectables[i]
		if collectable == null or not is_instance_valid(collectable) or collectable.get_instance_id() == instance_id:
			_collectables.remove_at(i)

func _prune_invalid() -> void:
	for i in range(_collectables.size() - 1, -1, -1):
		var collectable := _collectables[i]
		if collectable == null or not is_instance_valid(collectable):
			_collectables.remove_at(i)
