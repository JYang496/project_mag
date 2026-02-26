extends Node2D
class_name BoardCellGenerator

@export var cell_scene: PackedScene
@export var grid_size: Vector2i = Vector2i(3, 3)
@export var cell_spacing: Vector2 = Vector2(510, 510)
@export var player_spawner_path: NodePath
@export var center_spawn_offset: Vector2 = Vector2(255, 258)
@export var auto_assign_enemy_on_battle := true
@export var initial_cell_profiles: Array[CellProfile] = []

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
			_cells.append(cell)
			_apply_initial_profile(cell, cell_index)
			if Vector2i(x, y) == center_index:
				_center_cell = cell
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

func _apply_initial_profile(cell: Cell, cell_index: int) -> void:
	if cell == null:
		return
	if cell_index < 0 or cell_index >= initial_cell_profiles.size():
		return
	var profile := initial_cell_profiles[cell_index]
	if profile:
		cell.apply_profile(profile)

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.BATTLE:
		_unlock_defense_cells_for_battle()
	elif _last_phase == PhaseManager.BATTLE and new_phase != PhaseManager.BATTLE:
		_reset_cell_ownership()
	_last_phase = new_phase

func _unlock_defense_cells_for_battle() -> void:
	for cell in _cells:
		if not cell:
			continue
		cell.progress = 0
		cell.cell_owner = Cell.CellOwner.NONE
		if cell.task_type == Cell.TaskType.DEFENSE:
			cell.set_locked(false)
		else:
			cell.set_locked(true)

func _reset_cell_ownership() -> void:
	for cell in _cells:
		if not cell:
			continue
		cell.progress = 0
		cell.set_locked(true)
		cell.cell_owner = Cell.CellOwner.NONE
