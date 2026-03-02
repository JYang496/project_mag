extends Node2D
class_name BoardCellGenerator

@export var cell_scene: PackedScene
@export var cell_spacing: Vector2 = Vector2(510, 510)
@export var player_spawner_path: NodePath
@export var center_spawn_offset: Vector2 = Vector2(255, 258)
@export var auto_assign_enemy_on_battle := true
@export var initial_cell_profiles: Array[CellProfile] = []
@export_group("Board Blockers")
@export var blocker_collision_layer: int = 32
@export var blocker_collision_mask: int = 0
@export var corner_pillar_size: Vector2 = Vector2(48, 48)
@export var border_wall_thickness: float = 48.0
@export_group("Blocker Visuals")
@export var blocker_visual_z_index: int = 5
@export var pillar_visual_color: Color = Color(0.20, 0.20, 0.20, 0.85)
@export var wall_visual_color: Color = Color(0.15, 0.15, 0.15, 0.75)

var grid_size: Vector2i = Vector2i(3, 3)
var _cells: Array[Cell] = []
var _player_spawner: Node2D
var _center_cell: Cell
var _last_phase: String = ""

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
	_last_phase = PhaseManager.current_state()
	if auto_assign_enemy_on_battle and not PhaseManager.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		PhaseManager.connect("phase_changed", Callable(self, "_on_phase_changed"))

func _spawn_cells() -> void:
	var center_index := Vector2i(grid_size.x / 2, grid_size.y / 2)
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
			add_child(cell)
			_configure_cell_capture_shape(cell)
			_cells.append(cell)
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

func get_center_cell() -> Cell:
	return _center_cell

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
	_add_blocker_body(parent, "WallTop", Vector2(board_size.x * 0.5, 0.0), horizontal_size, wall_visual_color)
	_add_blocker_body(parent, "WallBottom", Vector2(board_size.x * 0.5, board_size.y), horizontal_size, wall_visual_color)
	_add_blocker_body(parent, "WallLeft", Vector2(0.0, board_size.y * 0.5), vertical_size, wall_visual_color)
	_add_blocker_body(parent, "WallRight", Vector2(board_size.x, board_size.y * 0.5), vertical_size, wall_visual_color)

func _add_blocker_body(
	parent: Node2D,
	blocker_name: String,
	blocker_position: Vector2,
	blocker_size: Vector2,
	visual_color: Color,
	enable_collision: bool = true
) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = blocker_name
	body.position = blocker_position
	body.collision_layer = blocker_collision_layer if enable_collision else 0
	body.collision_mask = blocker_collision_mask if enable_collision else 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = blocker_size
	shape.shape = rectangle
	body.add_child(shape)
	body.add_child(_create_blocker_visual(blocker_size, visual_color))
	parent.add_child(body)

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
	var y := int(index / grid_size.x)
	return Vector2i(x, y)

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.BATTLE:
		_unlock_defense_cells_for_battle()
	elif _last_phase == PhaseManager.BATTLE and new_phase != PhaseManager.BATTLE:
		_reset_cells_after_battle()
	_last_phase = new_phase

func _unlock_defense_cells_for_battle() -> void:
	for cell in _cells:
		if not cell:
			continue
		cell.progress = 0
		if cell.task_type == Cell.TaskType.DEFENSE:
			cell.set_locked(false)
		else:
			cell.set_locked(true)

func _reset_cells_after_battle() -> void:
	for cell in _cells:
		if not cell:
			continue
		cell.progress = 0
		cell.set_locked(true)
