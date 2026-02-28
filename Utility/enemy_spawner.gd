extends Node2D
class_name EnemySpawner

@onready var timer = $Timer
@export var debug_print_spawn_stats := false
@export var min_spawn_distance_from_player: float = 180.0
@export var spawn_point_attempts_per_enemy: int = 12
@onready var board = get_parent().get_node_or_null("Board")
@onready var x_min = $TopLeft.global_position.x
@onready var y_min = $TopLeft.global_position.y
@onready var x_max = $BottomRight.global_position.x
@onready var y_max = $BottomRight.global_position.y

var instance_list : Array
var time_out_list : Array
var board_cells : Array[Cell] = []
var _last_spawn_cell: Cell = null

func _ready():
	GlobalVariables.enemy_spawner = self
	_cache_board_cells()
	_refresh_spawn_tables()

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
	var wave_clear = true
	for e : SpawnInfo in enemy_spawns:
		if e.wave < e.max_wave or e.alive_enemy_number > 0:
			wave_clear = false
	if PhaseManager.battle_time >= time_out_list[level_index] or wave_clear or PhaseManager.phase == PhaseManager.REWARD:
		timer.stop()
		erase_all_enemies()
		PhaseManager.enter_reward()
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
				var counter = 0
				var random_position_center = get_random_position()
				while counter < i.number:
					var enemy_spawn = new_enemy.instantiate()
					_apply_level_scaling(i, enemy_spawn)
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
	var spawn_cell = _pick_spawn_cell_near_player(player)
	if spawn_cell:
		_last_spawn_cell = spawn_cell
		return _get_random_point_in_cell_away_from_player(spawn_cell, player.global_position)
	_last_spawn_cell = null
	return _get_fallback_spawn_position(player)

func _cache_board_cells() -> void:
	board_cells.clear()
	if board:
		for child in board.get_children():
			if child is Cell:
				board_cells.append(child)

func _pick_spawn_cell_near_player(player: Player) -> Cell:
	if board_cells.is_empty():
		_cache_board_cells()
	if board_cells.is_empty():
		return null
	var player_position = player.global_position
	var player_cell = _get_cell_at_position(player_position)
	var neighbor_cells = _get_neighbor_cells(player_cell)
	var view_rect := _get_player_view_rect(player)
	var visible_preferred : Array[Cell] = []
	var visible_fallback : Array[Cell] = []
	var preferred_cells : Array[Cell] = []
	var fallback_cells : Array[Cell] = []
	for cell in board_cells:
		if cell == null:
			continue
		if cell == player_cell:
			continue
		if not neighbor_cells.is_empty() and not neighbor_cells.has(cell):
			continue
		if not _cell_can_spawn_away_from_player(cell, player_position):
			continue
		var is_contested := cell.state == Cell.CellState.CONTESTED
		if cell.cell_owner == Cell.CellOwner.PLAYER and not is_contested:
			continue
		var is_visible := _cell_intersects_rect(cell, view_rect)
		if is_contested:
			if is_visible:
				visible_preferred.append(cell)
			else:
				preferred_cells.append(cell)
		elif cell.state != Cell.CellState.LOCKED:
			if is_visible:
				visible_fallback.append(cell)
			else:
				fallback_cells.append(cell)
	var ordered_lists = [visible_preferred, visible_fallback, preferred_cells, fallback_cells]
	for cell_list in ordered_lists:
		if cell_list.is_empty():
			continue
		if not cell_list.is_empty():
			return cell_list.pick_random()
	return null

func _get_cell_at_position(position: Vector2) -> Cell:
	for cell in board_cells:
		if _cell_contains_point(cell, position):
			return cell
	return null

func _cell_contains_point(cell: Cell, position: Vector2) -> bool:
	if cell == null:
		return false
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

func _get_neighbor_cells(player_cell: Cell) -> Array[Cell]:
	var neighbors : Array[Cell] = []
	if player_cell == null:
		return neighbors
	var max_neighbor_distance: float = _estimate_neighbor_distance(player_cell)
	for cell in board_cells:
		if cell == null or cell == player_cell:
			continue
		if cell.global_position.distance_to(player_cell.global_position) <= max_neighbor_distance:
			neighbors.append(cell)
	return neighbors

func _estimate_neighbor_distance(player_cell: Cell) -> float:
	var nearest_distance: float = INF
	for cell in board_cells:
		if cell == null or cell == player_cell:
			continue
		var distance: float = cell.global_position.distance_to(player_cell.global_position)
		if distance > 0.0 and distance < nearest_distance:
			nearest_distance = distance
	if nearest_distance == INF:
		return 0.0
	return nearest_distance * 1.1

func _project_point_into_cell(cell: Cell, position: Vector2) -> Vector2:
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

func _get_fallback_spawn_position(player: Player) -> Vector2:
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
		if player == null:
			return candidate
		var distance_to_player: float = candidate.distance_to(player.global_position)
		if distance_to_player >= min_spawn_distance_from_player:
			return candidate
		if distance_to_player > best_distance:
			best_distance = distance_to_player
			best_position = candidate
	return best_position

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

func _apply_level_scaling(spawn_info: SpawnInfo, enemy_instance) -> void:
	if enemy_instance is BaseEnemy:
		var base_enemy : BaseEnemy = enemy_instance
		var level_index = max(PhaseManager.current_level, 0)
		base_enemy.hp = spawn_info.get_scaled_hp(level_index, base_enemy.hp)
		base_enemy.damage = spawn_info.get_scaled_damage(level_index, base_enemy.damage)

func _debug_log_spawned_enemy(enemy_instance) -> void:
	if not debug_print_spawn_stats:
		return
	if enemy_instance is BaseEnemy:
		var base_enemy := enemy_instance as BaseEnemy
		print(
			"[Spawn] level=%s enemy=%s hp=%s damage=%s"
			% [PhaseManager.current_level, base_enemy.name, base_enemy.hp, base_enemy.damage]
		)
