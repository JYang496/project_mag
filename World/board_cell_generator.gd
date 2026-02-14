extends Node2D
class_name BoardCellGenerator

@export var cell_scene: PackedScene
@export var grid_size: Vector2i = Vector2i(3, 3)
@export var cell_spacing: Vector2 = Vector2(510, 510)
@export var player_spawner_path: NodePath
@export var center_spawn_offset: Vector2 = Vector2(255, 258)
@export var auto_assign_enemy_on_battle := true

var _cells: Array[Cell] = []
var _player_spawner: Node2D
var _center_cell: Cell

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

func _on_phase_changed(new_phase: String) -> void:
	if new_phase == PhaseManager.BATTLE:
		_assign_enemy_cells()
	elif new_phase == PhaseManager.REWARD:
		_reset_cell_ownership()

func _assign_enemy_cells() -> void:
	var neutral_cells: Array[Cell] = []
	for cell in _cells:
		if cell and cell.state == Cell.CellState.IDLE:
			neutral_cells.append(cell)
	if neutral_cells.is_empty():
		return
	neutral_cells.shuffle()
	var cells_to_convert := neutral_cells.size() / 2
	for i in range(cells_to_convert):
		var cell := neutral_cells[i]
		cell.state = Cell.CellState.ENEMY
		cell.progress = -Cell.CAPTURE_THRESHOLD
		cell.cell_owner = Cell.CellOwner.ENEMY

func _reset_cell_ownership() -> void:
	for cell in _cells:
		if not cell:
			continue
		cell.progress = 0
		cell.state = Cell.CellState.IDLE
		cell.cell_owner = Cell.CellOwner.NONE
