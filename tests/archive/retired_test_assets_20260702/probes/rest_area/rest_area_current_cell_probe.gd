extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_scene := load("res://World/world.tscn") as PackedScene
	if world_scene == null:
		_fail("world scene missing")
		return
	var world := world_scene.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var board := world.get_node_or_null("Board") as BoardCellGenerator
	var rest_area := world.get_node_or_null("RestArea") as RestArea
	if board == null or rest_area == null:
		_fail("board/rest_area missing")
		return
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player):
		_fail("player missing")
		return
	PhaseManager.enter_battle()
	await get_tree().process_frame
	var target_cell := board.get_cell_by_logical_id(6)
	if target_cell == null:
		_fail("target cell 6 missing")
		return
	var battle_end_position := _get_cell_center_global(target_cell)
	player.global_position = battle_end_position
	await get_tree().process_frame
	PhaseManager.enter_prepare()
	await get_tree().process_frame
	await get_tree().process_frame
	var rest_spawn_position := rest_area.get_spawn_position()
	var distance_to_battle_end := rest_spawn_position.distance_to(battle_end_position)
	if distance_to_battle_end > 1.0:
		_fail("rest area target drifted: distance=%.3f rest=%s battle_end=%s" % [
			distance_to_battle_end,
			str(rest_spawn_position),
			str(battle_end_position)
		])
		return
	print("PASS: rest area follows battle-end player cell")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	get_tree().quit(1)

func _get_cell_center_global(cell: Cell) -> Vector2:
	if cell == null:
		return Vector2.ZERO
	var capture_polygon := cell.get_node_or_null("Area2D/CapturePolygon") as CollisionPolygon2D
	if capture_polygon != null and not capture_polygon.polygon.is_empty():
		var sum := Vector2.ZERO
		for point in capture_polygon.polygon:
			sum += point
		return capture_polygon.global_transform * (sum / float(capture_polygon.polygon.size()))
	return cell.global_position
