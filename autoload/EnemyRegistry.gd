extends Node

signal enemy_registered(enemy: Node2D)
signal enemy_unregistered(enemy: Node2D)

# Match the default crowd-separation query radius so each spatial bucket tracks
# approximately one neighborhood instead of several overlapping neighborhoods.
const SPATIAL_CELL_SIZE := 48.0
const MAX_ENEMIES_PER_SPATIAL_CELL := 24
const CAPACITY_SEARCH_RING_LIMIT := 4

var _enemies: Array[Node2D] = []
var _enemy_ids: Dictionary = {}
var _enemy_index_by_id: Dictionary = {}
var _enemy_order_by_id: Dictionary = {}
var _next_enemy_order := 0
var _support_enemies: Array[BaseEnemy] = []
var _support_ids: Dictionary = {}

var _spatial_buckets: Dictionary = {}
var _enemy_cell_by_id: Dictionary = {}
var _spatial_bucket_index_by_id: Dictionary = {}
var _query_count := 0
var _candidate_checks := 0
var _bucket_visits := 0

func _ready() -> void:
	_rebuild_from_group()

func register_enemy(enemy: Node) -> void:
	var enemy2d := enemy as Node2D
	if enemy2d == null:
		return
	var instance_id := enemy2d.get_instance_id()
	if _enemy_ids.has(instance_id):
		update_enemy_position(enemy2d)
		refresh_enemy_roles(enemy2d)
		return
	_enemy_ids[instance_id] = true
	_enemy_order_by_id[instance_id] = _next_enemy_order
	_next_enemy_order += 1
	_enemy_index_by_id[instance_id] = _enemies.size()
	_enemies.append(enemy2d)
	var target_cell := _world_to_cell(enemy2d.global_position)
	if _get_bucket_size(target_cell) >= MAX_ENEMIES_PER_SPATIAL_CELL:
		var available_cell := _find_nearest_available_cell(target_cell)
		if available_cell != target_cell:
			var local_offset := enemy2d.global_position - Vector2(target_cell) * SPATIAL_CELL_SIZE
			enemy2d.global_position = Vector2(available_cell) * SPATIAL_CELL_SIZE + local_offset
			target_cell = available_cell
	_add_to_spatial_bucket(enemy2d, target_cell)
	refresh_enemy_roles(enemy2d)
	if not enemy2d.tree_exiting.is_connected(_on_enemy_tree_exiting.bind(instance_id)):
		enemy2d.tree_exiting.connect(_on_enemy_tree_exiting.bind(instance_id), CONNECT_ONE_SHOT)
	enemy_registered.emit(enemy2d)

func unregister_enemy(enemy: Node) -> void:
	if enemy != null:
		_unregister_enemy_id(enemy.get_instance_id())

func update_enemy_position(enemy: Node) -> void:
	var enemy2d := enemy as Node2D
	if enemy2d == null:
		return
	var instance_id := enemy2d.get_instance_id()
	if not _enemy_ids.has(instance_id):
		register_enemy(enemy2d)
		return
	var new_cell := _world_to_cell(enemy2d.global_position)
	var old_cell: Variant = _enemy_cell_by_id.get(instance_id)
	if old_cell is Vector2i and old_cell == new_cell:
		return
	if _get_bucket_size(new_cell) >= MAX_ENEMIES_PER_SPATIAL_CELL:
		var available_cell := _find_nearest_available_cell(new_cell)
		var local_offset := enemy2d.global_position - Vector2(new_cell) * SPATIAL_CELL_SIZE
		enemy2d.global_position = Vector2(available_cell) * SPATIAL_CELL_SIZE + local_offset
		new_cell = available_cell
	_remove_from_spatial_bucket(instance_id, old_cell)
	_add_to_spatial_bucket(enemy2d, new_cell)

func can_accept_position(world_position: Vector2, moving_enemy: Node = null) -> bool:
	var target_cell := _world_to_cell(world_position)
	if moving_enemy != null:
		var current_cell: Variant = _enemy_cell_by_id.get(moving_enemy.get_instance_id())
		if current_cell is Vector2i and current_cell == target_cell:
			return true
	return _get_bucket_size(target_cell) < MAX_ENEMIES_PER_SPATIAL_CELL

func get_separation_vector(requester: Node2D, radius: float, max_neighbors: int = 12) -> Vector2:
	if requester == null or radius <= 0.0 or max_neighbors <= 0:
		return Vector2.ZERO
	var radius_sq := radius * radius
	var accumulated := Vector2.ZERO
	var processed := 0
	_query_count += 1
	var minimum := requester.global_position - Vector2.ONE * radius
	var maximum := requester.global_position + Vector2.ONE * radius
	var min_cell := _world_to_cell(minimum)
	var max_cell := _world_to_cell(maximum)
	for cell_y in range(min_cell.y, max_cell.y + 1):
		for cell_x in range(min_cell.x, max_cell.x + 1):
			_bucket_visits += 1
			var bucket_value: Variant = _spatial_buckets.get(Vector2i(cell_x, cell_y))
			if not (bucket_value is Array):
				continue
			for candidate_value in bucket_value as Array:
				_candidate_checks += 1
				var candidate := candidate_value as Node2D
				if candidate == null or candidate == requester or not is_instance_valid(candidate):
					continue
				var away := requester.global_position - candidate.global_position
				var distance_sq := away.length_squared()
				if distance_sq > radius_sq:
					continue
				if distance_sq <= 0.0001:
					var pair_seed := requester.get_instance_id() ^ candidate.get_instance_id()
					away = Vector2.RIGHT.rotated(float(pair_seed % 360) * PI / 180.0)
					if requester.get_instance_id() < candidate.get_instance_id():
						away = -away
					distance_sq = 1.0
				var distance := sqrt(distance_sq)
				var weight := 1.0 - clampf(distance / radius, 0.0, 1.0)
				accumulated += away / distance * weight
				processed += 1
				if processed >= max_neighbors:
					return accumulated.normalized() * minf(accumulated.length(), 1.0)
	return accumulated.normalized() * minf(accumulated.length(), 1.0) if accumulated != Vector2.ZERO else Vector2.ZERO

func refresh_enemy_roles(enemy: Node) -> void:
	var base_enemy := enemy as BaseEnemy
	if base_enemy == null:
		return
	var instance_id := base_enemy.get_instance_id()
	var is_support := base_enemy.is_support_unit()
	if is_support and not _support_ids.has(instance_id):
		_support_ids[instance_id] = true
		_support_enemies.append(base_enemy)
	elif not is_support and _support_ids.erase(instance_id):
		_support_enemies.erase(base_enemy)

func get_enemy_count() -> int:
	_prune_invalid()
	return _enemies.size()

func get_enemies() -> Array[Node2D]:
	_prune_invalid()
	return _enemies.duplicate()

func get_support_enemies() -> Array[BaseEnemy]:
	_prune_invalid_supports()
	return _support_enemies.duplicate()

func get_repair_target(requester: Node, radius: float) -> Node2D:
	var requester2d := requester as Node2D
	if requester2d == null:
		return null
	var best: BaseEnemy
	var best_health := 1.0
	var best_distance_sq := INF
	for candidate_value in get_enemies_in_radius(requester2d.global_position, radius, requester):
		var candidate := candidate_value as BaseEnemy
		if candidate == null or candidate.is_dead or not candidate.can_receive_support_from(requester as BaseEnemy):
			continue
		var health_ratio := candidate.get_health_ratio()
		var distance_sq := requester2d.global_position.distance_squared_to(candidate.global_position)
		if health_ratio < best_health or (is_equal_approx(health_ratio, best_health) and distance_sq < best_distance_sq):
			best = candidate
			best_health = health_ratio
			best_distance_sq = distance_sq
	return best

func get_nearest_support(requester: Node, max_radius: float) -> Node2D:
	var requester2d := requester as Node2D
	if requester2d == null:
		return null
	var best: BaseEnemy
	var best_distance_sq := maxf(max_radius, 0.0) ** 2
	for candidate in get_support_enemies():
		if candidate == requester or not candidate.can_receive_support_from(requester as BaseEnemy):
			continue
		var distance_sq := requester2d.global_position.distance_squared_to(candidate.global_position)
		if distance_sq <= best_distance_sq:
			best = candidate
			best_distance_sq = distance_sq
	return best

func get_enemies_in_radius(origin: Vector2, radius: float, excluded: Node = null) -> Array[Node2D]:
	var output: Array[Node2D] = []
	var safe_radius := maxf(radius, 0.0)
	var max_radius_sq := safe_radius * safe_radius
	var excluded_id := excluded.get_instance_id() if excluded != null else 0
	_query_count += 1
	for enemy in _get_spatial_candidates(origin - Vector2.ONE * safe_radius, origin + Vector2.ONE * safe_radius):
		_candidate_checks += 1
		if enemy == null or not is_instance_valid(enemy):
			continue
		if excluded_id != 0 and enemy.get_instance_id() == excluded_id:
			continue
		if enemy.global_position.distance_squared_to(origin) <= max_radius_sq:
			output.append(enemy)
	_sort_by_registration_order(output)
	return output

func get_enemies_in_rect(world_rect: Rect2, excluded: Node = null) -> Array[Node2D]:
	var output: Array[Node2D] = []
	_query_count += 1
	if world_rect.size.x < 0.0 or world_rect.size.y < 0.0:
		return output
	var excluded_id := excluded.get_instance_id() if excluded != null else 0
	for enemy in _get_spatial_candidates(world_rect.position, world_rect.end):
		_candidate_checks += 1
		if enemy == null or not is_instance_valid(enemy):
			continue
		if excluded_id != 0 and enemy.get_instance_id() == excluded_id:
			continue
		if world_rect.has_point(enemy.global_position):
			output.append(enemy)
	_sort_by_registration_order(output)
	return output

func reset_query_metrics() -> void:
	_query_count = 0
	_candidate_checks = 0
	_bucket_visits = 0

func get_query_metrics() -> Dictionary:
	return {"query_count": _query_count, "candidate_checks": _candidate_checks, "bucket_visits": _bucket_visits}

func get_spatial_debug_snapshot() -> Dictionary:
	var bucket_entry_count := 0
	var max_bucket_occupancy := 0
	for bucket_value in _spatial_buckets.values():
		var bucket_size := (bucket_value as Array).size()
		bucket_entry_count += bucket_size
		max_bucket_occupancy = maxi(max_bucket_occupancy, bucket_size)
	return {
		"enemy_count": _enemies.size(),
		"indexed_enemy_count": _enemy_cell_by_id.size(),
		"bucket_count": _spatial_buckets.size(),
		"bucket_entry_count": bucket_entry_count,
		"support_count": _support_enemies.size(),
		"cell_size": SPATIAL_CELL_SIZE,
		"max_bucket_occupancy": max_bucket_occupancy,
		"bucket_capacity": MAX_ENEMIES_PER_SPATIAL_CELL,
		"has_frame_processing": is_physics_processing() or is_processing(),
	}

func _get_spatial_candidates(minimum: Vector2, maximum: Vector2) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	var min_cell := _world_to_cell(minimum)
	var max_cell := _world_to_cell(maximum)
	for cell_y in range(min_cell.y, max_cell.y + 1):
		for cell_x in range(min_cell.x, max_cell.x + 1):
			_bucket_visits += 1
			var bucket_value: Variant = _spatial_buckets.get(Vector2i(cell_x, cell_y))
			if not (bucket_value is Array):
				continue
			for enemy_value in bucket_value:
				var enemy := enemy_value as Node2D
				if enemy != null:
					candidates.append(enemy)
	return candidates

func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / SPATIAL_CELL_SIZE), floori(world_position.y / SPATIAL_CELL_SIZE))

func _get_bucket_size(cell: Vector2i) -> int:
	var bucket_value: Variant = _spatial_buckets.get(cell)
	return (bucket_value as Array).size() if bucket_value is Array else 0

func _find_nearest_available_cell(origin: Vector2i) -> Vector2i:
	if _get_bucket_size(origin) < MAX_ENEMIES_PER_SPATIAL_CELL:
		return origin
	for ring in range(1, CAPACITY_SEARCH_RING_LIMIT + 1):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if absi(x) != ring and absi(y) != ring:
					continue
				var candidate := origin + Vector2i(x, y)
				if _get_bucket_size(candidate) < MAX_ENEMIES_PER_SPATIAL_CELL:
					return candidate
	# 240 enemies cannot fill this search area at the configured capacity, but
	# retain a deterministic fallback if a caller bypasses the combat alive cap.
	var fallback := origin + Vector2i(CAPACITY_SEARCH_RING_LIMIT + 1, 0)
	while _get_bucket_size(fallback) >= MAX_ENEMIES_PER_SPATIAL_CELL:
		fallback.x += 1
	return fallback

func _sort_by_registration_order(enemies: Array[Node2D]) -> void:
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return int(_enemy_order_by_id.get(a.get_instance_id(), 0)) < int(_enemy_order_by_id.get(b.get_instance_id(), 0))
	)

func _add_to_spatial_bucket(enemy: Node2D, cell: Vector2i) -> void:
	var bucket: Array = _spatial_buckets.get(cell, [])
	_spatial_bucket_index_by_id[enemy.get_instance_id()] = bucket.size()
	bucket.append(enemy)
	_spatial_buckets[cell] = bucket
	_enemy_cell_by_id[enemy.get_instance_id()] = cell

func _remove_from_spatial_bucket(instance_id: int, cell_value: Variant) -> void:
	_enemy_cell_by_id.erase(instance_id)
	var index := int(_spatial_bucket_index_by_id.get(instance_id, -1))
	_spatial_bucket_index_by_id.erase(instance_id)
	if not (cell_value is Vector2i):
		return
	var cell := cell_value as Vector2i
	var bucket_value: Variant = _spatial_buckets.get(cell)
	if not (bucket_value is Array):
		return
	var bucket := bucket_value as Array
	if index < 0 or index >= bucket.size():
		return
	var last_index := bucket.size() - 1
	if index != last_index:
		var moved := bucket[last_index] as Node2D
		bucket[index] = moved
		if moved != null and is_instance_valid(moved):
			_spatial_bucket_index_by_id[moved.get_instance_id()] = index
	bucket.pop_back()
	if bucket.is_empty():
		_spatial_buckets.erase(cell)

func _rebuild_from_group() -> void:
	_enemies.clear()
	_enemy_ids.clear()
	_enemy_index_by_id.clear()
	_enemy_order_by_id.clear()
	_support_enemies.clear()
	_support_ids.clear()
	_next_enemy_order = 0
	_spatial_buckets.clear()
	_enemy_cell_by_id.clear()
	_spatial_bucket_index_by_id.clear()
	var tree := get_tree()
	if tree != null:
		for enemy in tree.get_nodes_in_group("enemies"):
			register_enemy(enemy)

func _on_enemy_tree_exiting(instance_id: int) -> void:
	_unregister_enemy_id(instance_id)

func _unregister_enemy_id(instance_id: int) -> void:
	if not _enemy_ids.erase(instance_id):
		return
	_enemy_order_by_id.erase(instance_id)
	var old_cell: Variant = _enemy_cell_by_id.get(instance_id)
	_remove_from_spatial_bucket(instance_id, old_cell)
	var index := int(_enemy_index_by_id.get(instance_id, -1))
	_enemy_index_by_id.erase(instance_id)
	if index < 0 or index >= _enemies.size():
		return
	var departing := _enemies[index]
	var last_index := _enemies.size() - 1
	if index != last_index:
		var moved := _enemies[last_index]
		_enemies[index] = moved
		if moved != null and is_instance_valid(moved):
			_enemy_index_by_id[moved.get_instance_id()] = index
	_enemies.pop_back()
	if _support_ids.erase(instance_id) and departing is BaseEnemy:
		_support_enemies.erase(departing as BaseEnemy)
	if departing != null and is_instance_valid(departing):
		enemy_unregistered.emit(departing)

func _prune_invalid() -> void:
	for instance_id_value in _enemy_index_by_id.keys():
		var instance_id := int(instance_id_value)
		if not is_instance_id_valid(instance_id):
			_unregister_enemy_id(instance_id)

func _prune_invalid_supports() -> void:
	for index in range(_support_enemies.size() - 1, -1, -1):
		var enemy := _support_enemies[index]
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_support_unit():
			if enemy != null and is_instance_valid(enemy):
				_support_ids.erase(enemy.get_instance_id())
			_support_enemies.remove_at(index)
