extends Node2D
class_name BoardCellGenerator

signal active_cells_changed(active_cell_ids: PackedInt32Array)

@export var cell_scene: PackedScene
@export var cell_spacing: Vector2 = Vector2(510, 510)
@export var player_spawner_path: NodePath
@export var center_spawn_offset: Vector2 = Vector2(255, 258)
@export var auto_assign_enemy_on_battle := true
@export var initial_cell_profiles: Array[CellProfile] = []
@export_group("Debug")
@export var debug_recenter_logs: bool = false
@export_group("Board Blockers")
@export var blocker_collision_layer: int = 32
@export var blocker_collision_mask: int = 0
@export var corner_pillar_size: Vector2 = Vector2(48, 48)
@export var border_wall_thickness: float = 48.0
@export var internal_boundary_wall_thickness: float = 18.0
@export var enemy_traversable_inset: float = 6.0
@export_group("Blocker Visuals")
@export var blocker_visual_z_index: int = 5
@export var pillar_visual_color: Color = Color(0.20, 0.20, 0.20, 0.85)
@export var wall_visual_color: Color = Color(0.15, 0.15, 0.15, 0.75)
@export var fade_duration: float = 0.35

var grid_size: Vector2i = Vector2i(3, 3)
var _cells: Array[Cell] = []
var _cell_id_to_node: Dictionary = {}
var _active_cell_ids: PackedInt32Array = PackedInt32Array()
var _player_spawner: Node2D
var _center_cell: Cell
var _rest_area: Cell
var _last_phase: String = ""
var _board_active := true
var _fade_tween: Tween
var _has_rest_area_target_center := false
var _rest_area_target_center := Vector2.ZERO

func _enter_tree() -> void:
	if not _cells.is_empty():
		return
	if grid_size.x <= 0 or grid_size.y <= 0:
		push_error("grid_size must be positive.")
		return
	if grid_size.x % 2 == 0 or grid_size.y % 2 == 0:
		push_error("grid_size must have odd dimensions to determine a single center cell.")
		return
	if not cell_scene:
		push_error("cell_scene is not assigned.")
		return
	if player_spawner_path != NodePath():
		_player_spawner = get_node_or_null(player_spawner_path)
	_normalize_initial_cell_profiles()
	_spawn_cells()

func _ready() -> void:
	_connect_cell_task_runtime_signals()
	_resolve_rest_area()
	_refresh_active_cells_for_current_level(true)
	_last_phase = PhaseManager.current_state()
	if auto_assign_enemy_on_battle and not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	set_board_active(PhaseManager.current_state() == PhaseManager.BATTLE, true)
	apply_cell_effect_runtime_state(PhaseManager.current_state() == PhaseManager.PREPARE)
	call_deferred("_refresh_cell_task_markers")

func _spawn_cells() -> void:
	var center_index := Vector2i(floori(float(grid_size.x) / 2.0), floori(float(grid_size.y) / 2.0))
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := cell_scene.instantiate() as Cell
			if not cell:
				push_error("cell_scene must instantiate a Cell.")
				return
			var cell_index := _cells.size()
			if cell_index == 0:
				cell.name = "Cell"
			else:
				cell.name = "Cell%s" % str(cell_index + 1)
			cell.position = Vector2(x * cell_spacing.x, y * cell_spacing.y)
			cell.logical_id = _compute_logical_cell_id(Vector2i(x, y))
			add_child(cell)
			_configure_cell_capture_shape(cell)
			_cells.append(cell)
			_cell_id_to_node[cell.logical_id] = cell
			_apply_initial_profile(cell, cell_index)
			if Vector2i(x, y) == center_index:
				_center_cell = cell
	_build_navigation_blockers()
	if _center_cell:
		_attach_spawner(_center_cell)

func _attach_spawner(target_cell: Cell) -> void:
	if not _player_spawner:
		return
	_player_spawner.reparent(target_cell)
	_player_spawner.position = center_spawn_offset

func get_cells() -> Array[Cell]:
	return _cells.duplicate()

func get_cell_by_logical_id(logical_id: int) -> Cell:
	return _cell_id_to_node.get(logical_id) as Cell

func get_active_cell_ids() -> PackedInt32Array:
	return _active_cell_ids

func get_active_cells() -> Array[Cell]:
	var result: Array[Cell] = []
	for logical_id in _active_cell_ids:
		var cell := get_cell_by_logical_id(int(logical_id))
		if cell != null:
			result.append(cell)
	return result

func is_cell_active_by_id(logical_id: int) -> bool:
	return _active_cell_ids.has(logical_id)

func get_center_cell() -> Cell:
	return _center_cell

func get_center_cell_global_position() -> Vector2:
	if _center_cell == null:
		return global_position
	return _get_cell_center_global(_center_cell)

func get_cell_center_global_for_point(point: Vector2) -> Vector2:
	var cell := _find_cell_containing_point(point)
	if cell:
		return _get_cell_center_global(cell)
	return get_center_cell_global_position()

func get_rest_area_target_center_global_position() -> Vector2:
	if _has_rest_area_target_center:
		return _rest_area_target_center
	return get_center_cell_global_position()

func project_point_to_enemy_traversable_area(world_point: Vector2) -> Vector2:
	return project_point_to_enemy_traversable_area_with_margin(world_point, enemy_traversable_inset)

func project_point_to_enemy_traversable_area_with_margin(world_point: Vector2, margin: float = 0.0) -> Vector2:
	var active_cells := get_active_cells()
	if active_cells.is_empty():
		return world_point
	for cell in active_cells:
		if _cell_contains_point(cell, world_point):
			return _project_point_away_from_active_boundaries(cell, world_point, margin)
	return _project_point_to_nearest_cells(active_cells, world_point, margin)

func project_point_to_player_traversable_area(world_point: Vector2) -> Vector2:
	var best_point := project_point_to_enemy_traversable_area_with_margin(world_point, enemy_traversable_inset)
	var best_distance := best_point.distance_squared_to(world_point)
	if _rest_area != null:
		if _cell_contains_point(_rest_area, world_point):
			return world_point
		var projected_rest_point := _project_point_to_cell(_rest_area, world_point, enemy_traversable_inset)
		var rest_distance := projected_rest_point.distance_squared_to(world_point)
		if rest_distance < best_distance:
			best_point = projected_rest_point
	return best_point

func set_board_active(active: bool, immediate: bool = false) -> void:
	if _board_active == active and not immediate:
		return
	_board_active = active
	_set_cells_monitoring(active)
	_set_blocker_collision(active)
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	if immediate:
		visible = active
		process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
		var color := modulate
		color.a = 1.0 if active else 0.0
		modulate = color
		return
	if active:
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT
		var start_color := modulate
		start_color.a = 0.0
		modulate = start_color
		var end_color := modulate
		end_color.a = 1.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate", end_color, fade_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	else:
		var end_color := modulate
		end_color.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate", end_color, fade_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
		_fade_tween.finished.connect(func():
			visible = false
			process_mode = Node.PROCESS_MODE_DISABLED
		)

func _set_cells_monitoring(active: bool) -> void:
	for cell in _cells:
		if cell == null:
			continue
		var area: Area2D = cell.get_node_or_null("Area2D") as Area2D
		if area:
			var should_monitor := active and is_cell_active_by_id(cell.logical_id)
			area.set_deferred("monitoring", should_monitor)
			area.set_deferred("monitorable", should_monitor)

func _set_blocker_collision(active: bool) -> void:
	var blocker_root: Node = get_node_or_null("NavigationBlockers")
	if blocker_root == null:
		return
	_set_blocker_collision_recursive(blocker_root, active)

func _set_blocker_collision_recursive(node: Node, active: bool) -> void:
	for child in node.get_children():
		var body := child as StaticBody2D
		if body != null:
			var enable_collision := bool(body.get_meta("board_collision_enabled", true))
			var should_enable := active and enable_collision
			body.collision_layer = blocker_collision_layer if should_enable else 0
			body.collision_mask = blocker_collision_mask if should_enable else 0
		_set_blocker_collision_recursive(child, active)

func _build_navigation_blockers() -> void:
	var blocker_root: Node2D = get_node_or_null("NavigationBlockers") as Node2D
	if blocker_root:
		blocker_root.queue_free()
	blocker_root = Node2D.new()
	blocker_root.name = "NavigationBlockers"
	add_child(blocker_root)
	_add_corner_pillars(blocker_root)
	_add_border_walls(blocker_root)

func _add_corner_pillars(parent: Node2D) -> void:
	for y in range(grid_size.y + 1):
		for x in range(grid_size.x + 1):
			var pillar_position: Vector2 = Vector2(x * cell_spacing.x, y * cell_spacing.y)
			_add_blocker_body(parent, "CellCornerZone_%d_%d" % [x, y], pillar_position, corner_pillar_size, pillar_visual_color, false)

func _add_border_walls(parent: Node2D) -> void:
	var board_size: Vector2 = Vector2(grid_size.x * cell_spacing.x, grid_size.y * cell_spacing.y)
	var horizontal_size: Vector2 = Vector2(board_size.x, border_wall_thickness)
	var vertical_size: Vector2 = Vector2(border_wall_thickness, board_size.y)
	var half_thickness: float = border_wall_thickness * 0.5
	_add_blocker_body(parent, "WallTop", Vector2(board_size.x * 0.5, -half_thickness), horizontal_size, wall_visual_color)
	_add_blocker_body(parent, "WallBottom", Vector2(board_size.x * 0.5, board_size.y + half_thickness), horizontal_size, wall_visual_color)
	_add_blocker_body(parent, "WallLeft", Vector2(-half_thickness, board_size.y * 0.5), vertical_size, wall_visual_color)
	_add_blocker_body(parent, "WallRight", Vector2(board_size.x + half_thickness, board_size.y * 0.5), vertical_size, wall_visual_color)

func _add_blocker_body(
	parent: Node2D,
	blocker_name: String,
	blocker_position: Vector2,
	blocker_size: Vector2,
	visual_color: Color,
	enable_collision: bool = true
) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = blocker_name
	body.position = blocker_position
	body.set_meta("board_collision_enabled", enable_collision)
	body.collision_layer = blocker_collision_layer if enable_collision else 0
	body.collision_mask = blocker_collision_mask if enable_collision else 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = blocker_size
	shape.shape = rectangle
	body.add_child(shape)
	body.add_child(_create_blocker_visual(blocker_size, visual_color))
	parent.add_child(body)
	return body

func _configure_cell_capture_shape(cell: Cell) -> void:
	if cell == null:
		return
	var area: Area2D = cell.get_node_or_null("Area2D") as Area2D
	if area == null:
		return
	var collision_shape: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return
	var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return
	var polygon_node: CollisionPolygon2D = area.get_node_or_null("CapturePolygon") as CollisionPolygon2D
	if polygon_node == null:
		polygon_node = CollisionPolygon2D.new()
		polygon_node.name = "CapturePolygon"
		area.add_child(polygon_node)
	collision_shape.disabled = true
	var half_size: Vector2 = rectangle_shape.size * 0.5 * collision_shape.scale.abs()
	var center: Vector2 = collision_shape.position
	var cut_size: float = clampf(
		minf(corner_pillar_size.x, corner_pillar_size.y) * 0.5,
		1.0,
		minf(half_size.x, half_size.y) - 1.0
	)
	polygon_node.polygon = PackedVector2Array([
		center + Vector2(-half_size.x + cut_size, -half_size.y),
		center + Vector2(half_size.x - cut_size, -half_size.y),
		center + Vector2(half_size.x, -half_size.y + cut_size),
		center + Vector2(half_size.x, half_size.y - cut_size),
		center + Vector2(half_size.x - cut_size, half_size.y),
		center + Vector2(-half_size.x + cut_size, half_size.y),
		center + Vector2(-half_size.x, half_size.y - cut_size),
		center + Vector2(-half_size.x, -half_size.y + cut_size)
	])

func _create_blocker_visual(blocker_size: Vector2, visual_color: Color) -> Polygon2D:
	var polygon: Polygon2D = Polygon2D.new()
	var half_size: Vector2 = blocker_size * 0.5
	polygon.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])
	polygon.color = visual_color
	polygon.z_index = blocker_visual_z_index
	return polygon

func _apply_initial_profile(cell: Cell, cell_index: int) -> void:
	if cell == null:
		return
	if cell_index < 0 or cell_index >= initial_cell_profiles.size():
		return
	var profile := initial_cell_profiles[cell_index]
	if profile:
		cell.apply_profile(profile)

func _normalize_initial_cell_profiles() -> void:
	var expected_size := _get_expected_profile_count()
	var current_size := initial_cell_profiles.size()
	if current_size == expected_size:
		return
	initial_cell_profiles.resize(expected_size)
	push_warning(
		"initial_cell_profiles resized from %d to %d. Slot map: %s"
		% [current_size, expected_size, ", ".join(get_initial_profile_slot_labels())]
	)

func _get_expected_profile_count() -> int:
	return grid_size.x * grid_size.y

func get_initial_profile_slot_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for index in range(_get_expected_profile_count()):
		var grid_pos := _get_grid_pos_from_index(index)
		labels.append("[%d] (%d,%d)" % [index, grid_pos.x, grid_pos.y])
	return labels

func _get_grid_pos_from_index(index: int) -> Vector2i:
	if grid_size.x <= 0:
		return Vector2i.ZERO
	var x := index % grid_size.x
	var y := floori(float(index) / float(grid_size.x))
	return Vector2i(x, y)

func _on_phase_changed(new_phase: String) -> void:
	var entered_prepare_from_battle := new_phase != PhaseManager.BATTLE and _last_phase == PhaseManager.BATTLE
	if entered_prepare_from_battle:
		_capture_rest_area_target_from_player_cell()
	elif new_phase != PhaseManager.BATTLE:
		_clear_rest_area_target_center()
	_refresh_active_cells_for_current_level()
	if new_phase == PhaseManager.BATTLE:
		apply_cell_effect_runtime_state(false)
		if _last_phase == PhaseManager.PREPARE:
			recenter_board_around_player()
		set_board_active(true)
		_unlock_defense_cells_for_battle()
	else:
		apply_cell_effect_runtime_state(true)
		if _last_phase == PhaseManager.BATTLE:
			_reset_cells_after_battle()
		set_board_active(false)
	# On battle -> prepare, RestArea will place player at center explicitly.
	# Skipping board projection here avoids an intermediate jump to rest-area edge.
	if not entered_prepare_from_battle:
		_enforce_traversable_bounds_for_existing_units()
	_last_phase = new_phase
	call_deferred("_refresh_cell_task_markers")

func _capture_rest_area_target_from_player_cell() -> void:
	_clear_rest_area_target_center()
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	var player_cell := _find_any_cell_containing_point(PlayerData.player.global_position)
	if player_cell == null:
		return
	_rest_area_target_center = _get_cell_center_global(player_cell)
	_has_rest_area_target_center = true

func _clear_rest_area_target_center() -> void:
	_has_rest_area_target_center = false
	_rest_area_target_center = Vector2.ZERO

func recenter_board_around_player() -> void:
	if _center_cell == null:
		return
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	var board_position_before: Vector2 = global_position
	var player_position: Vector2 = PlayerData.player.global_position
	var player_cell := _find_cell_containing_point(player_position)
	if player_cell == null:
		return
	var center_cell_position: Vector2 = _get_cell_center_global(_center_cell)
	var recenter_offset: Vector2 = player_position - center_cell_position
	if recenter_offset == Vector2.ZERO:
		_log_recenter_debug(board_position_before, global_position, player_position, PlayerData.player.global_position, recenter_offset, 0.0)
		return
	global_position += recenter_offset
	var board_position_after: Vector2 = global_position
	var player_position_after: Vector2 = PlayerData.player.global_position
	var center_after: Vector2 = _get_cell_center_global(_center_cell)
	var center_player_distance: float = center_after.distance_to(player_position_after)
	_log_recenter_debug(board_position_before, board_position_after, player_position, player_position_after, recenter_offset, center_player_distance)
	_offset_scene_npcs_and_start_buttons(recenter_offset)

func _unlock_defense_cells_for_battle() -> void:
	for cell in _cells:
		if not cell:
			continue
		if not is_cell_active_by_id(cell.logical_id):
			cell.progress = 0
			cell.set_locked(true)
			continue
		cell.progress = 0
		var has_runtime_task := CellTaskModuleRuntime.has_active_task_for_cell(cell.logical_id)
		if has_runtime_task or cell.task_type == Cell.TaskType.OFFENSE or cell.task_type == Cell.TaskType.DEFENSE or cell.task_type == Cell.TaskType.CLEAR or cell.task_type == Cell.TaskType.HUNT or cell.task_type == Cell.TaskType.DODGE:
			cell.set_locked(false)
		else:
			cell.set_locked(true)

func _reset_cells_after_battle() -> void:
	for cell in _cells:
		if not cell:
			continue
		cell.progress = 0
		cell.set_locked(true)

func _find_cell_containing_point(point: Vector2) -> Cell:
	for cell in get_active_cells():
		if cell == null:
			continue
		if _cell_contains_point(cell, point):
			return cell
	return null

func _find_any_cell_containing_point(point: Vector2) -> Cell:
	for cell in _cells:
		if cell == null:
			continue
		if _cell_contains_point(cell, point):
			return cell
	return null

func _compute_logical_cell_id(grid_pos: Vector2i) -> int:
	# 3x3 mapping from top-left to bottom-right:
	# 7,8,9
	# 4,5,6
	# 1,2,3
	return (grid_size.y - grid_pos.y - 1) * grid_size.x + grid_pos.x + 1

func _get_active_cell_ids_for_level(level_one_based: int) -> PackedInt32Array:
	if level_one_based <= 2:
		return PackedInt32Array([5, 6])
	if level_one_based <= 4:
		return PackedInt32Array([4, 5, 6])
	if level_one_based <= 6:
		return PackedInt32Array([4, 5, 6, 8])
	if level_one_based <= 8:
		return PackedInt32Array([2, 4, 5, 6, 8])
	var all_ids := PackedInt32Array()
	for i in range(1, grid_size.x * grid_size.y + 1):
		all_ids.append(i)
	return all_ids

func apply_cell_effect_runtime_state(include_pending_preview: bool = true) -> void:
	for cell in _cells:
		if cell == null:
			continue
		var effect_id := CellEffectRuntime.get_effect_for_cell(cell.logical_id, include_pending_preview)
		if effect_id.strip_edges() == "":
			cell.restore_profile_terrain_effect()
			continue
		var definition := CellEffectRuntime.get_definition(effect_id)
		if definition == null:
			cell.restore_profile_terrain_effect()
			continue
		var preview_only := include_pending_preview and CellEffectRuntime.get_pending_snapshot().has(str(cell.logical_id))
		cell.apply_runtime_cell_effect(definition, preview_only)

func apply_task_module_runtime_state() -> void:
	for cell in _cells:
		if cell == null:
			continue
		var definition := CellTaskModuleRuntime.get_active_task_definition(cell.logical_id)
		if definition != null:
			cell.apply_runtime_task_module(definition)
			_connect_cell_objective_status_signal(cell)
		else:
			cell.restore_profile_task_module()
	call_deferred("_refresh_cell_task_markers")

func _refresh_active_cells_for_current_level(force: bool = false) -> void:
	var level_one_based := maxi(PhaseManager.current_level + 1, 1)
	var target_ids := _get_active_cell_ids_for_level(level_one_based)
	if not force and target_ids == _active_cell_ids:
		return
	_active_cell_ids = target_ids
	_apply_active_cell_flags()
	active_cells_changed.emit(_active_cell_ids)

func _apply_active_cell_flags() -> void:
	for cell in _cells:
		if cell == null:
			continue
		var is_active := is_cell_active_by_id(cell.logical_id)
		cell.set_board_enabled(is_active)
		if not is_active:
			cell.set_locked(true)
	_refresh_active_cell_boundaries()
	_refresh_active_boundary_blockers()
	_set_cells_monitoring(_board_active)
	_set_blocker_collision(_board_active)
	call_deferred("_refresh_cell_task_markers")

func _refresh_active_boundary_blockers() -> void:
	var blocker_root := get_node_or_null("NavigationBlockers") as Node2D
	if blocker_root == null:
		return
	_clear_active_boundary_blockers(blocker_root)
	for cell in _cells:
		if cell == null or not is_cell_active_by_id(cell.logical_id):
			continue
		var grid_pos := _get_grid_pos_for_logical_id(cell.logical_id)
		var edges := _get_inactive_neighbor_edges(cell.logical_id)
		for edge in edges:
			_add_active_boundary_blocker(blocker_root, grid_pos, String(edge))

func _clear_active_boundary_blockers(blocker_root: Node2D) -> void:
	for child in blocker_root.get_children().duplicate():
		var body := child as StaticBody2D
		if body == null:
			continue
		if bool(body.get_meta("active_boundary_blocker", false)):
			blocker_root.remove_child(body)
			body.queue_free()

func _add_active_boundary_blocker(blocker_root: Node2D, grid_pos: Vector2i, edge: String) -> void:
	var cell_origin := Vector2(grid_pos.x * cell_spacing.x, grid_pos.y * cell_spacing.y)
	var cell_size := _get_cell_capture_size()
	var thickness := maxf(internal_boundary_wall_thickness, 1.0)
	var half_thickness := thickness * 0.5
	var blocker_position := Vector2.ZERO
	var blocker_size := Vector2.ZERO
	match edge:
		"top":
			blocker_position = cell_origin + Vector2(cell_size.x * 0.5, half_thickness)
			blocker_size = Vector2(cell_size.x, thickness)
		"right":
			blocker_position = cell_origin + Vector2(cell_size.x - half_thickness, cell_size.y * 0.5)
			blocker_size = Vector2(thickness, cell_size.y)
		"bottom":
			blocker_position = cell_origin + Vector2(cell_size.x * 0.5, cell_size.y - half_thickness)
			blocker_size = Vector2(cell_size.x, thickness)
		"left":
			blocker_position = cell_origin + Vector2(half_thickness, cell_size.y * 0.5)
			blocker_size = Vector2(thickness, cell_size.y)
		_:
			return
	var body := _add_blocker_body(
		blocker_root,
		"ActiveBoundaryWall_%d_%d_%s" % [grid_pos.x, grid_pos.y, edge],
		blocker_position,
		blocker_size,
		Color(wall_visual_color.r, wall_visual_color.g, wall_visual_color.b, 0.0),
		true
	)
	body.set_meta("active_boundary_blocker", true)

func _get_cell_capture_size() -> Vector2:
	return Vector2(cell_spacing.x, cell_spacing.y)

func _refresh_active_cell_boundaries() -> void:
	for cell in _cells:
		if cell == null:
			continue
		if not cell.board_enabled:
			cell.set_active_boundary_edges(PackedStringArray())
			continue
		cell.set_active_boundary_edges(_get_inactive_neighbor_edges(cell.logical_id))

func _get_inactive_neighbor_edges(logical_id: int) -> PackedStringArray:
	var edges := PackedStringArray()
	var grid_pos := _get_grid_pos_for_logical_id(logical_id)
	var neighbors := [
		{"edge": "top", "position": grid_pos + Vector2i(0, -1)},
		{"edge": "right", "position": grid_pos + Vector2i(1, 0)},
		{"edge": "bottom", "position": grid_pos + Vector2i(0, 1)},
		{"edge": "left", "position": grid_pos + Vector2i(-1, 0)}
	]
	for neighbor in neighbors:
		var neighbor_pos := neighbor["position"] as Vector2i
		if neighbor_pos.x < 0 or neighbor_pos.y < 0 or neighbor_pos.x >= grid_size.x or neighbor_pos.y >= grid_size.y:
			continue
		var neighbor_id := _compute_logical_cell_id(neighbor_pos)
		if not is_cell_active_by_id(neighbor_id):
			edges.append(str(neighbor["edge"]))
	return edges

func _get_grid_pos_for_logical_id(logical_id: int) -> Vector2i:
	var zero_based := logical_id - 1
	if zero_based < 0:
		return Vector2i.ZERO
	var x := zero_based % grid_size.x
	var y_from_bottom := floori(float(zero_based) / float(grid_size.x))
	return Vector2i(x, grid_size.y - y_from_bottom - 1)

func _connect_cell_task_runtime_signals() -> void:
	var active_callback := Callable(self, "_on_cell_task_runtime_changed")
	var completed_callback := Callable(self, "_on_cell_task_runtime_changed")
	var status_callback := Callable(self, "_on_cell_task_status_changed")
	if not CellTaskModuleRuntime.active_tasks_changed.is_connected(active_callback):
		CellTaskModuleRuntime.active_tasks_changed.connect(active_callback)
	if not CellTaskModuleRuntime.completed_tasks_changed.is_connected(completed_callback):
		CellTaskModuleRuntime.completed_tasks_changed.connect(completed_callback)
	if CellTaskModuleRuntime.has_signal("active_task_status_changed") and not CellTaskModuleRuntime.active_task_status_changed.is_connected(status_callback):
		CellTaskModuleRuntime.active_task_status_changed.connect(status_callback)

func _on_cell_task_runtime_changed() -> void:
	call_deferred("_refresh_cell_task_markers")

func _on_cell_task_status_changed(_cell_id: int) -> void:
	call_deferred("_refresh_cell_task_markers")

func _connect_cell_objective_status_signal(cell: Cell) -> void:
	if cell == null:
		return
	var module_root := cell.get_node_or_null("Modules")
	if module_root == null:
		return
	var callback := Callable(self, "_on_objective_task_status_changed")
	for child in module_root.get_children():
		if child is CellObjectiveModule and child.has_signal("task_status_changed"):
			if not child.is_connected("task_status_changed", callback):
				child.connect("task_status_changed", callback)

func _on_objective_task_status_changed(cell_id: int) -> void:
	if CellTaskModuleRuntime.has_method("notify_active_task_status_changed"):
		CellTaskModuleRuntime.call("notify_active_task_status_changed", cell_id)
	else:
		call_deferred("_refresh_cell_task_markers")

func _refresh_cell_task_markers() -> void:
	var statuses := _collect_active_task_statuses()
	for cell in _cells:
		if cell == null:
			continue
		var cell_key := str(cell.logical_id)
		if statuses.has(cell_key):
			cell.set_task_marker_status(statuses[cell_key] as Dictionary)
		else:
			cell.clear_task_marker_status()

func _collect_active_task_statuses() -> Dictionary:
	if CellTaskModuleRuntime.has_method("get_active_task_statuses"):
		var runtime_statuses: Variant = CellTaskModuleRuntime.call("get_active_task_statuses", self)
		var normalized := _normalize_task_status_collection(runtime_statuses)
		if not normalized.is_empty():
			return normalized
	return _build_active_task_statuses_from_runtime_snapshots()

func _normalize_task_status_collection(runtime_statuses: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if runtime_statuses is Dictionary:
		for key in (runtime_statuses as Dictionary).keys():
			var value: Variant = (runtime_statuses as Dictionary)[key]
			if value is Dictionary:
				var status := (value as Dictionary).duplicate(true)
				var cell_id := int(status.get("cell_id", int(str(key))))
				if cell_id > 0:
					normalized[str(cell_id)] = status
	elif runtime_statuses is Array:
		for value in runtime_statuses:
			if value is Dictionary:
				var status := (value as Dictionary).duplicate(true)
				var cell_id := int(status.get("cell_id", 0))
				if cell_id > 0:
					normalized[str(cell_id)] = status
	return normalized

func _build_active_task_statuses_from_runtime_snapshots() -> Dictionary:
	var statuses: Dictionary = {}
	var active_snapshot := CellTaskModuleRuntime.get_active_tasks_snapshot()
	var completed_snapshot := CellTaskModuleRuntime.get_completed_cells_snapshot()
	for cell_key in active_snapshot.keys():
		var cell_id := int(str(cell_key))
		if cell_id <= 0:
			continue
		var cell := get_cell_by_logical_id(cell_id)
		if cell == null or not cell.board_enabled:
			continue
		var status := cell.get_active_task_marker_status()
		if status.is_empty():
			status = _build_definition_task_marker_status(cell_id)
		if completed_snapshot.has(str(cell_id)):
			status["state"] = "complete"
			status["progress"] = 1.0
			status["value_text"] = "完成"
		statuses[str(cell_id)] = status
	return statuses

func _build_definition_task_marker_status(cell_id: int) -> Dictionary:
	var definition := CellTaskModuleRuntime.get_active_task_definition(cell_id)
	if definition == null:
		return {}
	var icon_key := _task_type_to_marker_key(definition.task_type)
	return {
		"cell_id": cell_id,
		"module_id": definition.module_id,
		"type": icon_key,
		"icon_key": icon_key,
		"label": _marker_key_to_label(icon_key),
		"progress": 0.0,
		"value_text": _default_marker_value_text(icon_key),
		"state": "waiting"
	}

func _task_type_to_marker_key(task_type: int) -> String:
	match task_type:
		Cell.TaskType.OFFENSE:
			return "kill"
		Cell.TaskType.DEFENSE:
			return "hold"
		Cell.TaskType.CLEAR:
			return "clear"
		Cell.TaskType.HUNT:
			return "hunt"
		Cell.TaskType.DODGE:
			return "dodge"
		_:
			return "fallback"

func _marker_key_to_label(marker_key: String) -> String:
	match marker_key:
		"kill":
			return "击杀"
		"hold":
			return "守点"
		"clear":
			return "清场"
		"hunt":
			return "精英"
		"dodge":
			return "闪避"
		_:
			return "任务"

func _default_marker_value_text(marker_key: String) -> String:
	match marker_key:
		"hold":
			return "0/100%"
		"dodge":
			return "0/1秒"
		_:
			return "0/1"

func _resolve_rest_area() -> void:
	if is_inside_tree():
		var rest_nodes := get_tree().get_nodes_in_group("rest_area")
		for node in rest_nodes:
			if node is Cell:
				_rest_area = node as Cell
				return

func _project_point_to_nearest_cells(cells: Array[Cell], world_point: Vector2, margin: float = 0.0) -> Vector2:
	if cells.is_empty():
		return world_point
	var best_point := world_point
	var best_distance := INF
	for cell in cells:
		if cell == null:
			continue
		var projected := _project_point_to_cell(cell, world_point, margin)
		var sqr_distance := projected.distance_squared_to(world_point)
		if sqr_distance < best_distance:
			best_distance = sqr_distance
			best_point = projected
	return best_point

func _project_point_to_cell(cell: Cell, world_point: Vector2, margin: float = 0.0) -> Vector2:
	if cell == null:
		return world_point
	var capture_polygon: CollisionPolygon2D = cell.get_node_or_null("Area2D/CapturePolygon")
	if capture_polygon and not capture_polygon.polygon.is_empty():
		var projected_polygon_point := _project_point_into_capture_polygon(capture_polygon, world_point)
		return _push_point_inside_cell(cell, projected_polygon_point, margin)
	var collision_shape: CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		var half_size := rectangle.size * 0.5 * collision_shape.scale.abs()
		var clamped_margin := maxf(0.0, margin)
		half_size.x = maxf(half_size.x - clamped_margin, 1.0)
		half_size.y = maxf(half_size.y - clamped_margin, 1.0)
		var local_point := collision_shape.global_transform.affine_inverse() * world_point
		local_point.x = clampf(local_point.x, -half_size.x, half_size.x)
		local_point.y = clampf(local_point.y, -half_size.y, half_size.y)
		return collision_shape.global_transform * local_point
	return _push_point_inside_cell(cell, _get_cell_center_global(cell), margin)

func _project_point_away_from_active_boundaries(cell: Cell, world_point: Vector2, margin: float) -> Vector2:
	if cell == null:
		return world_point
	var boundary_edges := _get_enemy_traversable_boundary_edges(cell.logical_id)
	if boundary_edges.is_empty():
		return world_point
	var safe_margin := _get_active_boundary_safe_margin(margin)
	if safe_margin <= 0.001:
		return world_point
	var capture_polygon: CollisionPolygon2D = cell.get_node_or_null("Area2D/CapturePolygon")
	if capture_polygon and not capture_polygon.polygon.is_empty():
		return _project_polygon_point_away_from_edges(cell, capture_polygon, world_point, boundary_edges, safe_margin)
	var collision_shape: CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		return _project_rect_point_away_from_edges(cell, collision_shape, world_point, boundary_edges, safe_margin)
	return world_point

func _get_active_boundary_safe_margin(margin: float) -> float:
	var wall_clearance := maxf(internal_boundary_wall_thickness, 0.0) + maxf(enemy_traversable_inset, 0.0)
	return maxf(maxf(margin, 0.0), wall_clearance)

func _get_enemy_traversable_boundary_edges(logical_id: int) -> PackedStringArray:
	var edges := PackedStringArray()
	var grid_pos := _get_grid_pos_for_logical_id(logical_id)
	var neighbors := [
		{"edge": "top", "position": grid_pos + Vector2i(0, -1)},
		{"edge": "right", "position": grid_pos + Vector2i(1, 0)},
		{"edge": "bottom", "position": grid_pos + Vector2i(0, 1)},
		{"edge": "left", "position": grid_pos + Vector2i(-1, 0)}
	]
	for neighbor in neighbors:
		var neighbor_pos := neighbor["position"] as Vector2i
		var edge := str(neighbor["edge"])
		if neighbor_pos.x < 0 or neighbor_pos.y < 0 or neighbor_pos.x >= grid_size.x or neighbor_pos.y >= grid_size.y:
			edges.append(edge)
			continue
		var neighbor_id := _compute_logical_cell_id(neighbor_pos)
		if not is_cell_active_by_id(neighbor_id):
			edges.append(edge)
	return edges

func _project_polygon_point_away_from_edges(
	cell: Cell,
	capture_polygon: CollisionPolygon2D,
	world_point: Vector2,
	boundary_edges: PackedStringArray,
	safe_margin: float
) -> Vector2:
	var local_aabb := _get_polygon_local_aabb(capture_polygon.polygon)
	if local_aabb.size == Vector2.ZERO:
		return world_point
	var local_point: Vector2 = capture_polygon.global_transform.affine_inverse() * world_point
	var adjusted_point := _clamp_local_point_away_from_edges(local_point, local_aabb, boundary_edges, safe_margin)
	if adjusted_point.distance_squared_to(local_point) <= 0.0001:
		return world_point
	var adjusted_world: Vector2 = capture_polygon.global_transform * adjusted_point
	if _cell_contains_point(cell, adjusted_world):
		return adjusted_world
	return _push_point_inside_cell(cell, _project_point_into_capture_polygon(capture_polygon, adjusted_world), 0.0)

func _project_rect_point_away_from_edges(
	cell: Cell,
	collision_shape: CollisionShape2D,
	world_point: Vector2,
	boundary_edges: PackedStringArray,
	safe_margin: float
) -> Vector2:
	var rectangle := collision_shape.shape as RectangleShape2D
	var half_size := rectangle.size * 0.5 * collision_shape.scale.abs()
	var local_aabb := Rect2(-half_size, half_size * 2.0)
	var local_point := collision_shape.global_transform.affine_inverse() * world_point
	var adjusted_point := _clamp_local_point_away_from_edges(local_point, local_aabb, boundary_edges, safe_margin)
	if adjusted_point.distance_squared_to(local_point) <= 0.0001:
		return world_point
	var adjusted_world: Vector2 = collision_shape.global_transform * adjusted_point
	if _cell_contains_point(cell, adjusted_world):
		return adjusted_world
	return _push_point_inside_cell(cell, adjusted_world, 0.0)

func _clamp_local_point_away_from_edges(
	local_point: Vector2,
	local_aabb: Rect2,
	boundary_edges: PackedStringArray,
	safe_margin: float
) -> Vector2:
	var adjusted_point := local_point
	var x_margin := minf(safe_margin, maxf(local_aabb.size.x * 0.5 - 1.0, 0.0))
	var y_margin := minf(safe_margin, maxf(local_aabb.size.y * 0.5 - 1.0, 0.0))
	if boundary_edges.has("left"):
		adjusted_point.x = maxf(adjusted_point.x, local_aabb.position.x + x_margin)
	if boundary_edges.has("right"):
		adjusted_point.x = minf(adjusted_point.x, local_aabb.end.x - x_margin)
	if boundary_edges.has("top"):
		adjusted_point.y = maxf(adjusted_point.y, local_aabb.position.y + y_margin)
	if boundary_edges.has("bottom"):
		adjusted_point.y = minf(adjusted_point.y, local_aabb.end.y - y_margin)
	return adjusted_point

func _project_point_into_capture_polygon(capture_polygon: CollisionPolygon2D, world_point: Vector2) -> Vector2:
	if capture_polygon == null or capture_polygon.polygon.is_empty():
		return world_point
	var local_point: Vector2 = capture_polygon.global_transform.affine_inverse() * world_point
	if Geometry2D.is_point_in_polygon(local_point, capture_polygon.polygon):
		return world_point
	var local_aabb: Rect2 = _get_polygon_local_aabb(capture_polygon.polygon)
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

func _push_point_inside_cell(cell: Cell, world_point: Vector2, margin: float) -> Vector2:
	var clamped_margin := maxf(margin, 0.0)
	if clamped_margin <= 0.001 or cell == null:
		return world_point
	var cell_center := _get_cell_center_global(cell)
	if world_point.distance_squared_to(cell_center) <= 0.0001:
		return world_point
	var candidate := world_point.move_toward(cell_center, clamped_margin)
	if _cell_contains_point(cell, candidate):
		return candidate
	return world_point

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

func _enforce_traversable_bounds_for_existing_units() -> void:
	if PlayerData.player and is_instance_valid(PlayerData.player):
		PlayerData.player.global_position = project_point_to_player_traversable_area(PlayerData.player.global_position)
	for enemy_2d in _get_registered_enemies():
		if enemy_2d == null or not is_instance_valid(enemy_2d):
			continue
		enemy_2d.global_position = project_point_to_enemy_traversable_area(enemy_2d.global_position)

func _get_registered_enemies() -> Array[Node2D]:
	var output: Array[Node2D] = []
	var registry := get_node_or_null("/root/EnemyRegistry")
	if registry != null and registry.has_method("get_enemies"):
		var registered_enemies: Variant = registry.call("get_enemies")
		if registered_enemies is Array:
			for enemy_ref in registered_enemies:
				var enemy := enemy_ref as Node2D
				if enemy != null and is_instance_valid(enemy):
					output.append(enemy)
			return output
	for enemy_ref in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_ref as Node2D
		if enemy != null and is_instance_valid(enemy):
			output.append(enemy)
	return output

func _cell_contains_point(cell: Cell, point: Vector2) -> bool:
	var capture_polygon: CollisionPolygon2D = cell.get_node_or_null("Area2D/CapturePolygon")
	if capture_polygon and not capture_polygon.polygon.is_empty():
		var local_point := capture_polygon.global_transform.affine_inverse() * point
		return Geometry2D.is_point_in_polygon(local_point, capture_polygon.polygon)
	var collision_shape: CollisionShape2D = cell.get_node_or_null("Area2D/CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		var half_size := rectangle.size * 0.5 * collision_shape.scale.abs()
		var local_point := collision_shape.global_transform.affine_inverse() * point
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y
	return false

func _get_cell_center_global(cell: Cell) -> Vector2:
	if cell == null:
		return Vector2.ZERO
	var capture_polygon: CollisionPolygon2D = cell.get_node_or_null("Area2D/CapturePolygon")
	if capture_polygon and not capture_polygon.polygon.is_empty():
		var local_sum := Vector2.ZERO
		for p in capture_polygon.polygon:
			local_sum += p
		var centroid_local := local_sum / float(capture_polygon.polygon.size())
		return capture_polygon.global_transform * centroid_local
	return cell.global_position

func _offset_scene_npcs_and_start_buttons(offset: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("npc"):
		var node_2d := node as Node2D
		if node_2d == null:
			continue
		if _is_node_inside_board(node_2d):
			continue
		if _is_node_inside_group(node_2d, &"rest_area"):
			continue
		node_2d.global_position += offset
	var scene_root := tree.current_scene
	if scene_root == null:
		return
	for start_button in _find_start_battle_buttons(scene_root):
		if start_button == null:
			continue
		if _is_node_inside_board(start_button):
			continue
		if _is_node_inside_group(start_button, &"rest_area"):
			continue
		start_button.global_position += offset

func _find_start_battle_buttons(root: Node) -> Array[StartBattleButton]:
	var result: Array[StartBattleButton] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back() as Node
		if current == null:
			continue
		var battle_button := current as StartBattleButton
		if battle_button:
			result.append(battle_button)
		for child in current.get_children():
			pending.append(child)
	return result

func _is_node_inside_board(node: Node) -> bool:
	if node == null:
		return false
	var current: Node = node
	while current:
		if current == self:
			return true
		current = current.get_parent()
	return false

func _is_node_inside_group(node: Node, group_name: StringName) -> bool:
	if node == null:
		return false
	var current: Node = node
	while current:
		if current.is_in_group(group_name):
			return true
		current = current.get_parent()
	return false

func _log_recenter_debug(
	board_before: Vector2,
	board_after: Vector2,
	player_before: Vector2,
	player_after: Vector2,
	offset: Vector2,
	center_player_distance: float
) -> void:
	if not debug_recenter_logs:
		return
	print(
		"[BoardRecenter] board_before=%s board_after=%s player_before=%s player_after=%s offset=%s center_player_distance=%.4f"
		% [str(board_before), str(board_after), str(player_before), str(player_after), str(offset), center_player_distance]
	)
