extends Node

const CellScene := preload("res://Board/Cells/cell.tscn")
const EnemyScene := preload("res://Npc/enemy/scenes/base_enemy.tscn")

var _failed := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var board := BoardCellGenerator.new()
	board.name = "Board"
	board.cell_scene = CellScene
	board.auto_assign_enemy_on_battle = false
	add_child(board)
	var enemy := EnemyScene.instantiate() as BaseEnemy
	enemy.global_position = board.get_center_cell_global_position()
	add_child(enemy)
	enemy.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var initial := enemy.get_board_constraint_debug_metrics()
	_expect(int(initial.get("full_refreshes", -1)) == 1, "initial cache should require exactly one full projection")
	_expect(int(initial.get("fast_accepts", 0)) >= 1, "stable enemy position should use the fast rectangle path")
	var refreshes_before := int(initial.get("full_refreshes", 0))
	enemy.global_position += Vector2(4.0, 4.0)
	await get_tree().physics_frame
	var after_small_move := enemy.get_board_constraint_debug_metrics()
	_expect(int(after_small_move.get("full_refreshes", -1)) == refreshes_before, "movement inside the cached safe rectangle triggered a full projection")
	board.active_cells_changed.emit(board.get_active_cell_ids())
	await get_tree().physics_frame
	var after_invalidate := enemy.get_board_constraint_debug_metrics()
	_expect(int(after_invalidate.get("full_refreshes", -1)) == refreshes_before + 1, "board change did not invalidate the enemy cache")
	enemy.global_position += Vector2(10000.0, 10000.0)
	await get_tree().physics_frame
	var after_escape := enemy.get_board_constraint_debug_metrics()
	_expect(int(after_escape.get("full_refreshes", -1)) == refreshes_before + 2, "leaving the safe rectangle did not trigger exact projection")
	_expect(bool(after_escape.get("cache_valid", false)), "escaped enemy was not restored to a cacheable traversable cell")
	if _failed:
		push_error("FAIL: enemy board constraint cache")
		get_tree().quit(1)
		return
	print("PASS: enemy board constraint uses fast cached rectangles and exact invalidation fallback")
	get_tree().quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)
