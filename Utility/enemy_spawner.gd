extends Node2D
class_name EnemySpawner

@onready var timer = $Timer
@export var debug_print_spawn_stats := false
@export var min_spawn_distance_from_player: float = 180.0
@export var spawn_point_attempts_per_enemy: int = 12
@export var spawn_edge_margin: float = 28.0
@onready var board = get_parent().get_node_or_null("Board")
@onready var top_left_marker: Node2D = $TopLeft
@onready var bottom_right_marker: Node2D = $BottomRight

var instance_list : Array
var time_out_list : Array
var board_cells : Array[Cell] = []
var _last_spawn_cell: Cell = null
var x_min: float = 0.0
var y_min: float = 0.0
var x_max: float = 0.0
var y_max: float = 0.0

func _ready():
	GlobalVariables.enemy_spawner = self
	_cache_board_cells()
	if board and board.has_signal("active_cells_changed") and not board.is_connected("active_cells_changed", Callable(self, "_on_board_active_cells_changed")):
		board.connect("active_cells_changed", Callable(self, "_on_board_active_cells_changed"))
	_refresh_fallback_bounds()
	_refresh_spawn_tables()

func _on_board_active_cells_changed(_active_cell_ids: PackedInt32Array) -> void:
	_refresh_fallback_bounds()

func _refresh_spawn_tables() -> void:
	instance_list = []
	time_out_list = []
	for level_config in SpawnData.level_list:
		if level_config == null:
			continue
		var ins = level_config.duplicate(true)
		if ins == null:
			continue
		instance_list.append(ins.spawns)
		time_out_list.append(ins.time_out)

func start_timer() -> void:
	if instance_list.is_empty() or time_out_list.is_empty():
		_refresh_spawn_tables()
	if instance_list.is_empty() or time_out_list.is_empty():
		push_warning("EnemySpawner cannot start: spawn tables are empty.")
		return
	PhaseManager.battle_time = 0
	timer.start()

func _on_timer_timeout():
	if instance_list.is_empty() or time_out_list.is_empty():
		timer.stop()
		push_warning("EnemySpawner timeout with empty spawn tables.")
		return
	var level_index := clampi(PhaseManager.current_level, 0, instance_list.size() - 1)
	PhaseManager.battle_time += 1
	var enemy_spawns = instance_list[level_index]
	var base_time_out: int = int(time_out_list[level_index])
	var effective_time_out: int = get_effective_time_out(base_time_out, level_index)
	var wave_clear = true
	for e : SpawnInfo in enemy_spawns:
		if e.wave < e.max_wave or e.alive_enemy_number > 0:
			wave_clear = false
	if PhaseManager.battle_time >= effective_time_out or wave_clear:
		timer.stop()
		erase_all_enemies()
		PhaseManager.enter_prepare()
		return
	for i : SpawnInfo in enemy_spawns:
		if PhaseManager.battle_time >= i.time_start and i.wave < i.max_wave:
			if i.interval_counter > 1:
				i.interval_counter -= 1
			else:
				if i.alive_enemy_number >= i.max_enemy_number:
					continue
				i.wave += 1
				i.interval_counter = i.interval
				var new_enemy = i.enemy
				var spawn_count: int = max(1, i.number)
				var loot_value_multiplier: float = 1.0
				var preview_enemy: Node = new_enemy.instantiate()
				if preview_enemy is BaseEnemy:
					var base_preview: BaseEnemy = preview_enemy as BaseEnemy
					if base_preview.is_ranged_enemy():
						spawn_count = maxi(1, int(ceil(float(i.number) * 0.5)))
						loot_value_multiplier = float(max(1, i.number)) / float(spawn_count)
				if preview_enemy != null and is_instance_valid(preview_enemy):
					preview_enemy.free()
				var counter = 0
				var random_position_center = get_random_position()
				while counter < spawn_count:
					var enemy_spawn = new_enemy.instantiate()
					_apply_level_scaling(i, enemy_spawn)
					if enemy_spawn is BaseEnemy:
						var base_enemy := enemy_spawn as BaseEnemy
						base_enemy.loot_value_multiplier = maxf(loot_value_multiplier, 0.1)
					_debug_log_spawned_enemy(enemy_spawn)
					enemy_spawn.global_position = get_nearby_position(random_position_center)
					self.call_deferred("add_child",enemy_spawn)
					i.add_enemy_with_signal(enemy_spawn)
					counter += 1

func get_random_position() -> Vector2:
	var player : Player = PlayerData.player
	if player == null:
		_last_spawn_cell = null
		return Vector2.ZERO
	_refresh_fallback_bounds()
	var spawn_cell = _pick_spawn_cell_near_player(player)
	if spawn_cell:
		_last_spawn_cell = spawn_cell
		return _apply_spawn_safety_margin(_get_random_point_in_cell_away_from_player(spawn_cell, player.global_position))
	_last_spawn_cell = null
	return _apply_spawn_safety_margin(_get_fallback_spawn_position(player))

func _cache_board_cells() -> void:
	board_cells.clear()
	if board:
		for child in board.get_children():
			if child is Cell:
				board_cells.append(child)
	_refresh_fallback_bounds()

func _refresh_fallback_bounds() -> void:
	var bounds_set := false
	var min_x := 0.0
	var min_y := 0.0
	var max_x := 0.0
	var max_y := 0.0
	var effective_cells := _get_effective_board_cells()
	for cell in effective_cells:
		if cell == null:
			continue
		var cell_rect: Rect2 = _get_cell_aabb(cell)
		if cell_rect.size == Vector2.ZERO:
			continue
		if not bounds_set:
			min_x = cell_rect.position.x
			min_y = cell_rect.position.y
			max_x = cell_rect.end.x
			max_y = cell_rect.end.y
			bounds_set = true
			continue
		min_x = minf(min_x, cell_rect.position.x)
		min_y = minf(min_y, cell_rect.position.y)
		max_x = maxf(max_x, cell_rect.end.x)
		max_y = maxf(max_y, cell_rect.end.y)
	if not bounds_set:
		if top_left_marker != null and bottom_right_marker != null:
			min_x = minf(top_left_marker.global_position.x, bottom_right_marker.global_position.x)
			min_y = minf(top_left_marker.global_position.y, bottom_right_marker.global_position.y)
			max_x = maxf(top_left_marker.global_position.x, bottom_right_marker.global_position.x)
			max_y = maxf(top_left_marker.global_position.y, bottom_right_marker.global_position.y)
		else:
			min_x = -1000.0
			min_y = -1000.0
			max_x = 1000.0
			max_y = 1000.0
	x_min = min_x
	y_min = min_y
	x_max = max_x
	y_max = max_y

func _pick_spawn_cell_near_player(player: Player) -> Cell:
	var effective_cells := _get_effective_board_cells()
	if effective_cells.is_empty():
		_cache_board_cells()
		effective_cells = _get_effective_board_cells()
	if effective_cells.is_empty():
		return null
	var player_position = player.global_position
	var player_cell = _get_cell_at_position(player_position, effective_cells)
	var neighbor_cells = _get_neighbor_cells(player_cell, effective_cells)
	var neighbor_candidates : Array[Cell] = []
	var fallback_candidates : Array[Cell] = []
	for cell in effective_cells:
		if cell == null:
			continue
		if cell == player_cell:
			continue
		if not _cell_can_spawn_away_from_player(cell, player_position):
			continue
		if not neighbor_cells.is_empty() and neighbor_cells.has(cell):
			neighbor_candidates.append(cell)
		else:
			fallback_candidates.append(cell)
	if not neighbor_candidates.is_empty():
		return neighbor_candidates.pick_random()
	if not fallback_candidates.is_empty():
		return fallback_candidates.pick_random()
	return null

func _get_cell_at_position(position: Vector2, cells: Array[Cell]) -> Cell:
	for cell in cells:
		if _cell_contains_point(cell, position):
			return cell
	return null

func _cell_contains_point(cell: Cell, position: Vector2) -> bool:
	if cell == null:
		return false
	var capture_polygon: CollisionPolygon2D = _get_cell_capture_polygon(cell)
	if capture_polygon:
		return _is_point_inside_capture_polygon(capture_polygon, position)
	var collision_shape : CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape == null:
		return false
	var rect_shape := collision_shape.shape
	if rect_shape is RectangleShape2D:
		var half_size = rect_shape.size * 0.5
		var local_point = collision_shape.global_transform.affine_inverse() * position
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	return false

func _get_random_point_in_cell(cell: Cell) -> Vector2:
	var capture_polygon: CollisionPolygon2D = _get_cell_capture_polygon(cell)
	if capture_polygon:
		return _get_random_point_in_capture_polygon(capture_polygon)
	var collision_shape : CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape : RectangleShape2D = collision_shape.shape
		var half_size = rect_shape.size * 0.5
		var random_local = Vector2(
			randf_range(-half_size.x, half_size.x),
			randf_range(-half_size.y, half_size.y)
		)
		return collision_shape.global_transform * random_local
	return cell.global_position

func _get_random_point_in_cell_away_from_player(cell: Cell, player_position: Vector2) -> Vector2:
	var attempts: int = max(spawn_point_attempts_per_enemy, 1)
	var best_point: Vector2 = _get_random_point_in_cell(cell)
	var best_distance: float = best_point.distance_to(player_position)
	for _i in range(attempts):
		var candidate: Vector2 = _get_random_point_in_cell(cell)
		var distance_to_player: float = candidate.distance_to(player_position)
		if distance_to_player >= min_spawn_distance_from_player:
			return candidate
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_point = candidate
	return best_point

func _cell_can_spawn_away_from_player(cell: Cell, player_position: Vector2) -> bool:
	var cell_rect: Rect2 = _get_cell_aabb(cell)
	if cell_rect.size == Vector2.ZERO:
		return cell.global_position.distance_to(player_position) >= min_spawn_distance_from_player
	var farthest_point := Vector2(
		cell_rect.position.x if absf(player_position.x - cell_rect.position.x) > absf(player_position.x - cell_rect.end.x) else cell_rect.end.x,
		cell_rect.position.y if absf(player_position.y - cell_rect.position.y) > absf(player_position.y - cell_rect.end.y) else cell_rect.end.y
	)
	return farthest_point.distance_to(player_position) >= min_spawn_distance_from_player

func _get_neighbor_cells(player_cell: Cell, cells: Array[Cell]) -> Array[Cell]:
	var neighbors : Array[Cell] = []
	if player_cell == null:
		return neighbors
	var max_neighbor_distance: float = _estimate_neighbor_distance(player_cell, cells)
	for cell in cells:
		if cell == null or cell == player_cell:
			continue
		if cell.global_position.distance_to(player_cell.global_position) <= max_neighbor_distance:
			neighbors.append(cell)
	return neighbors

func _estimate_neighbor_distance(player_cell: Cell, cells: Array[Cell]) -> float:
	var nearest_distance: float = INF
	for cell in cells:
		if cell == null or cell == player_cell:
			continue
		var distance: float = cell.global_position.distance_to(player_cell.global_position)
		if distance > 0.0 and distance < nearest_distance:
			nearest_distance = distance
	if nearest_distance == INF:
		return 0.0
	return nearest_distance * 1.1

func _project_point_into_cell(cell: Cell, position: Vector2) -> Vector2:
	var capture_polygon: CollisionPolygon2D = _get_cell_capture_polygon(cell)
	if capture_polygon:
		return _project_point_into_capture_polygon(capture_polygon, position)
	var collision_shape : CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape == null:
		return position
	var rect_shape := collision_shape.shape
	if rect_shape is RectangleShape2D:
		var half_size = rect_shape.size * 0.5
		var local_point = collision_shape.global_transform.affine_inverse() * position
		local_point.x = clampf(local_point.x, -half_size.x, half_size.x)
		local_point.y = clampf(local_point.y, -half_size.y, half_size.y)
		return collision_shape.global_transform * local_point
	return position

func _get_player_view_rect(player: Player) -> Rect2:
	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size * 0.5
	var top_left = player.global_position - half_size
	return Rect2(top_left, viewport_size)

func _cell_intersects_rect(cell: Cell, rect: Rect2) -> bool:
	var cell_rect := _get_cell_aabb(cell)
	if cell_rect.size == Vector2.ZERO:
		return rect.has_point(cell.global_position)
	return cell_rect.intersects(rect)

func _get_cell_aabb(cell: Cell) -> Rect2:
	var capture_polygon: CollisionPolygon2D = _get_cell_capture_polygon(cell)
	if capture_polygon:
		return _get_capture_polygon_aabb(capture_polygon)
	var collision_shape : CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape : RectangleShape2D = collision_shape.shape
		var half_size = rect_shape.size * 0.5
		var gt := collision_shape.global_transform
		var points = [
			gt * Vector2(-half_size.x, -half_size.y),
			gt * Vector2(half_size.x, -half_size.y),
			gt * Vector2(half_size.x, half_size.y),
			gt * Vector2(-half_size.x, half_size.y)
		]
		var min_x = points[0].x
		var max_x = points[0].x
		var min_y = points[0].y
		var max_y = points[0].y
		for p in points:
			min_x = min(min_x, p.x)
			max_x = max(max_x, p.x)
			min_y = min(min_y, p.y)
			max_y = max(max_y, p.y)
		return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
	return Rect2(cell.global_position, Vector2.ZERO)

func _get_cell_capture_polygon(cell: Cell) -> CollisionPolygon2D:
	if cell == null:
		return null
	return cell.get_node_or_null("Area2D/CapturePolygon") as CollisionPolygon2D

func _is_point_inside_capture_polygon(capture_polygon: CollisionPolygon2D, world_position: Vector2) -> bool:
	if capture_polygon == null or capture_polygon.polygon.is_empty():
		return false
	var local_point: Vector2 = capture_polygon.global_transform.affine_inverse() * world_position
	return Geometry2D.is_point_in_polygon(local_point, capture_polygon.polygon)

func _get_random_point_in_capture_polygon(capture_polygon: CollisionPolygon2D) -> Vector2:
	if capture_polygon == null or capture_polygon.polygon.is_empty():
		return Vector2.ZERO
	var local_aabb: Rect2 = _get_polygon_local_aabb(capture_polygon.polygon)
	var attempts: int = max(spawn_point_attempts_per_enemy * 2, 12)
	for _i in range(attempts):
		var candidate_local: Vector2 = Vector2(
			randf_range(local_aabb.position.x, local_aabb.end.x),
			randf_range(local_aabb.position.y, local_aabb.end.y)
		)
		if Geometry2D.is_point_in_polygon(candidate_local, capture_polygon.polygon):
			return capture_polygon.global_transform * candidate_local
	var centroid_local: Vector2 = _get_polygon_centroid(capture_polygon.polygon)
	return capture_polygon.global_transform * centroid_local

func _project_point_into_capture_polygon(capture_polygon: CollisionPolygon2D, world_position: Vector2) -> Vector2:
	if capture_polygon == null or capture_polygon.polygon.is_empty():
		return world_position
	if _is_point_inside_capture_polygon(capture_polygon, world_position):
		return world_position
	var local_aabb: Rect2 = _get_polygon_local_aabb(capture_polygon.polygon)
	var local_point: Vector2 = capture_polygon.global_transform.affine_inverse() * world_position
	local_point.x = clampf(local_point.x, local_aabb.position.x, local_aabb.end.x)
	local_point.y = clampf(local_point.y, local_aabb.position.y, local_aabb.end.y)
	if Geometry2D.is_point_in_polygon(local_point, capture_polygon.polygon):
		return capture_polygon.global_transform * local_point
	var nearest_polygon_point: Vector2 = capture_polygon.polygon[0]
	var nearest_distance: float = nearest_polygon_point.distance_squared_to(local_point)
	for polygon_point in capture_polygon.polygon:
		var point_distance: float = polygon_point.distance_squared_to(local_point)
		if point_distance < nearest_distance:
			nearest_distance = point_distance
			nearest_polygon_point = polygon_point
	return capture_polygon.global_transform * nearest_polygon_point

func _get_capture_polygon_aabb(capture_polygon: CollisionPolygon2D) -> Rect2:
	var polygon_points: PackedVector2Array = capture_polygon.polygon
	if polygon_points.is_empty():
		return Rect2(capture_polygon.global_position, Vector2.ZERO)
	var first_point: Vector2 = capture_polygon.global_transform * polygon_points[0]
	var min_x: float = first_point.x
	var max_x: float = first_point.x
	var min_y: float = first_point.y
	var max_y: float = first_point.y
	for local_point in polygon_points:
		var world_point: Vector2 = capture_polygon.global_transform * local_point
		min_x = minf(min_x, world_point.x)
		max_x = maxf(max_x, world_point.x)
		min_y = minf(min_y, world_point.y)
		max_y = maxf(max_y, world_point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _get_polygon_local_aabb(polygon_points: PackedVector2Array) -> Rect2:
	if polygon_points.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var min_x: float = polygon_points[0].x
	var max_x: float = polygon_points[0].x
	var min_y: float = polygon_points[0].y
	var max_y: float = polygon_points[0].y
	for polygon_point in polygon_points:
		min_x = minf(min_x, polygon_point.x)
		max_x = maxf(max_x, polygon_point.x)
		min_y = minf(min_y, polygon_point.y)
		max_y = maxf(max_y, polygon_point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _get_polygon_centroid(polygon_points: PackedVector2Array) -> Vector2:
	if polygon_points.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for polygon_point in polygon_points:
		center += polygon_point
	return center / float(polygon_points.size())

func _get_fallback_spawn_position(player: Player) -> Vector2:
	var far_cell := _pick_farthest_cell_from_player(player.global_position)
	if far_cell:
		_last_spawn_cell = far_cell
		return _get_random_point_in_cell_away_from_player(far_cell, player.global_position)
	var attempts: int = max(spawn_point_attempts_per_enemy, 1)
	var best_pos: Vector2 = _get_farthest_boundary_point(player.global_position)
	var best_distance: float = 0.0
	for _i in range(attempts):
		var candidate: Vector2 = _get_random_boundary_position_away_from_player(player.global_position)
		var distance_to_player: float = candidate.distance_to(player.global_position)
		if distance_to_player >= min_spawn_distance_from_player:
			return candidate
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_pos = candidate
	return best_pos

func _pick_farthest_cell_from_player(player_position: Vector2) -> Cell:
	var effective_cells := _get_effective_board_cells()
	if effective_cells.is_empty():
		_cache_board_cells()
		effective_cells = _get_effective_board_cells()
	if effective_cells.is_empty():
		return null
	var best_cell: Cell = null
	var best_distance := -1.0
	for cell in effective_cells:
		if cell == null:
			continue
		if not _cell_can_spawn_away_from_player(cell, player_position):
			continue
		var distance_to_player: float = cell.global_position.distance_to(player_position)
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_cell = cell
	return best_cell

func _get_effective_board_cells() -> Array[Cell]:
	if board and board.has_method("get_active_cells"):
		var active_cells_variant: Variant = board.call("get_active_cells")
		if active_cells_variant is Array:
			var active_cells_raw := active_cells_variant as Array
			var active_cells: Array[Cell] = []
			for node in active_cells_raw:
				if node is Cell:
					active_cells.append(node as Cell)
			if not active_cells.is_empty():
				return active_cells
	return board_cells

func get_nearby_position(A: Vector2, min_distance: float = 0.0, max_distance: float = 100.0) -> Vector2:
	var player : Player = PlayerData.player
	var attempts: int = max(spawn_point_attempts_per_enemy, 1)
	var best_position: Vector2 = A
	var best_distance: float = 0.0
	for _i in range(attempts):
		var angle: float = randf() * 2.0 * PI
		var distance: float = randf_range(min_distance, max_distance)
		var nearby_pos: Vector2 = A + Vector2(cos(angle), sin(angle)) * distance
		var candidate: Vector2 = nearby_pos
		if _last_spawn_cell:
			candidate = _project_point_into_cell(_last_spawn_cell, nearby_pos)
		else:
			candidate = clamp_position(nearby_pos.x, nearby_pos.y)
		candidate = _apply_spawn_safety_margin(candidate)
		if player == null:
			return candidate
		var distance_to_player: float = candidate.distance_to(player.global_position)
		if distance_to_player >= min_spawn_distance_from_player:
			return candidate
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_position = candidate
	return best_position

func _apply_spawn_safety_margin(position: Vector2) -> Vector2:
	var margin := maxf(spawn_edge_margin, 0.0)
	if margin <= 0.001:
		return position
	if board != null and board.has_method("project_point_to_enemy_traversable_area_with_margin"):
		var projected_with_margin: Variant = board.call("project_point_to_enemy_traversable_area_with_margin", position, margin)
		if projected_with_margin is Vector2:
			return projected_with_margin as Vector2
	if _last_spawn_cell != null:
		var center: Vector2 = _last_spawn_cell.global_position
		if position.distance_squared_to(center) > 0.0001:
			var moved := position.move_toward(center, margin)
			if _cell_contains_point(_last_spawn_cell, moved):
				return moved
	return position

func clamp_position(x_value :float, y_value :float) -> Vector2:
	return Vector2(clampf(x_value,x_min,x_max),clampf(y_value,y_min,y_max))

func _get_random_boundary_position_away_from_player(player_position: Vector2) -> Vector2:
	var boundary_points := [
		Vector2(randf_range(x_min, x_max), y_min),
		Vector2(randf_range(x_min, x_max), y_max),
		Vector2(x_min, randf_range(y_min, y_max)),
		Vector2(x_max, randf_range(y_min, y_max))
	]
	var best_point: Vector2 = boundary_points[0]
	var best_distance: float = best_point.distance_to(player_position)
	for point in boundary_points:
		var point_distance: float = point.distance_to(player_position)
		if point_distance > best_distance:
			best_distance = point_distance
			best_point = point
	return best_point

func _get_farthest_boundary_point(player_position: Vector2) -> Vector2:
	var corners := [
		Vector2(x_min, y_min),
		Vector2(x_max, y_min),
		Vector2(x_min, y_max),
		Vector2(x_max, y_max)
	]
	var best_point: Vector2 = corners[0]
	var best_distance: float = best_point.distance_to(player_position)
	for point in corners:
		var point_distance: float = point.distance_to(player_position)
		if point_distance > best_distance:
			best_distance = point_distance
			best_point = point
	return best_point

func erase_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e : BaseEnemy in enemies:
		e.erase()
	for runtime_node in get_tree().get_nodes_in_group("enemy_runtime_cleanup"):
		if runtime_node == null or not is_instance_valid(runtime_node):
			continue
		if runtime_node.has_method("erase"):
			runtime_node.call_deferred("erase")
		else:
			runtime_node.call_deferred("queue_free")

func _apply_level_scaling(spawn_info: SpawnInfo, enemy_instance) -> void:
	if enemy_instance is BaseEnemy:
		var base_enemy : BaseEnemy = enemy_instance
		var level_index = max(PhaseManager.current_level, 0)
		var scaled_stats := calculate_scaled_enemy_stats(spawn_info, base_enemy.hp, base_enemy.damage, level_index)
		base_enemy.hp = int(scaled_stats.get("hp", base_enemy.hp))
		base_enemy.damage = int(scaled_stats.get("damage", base_enemy.damage))

func calculate_scaled_enemy_stats(
	spawn_info: SpawnInfo,
	fallback_hp: int,
	fallback_damage: int,
	level_index: int
) -> Dictionary:
	var scaled_hp := spawn_info.get_scaled_hp(level_index, fallback_hp)
	var scaled_damage := spawn_info.get_scaled_damage(level_index, fallback_damage)
	var route_def := RunRouteManager.get_route_for_level(level_index)
	if route_def:
		scaled_hp = max(1, int(round(float(scaled_hp) * route_def.enemy_hp_multiplier)))
		scaled_damage = max(1, int(round(float(scaled_damage) * route_def.enemy_damage_multiplier)))
	return {"hp": scaled_hp, "damage": scaled_damage}

func get_effective_time_out(base_time_out: int, level_index: int) -> int:
	var safe_base: int = max(base_time_out, 1)
	var route_def := RunRouteManager.get_route_for_level(level_index)
	if route_def == null:
		return safe_base
	return max(1, int(round(float(safe_base) * route_def.battle_timeout_multiplier)))

func _debug_log_spawned_enemy(enemy_instance) -> void:
	if not debug_print_spawn_stats:
		return
	if enemy_instance is BaseEnemy:
		var base_enemy := enemy_instance as BaseEnemy
		print(
			"[Spawn] level=%s enemy=%s hp=%s damage=%s"
			% [PhaseManager.current_level, base_enemy.name, base_enemy.hp, base_enemy.damage]
		)
