extends SceneTree

const ZONE_HELPER := preload("res://World/rest_area_zone_helper.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var owner := Node2D.new()
	owner.name = "RestAreaHelperOwner"
	var area := Area2D.new()
	area.name = "Area2D"
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(300.0, 300.0)
	shape_node.shape = rect
	area.add_child(shape_node)
	owner.add_child(area)
	root.add_child(owner)

	var helper = ZONE_HELPER.new()
	helper.setup(owner, NodePath("Area2D/CollisionShape2D"), 3, 9, [0, 1, 2, 6])
	var center_rect: Rect2 = helper.get_zone_rect_local(4)
	if center_rect.position != Vector2(-50.0, -50.0) or center_rect.size != Vector2(100.0, 100.0):
		_fail("RestAreaHelperTest: center zone rect mismatch: %s" % str(center_rect))
		return
	if int(helper.get_zone_id_for_global_point(Vector2.ZERO)) != 4:
		_fail("RestAreaHelperTest: origin should hit center zone.")
		return
	if int(helper.get_zone_id_for_global_point(Vector2(-120.0, -120.0))) != 0:
		_fail("RestAreaHelperTest: top-left point should hit merchant zone.")
		return
	if int(helper.get_zone_id_for_global_point(Vector2(200.0, 200.0))) != -1:
		_fail("RestAreaHelperTest: outside point should not hit any zone.")
		return
	if not bool(helper.zone_opens_interaction(6)) or bool(helper.zone_opens_interaction(4)):
		_fail("RestAreaHelperTest: interactive zone classification mismatch.")
		return

	print("PASS: RestArea helper zone geometry and interaction classification")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
