extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const HYBRID_VIEW := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const TAR_SLOW_ZONE := preload("res://Npc/enemy/scenes/tar_slow_zone.tscn")

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

	var zone := TAR_SLOW_ZONE.instantiate() as EnemyTarSlowZone
	zone.radius = 95.0
	zone.position = Vector2(120.0, -80.0)
	add_child(zone)
	await get_tree().process_frame
	await get_tree().process_frame

	var entries := view.get("_area_meshes") as Dictionary
	var entry := entries.get(zone.get_instance_id()) as Dictionary
	var mesh := entry.get("mesh") as MeshInstance3D
	_expect(mesh != null, "tar slow zone must register a hybrid ground mesh")
	_expect(not zone.draw_enabled, "hybrid registration must suppress the screen-space circle")

	if mesh != null:
		var world_scale := float(view.get("world_scale"))
		_expect(
			is_equal_approx(mesh.scale.x, zone.radius * world_scale)
			and is_equal_approx(mesh.scale.z, zone.radius * world_scale),
			"ground decal scale must preserve the gameplay radius",
		)
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		_expect(material != null, "tar slow zone must use a standard textured ground material")
		if material != null:
			_expect(material.albedo_texture == zone.visual_texture, "ground material must bind the selected tar texture")
			_expect(
				material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
				"pixel-art ground decal must use nearest texture filtering",
			)

	var collision := zone.get_node("CollisionShape2D") as CollisionShape2D
	var circle := collision.shape as CircleShape2D
	_expect(circle != null and is_equal_approx(circle.radius, 95.0), "visual replacement must not change the slow-zone collision radius")

	var zone_id := zone.get_instance_id()
	zone.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not entries.has(zone_id), "freed tar slow zone must leave the hybrid ground registry")

	print("FAIL tar slow zone ground visual" if _failed else "PASS tar slow zone ground visual")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
