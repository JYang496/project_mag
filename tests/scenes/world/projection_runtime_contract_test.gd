extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const HYBRID_VIEW := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")

class DummyBoard:
	extends Node2D
	var cells: Array = []

var _failed := false


func _ready() -> void:
	var board := DummyBoard.new()
	board.name = "Board"
	add_child(board)

	var view := HYBRID_VIEW.new()
	view.board_path = NodePath("../Board")
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame

	var points: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(120.0, -90.0),
		Vector2(-240.0, 310.0),
	]
	for point in points:
		var projected := view.project_world_to_screen(point)
		var round_trip := view.screen_to_world_2d(projected)
		_expect(
			round_trip.distance_to(point) < 0.25,
			"projection round trip failed for %s: %s" % [point, round_trip]
		)

	var screen_right := view.world_vector_to_screen(Vector2.RIGHT, Vector2.ZERO)
	_expect(screen_right.length_squared() > 0.01, "world direction must produce a screen direction")

	view.configure(56.0, -4.0, 20.0)
	await get_tree().process_frame
	_expect(view.can_project_world_point(Vector2.ZERO), "camera must remain projectable after reconfigure")

	print("FAIL hybrid projection runtime contract" if _failed else "PASS hybrid projection runtime contract")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
