extends Node

const HybridView := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const HybridCameraDefaultsType := preload("res://Visual/Oblique/hybrid_camera_defaults.gd")
const BaseEnemyScene := preload("res://Npc/enemy/scenes/base_enemy.tscn")
const EliteEnemyScene := preload("res://Npc/enemy/scenes/elite_enemy.tscn")

class DummyCell:
	extends Node2D
	var board_enabled: bool = true

class DummyBoard:
	extends Node2D

	signal active_cells_changed(active_cell_ids: PackedInt32Array)
	signal board_visual_active_changed(active: bool, immediate: bool)
	signal board_recentered(offset: Vector2)

	var _board_active: bool = true
	var cells: Array[Node2D] = []

	func get_cells() -> Array[Node2D]:
		return cells

class DummyRestArea:
	extends Node2D
	var selected_zone_id: int = 4
	var hover_zone_id: int = -1

	func _get_zone_rect_local(zone_id: int) -> Rect2:
		var column := zone_id % 3
		var row := zone_id / 3
		return Rect2(Vector2(column, row) * 170.0, Vector2(170.0, 170.0))

func _ready() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	player.position = Vector2(320.0, 180.0)
	add_child(player)
	var board := DummyBoard.new()
	board.name = "Board"
	add_child(board)
	var cell := DummyCell.new()
	cell.name = "DummyCell"
	var texture_root := Node2D.new()
	texture_root.name = "Texture"
	cell.add_child(texture_root)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	var texture := GradientTexture2D.new()
	texture.width = 512
	texture.height = 512
	sprite.texture = texture
	texture_root.add_child(sprite)
	board.add_child(cell)
	board.cells.append(cell)
	var rest_area := DummyRestArea.new()
	rest_area.name = "RestArea"
	rest_area.add_to_group(&"rest_area")
	rest_area.position = Vector2(-180.0, 420.0)
	var rest_texture_root := Node2D.new()
	rest_texture_root.name = "Texture"
	rest_texture_root.position = Vector2(255.0, 255.0)
	rest_area.add_child(rest_texture_root)
	var rest_sprite := Sprite2D.new()
	rest_sprite.name = "Sprite2D"
	rest_sprite.texture = texture
	rest_texture_root.add_child(rest_sprite)
	add_child(rest_area)
	var view := HybridView.new()
	view.board_path = NodePath("../Board")
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	var failed := false
	failed = _check(is_equal_approx(view.camera_distance, HybridCameraDefaultsType.CAMERA_DISTANCE), "Camera3D must use the shared distance default") or failed
	var rest_ground := view.get_node_or_null("GroundMeshes/RestAreaGround") as MeshInstance3D
	failed = _check(rest_ground != null, "hidden 2D RestArea texture must have a 3D ground replacement") or failed
	if rest_ground != null:
		failed = _check(rest_ground.position.distance_to(view.world_2d_to_3d(rest_sprite.global_position)) < 0.001, "3D RestArea ground must follow its 2D texture anchor") or failed
	var ground_mesh := view.get_node_or_null("GroundMeshes/DummyCellGround") as MeshInstance3D
	failed = _check(ground_mesh != null, "dummy 2D Cell must create a mapped 3D ground mesh") or failed
	if ground_mesh != null:
		var position_before := ground_mesh.position
		var recenter_offset := Vector2(140.0, -75.0)
		board.position += recenter_offset
		board.board_recentered.emit(recenter_offset)
		await get_tree().process_frame
		var expected_delta := view.world_2d_to_3d(recenter_offset)
		failed = _check(ground_mesh.position.distance_to(position_before + expected_delta) < 0.001, "3D Cell must follow 2D Board recenter") or failed
		board.board_visual_active_changed.emit(false, true)
		failed = _check(not ground_mesh.visible, "3D Cell must hide with the 2D Board") or failed
		board.board_visual_active_changed.emit(true, true)
		failed = _check(ground_mesh.visible, "3D Cell must become visible with the 2D Board") or failed
	var screen := view.project_world_to_screen(player.position)
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	failed = _check(screen.distance_to(viewport_center) < 2.0, "camera target must project to viewport center") or failed
	var points := [Vector2.ZERO, Vector2(120.0, -90.0), Vector2(-240.0, 310.0)]
	for point: Vector2 in points:
		var projected := view.project_world_to_screen(point)
		var round_trip := view.screen_to_world_2d(projected)
		failed = _check(round_trip.distance_to(point) < 0.25, "projection round trip failed for %s: %s" % [point, round_trip]) or failed
	var screen_right := view.world_vector_to_screen(Vector2.RIGHT, player.position)
	failed = _check(screen_right.length_squared() > 0.01, "world direction must produce a screen direction") or failed
	view.configure(56.0, -4.0, 20.0)
	await get_tree().process_frame
	failed = _check(view.can_project_world_point(player.position), "camera must remain projectable after reconfigure") or failed
	var base_enemy := BaseEnemyScene.instantiate() as BaseEnemy
	base_enemy.position = Vector2(80.0, 40.0)
	add_child(base_enemy)
	var elite_enemy := EliteEnemyScene.instantiate() as BaseEnemy
	elite_enemy.position = Vector2(-120.0, 60.0)
	add_child(elite_enemy)
	await get_tree().process_frame
	await get_tree().process_frame
	for enemy: BaseEnemy in [base_enemy, elite_enemy]:
		var body := enemy.get_node("Body") as Sprite2D
		failed = _check(body.has_method("set_screen_offset"), "%s body must use billboard projection" % enemy.name) or failed
		var expected_canvas := view.project_world_to_canvas(enemy.global_position, get_viewport())
		failed = _check(body.global_position.distance_to(expected_canvas) < 2.0, "%s billboard does not match logical footpoint" % enemy.name) or failed
	if failed:
		print("FAIL hybrid projection")
		get_tree().quit(1)
	else:
		print("PASS hybrid projection")
		get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
