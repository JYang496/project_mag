extends Node2D
class_name EnemySpawner

@onready var timer = $Timer
@export var debug_print_spawn_stats := false
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
		return _get_random_point_in_cell(spawn_cell)
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
		var is_contested := cell.state == Cell.CellState.CONTESTED
		if cell.cell_owner == Cell.CellOwner.PLAYER and not is_contested:
			continue
		var is_visible := _cell_intersects_rect(cell, view_rect)
		if cell.state == Cell.CellState.ENEMY or is_contested:
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
		var best_cell : Cell = null
		var best_distance := INF
		for candidate in cell_list:
			var distance = candidate.global_position.distance_squared_to(player_position)
			if distance < best_distance:
				best_distance = distance
				best_cell = candidate
		if best_cell:
			return best_cell
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
	var vpr = get_viewport_rect().size * randf_range(0.5,1.1)
	var top_left = clamp_position(player.global_position.x - vpr.x/2, player.global_position.y - vpr.y/2)
	var top_right = clamp_position(player.global_position.x + vpr.x/2, player.global_position.y - vpr.y/2)
	var bottom_left = clamp_position(player.global_position.x - vpr.x/2, player.global_position.y + vpr.y/2)
	var bottom_right = clamp_position(player.global_position.x + vpr.x/2, player.global_position.y + vpr.y/2)
	var pos_side = ["up","down","right","left"].pick_random()
	var spawn_pos1 = Vector2.ZERO
	var spawn_pos2 = Vector2.ZERO
	match pos_side:
		"up":
			spawn_pos1 = top_left
			spawn_pos2 = top_right
		"down":
			spawn_pos1 = bottom_left
			spawn_pos2 = bottom_right
		"right":
			spawn_pos1 = top_right
			spawn_pos2 = bottom_right
		"left":
			spawn_pos1 = top_left
			spawn_pos2 = bottom_left
	var x_spawn = randf_range(spawn_pos1.x, spawn_pos2.x)
	var y_spawn = randf_range(spawn_pos1.y, spawn_pos2.y)
	return Vector2(x_spawn,y_spawn)

func get_nearby_position(A: Vector2, min_distance: float = 0.0, max_distance: float = 100.0) -> Vector2:
	var angle = randf() * 2 * PI
	var distance = randf_range(min_distance, max_distance)
	var nearby_pos = A + Vector2(cos(angle), sin(angle)) * distance
	if _last_spawn_cell:
		return _project_point_into_cell(_last_spawn_cell, nearby_pos)
	return clamp_position(nearby_pos.x, nearby_pos.y)

func clamp_position(x_value :float, y_value :float) -> Vector2:
	return Vector2(clampf(x_value,x_min,x_max),clampf(y_value,y_min,y_max))

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
