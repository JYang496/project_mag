extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const HYBRID_VIEW := preload("res://Visual/Oblique/hybrid_ground_view_3d.gd")
const REPAIR_SCENE := preload("res://Npc/enemy/scenes/enemy_repair_unit.tscn")
const SHIELD_SCENE := preload("res://Npc/enemy/scenes/enemy_shield_core.tscn")
const ORBIT_SCENE := preload("res://Npc/enemy/scenes/enemy_orbit_support.tscn")
const TARGET_SCENE := preload("res://Npc/enemy/scenes/base_enemy.tscn")

class LinkSource:
	extends Node2D
	var target: Node2D
	func get_hybrid_link_visuals() -> Array[Dictionary]:
		return [{"target": target, "relationship_kind": &"repair", "link_style": 1, "flow_speed": 2.4, "segment_count": 14.0, "color": Color.GREEN, "width": 2.0}]

var _failed := false

func _ready() -> void:
	await _test_support_semantic_profiles()
	await _test_renderer_style_and_cleanup()
	print("FAIL: support relationship visual" if _failed else "PASS: support relationship visual")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_support_semantic_profiles() -> void:
	var target := TARGET_SCENE.instantiate() as BaseEnemy
	var repair := REPAIR_SCENE.instantiate() as BaseEnemy
	var shield := SHIELD_SCENE.instantiate() as BaseEnemy
	var orbit := ORBIT_SCENE.instantiate() as BaseEnemy
	for enemy in [target, repair, shield, orbit]:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(enemy)
	await get_tree().process_frame
	repair.set("_heal_target", target)
	var repair_links := repair.call("get_hybrid_link_visuals") as Array
	_expect(repair_links.size() == 1, "repair unit must expose its current target relationship")
	if not repair_links.is_empty():
		var config := repair_links[0] as Dictionary
		_expect(config.get("relationship_kind") == &"repair" and int(config.get("link_style", 0)) == 1, "repair relationship must use directed segmented flow")
		_expect(float(config.get("flow_speed", 0.0)) > 0.0, "repair segments must visibly flow toward the target")
	shield.call("_on_shield_area_body_entered", target)
	var shield_links := shield.call("get_hybrid_link_visuals") as Array
	_expect(shield_links.size() == 1, "shield core must expose protected-target relationship")
	if not shield_links.is_empty():
		var config := shield_links[0] as Dictionary
		_expect(config.get("relationship_kind") == &"shield" and int(config.get("link_style", 0)) == 2, "shield relationship must use continuous energy pulse")
	_expect((orbit.call("get_hybrid_aura_visual") as Dictionary).get("relationship_kind") == &"speed_aura", "orbit support must communicate through a ground aura")
	for enemy in [target, repair, shield, orbit]:
		enemy.queue_free()
	await get_tree().process_frame

func _test_renderer_style_and_cleanup() -> void:
	var view := HYBRID_VIEW.new()
	view.enabled = false
	view.board_path = NodePath("MissingBoard")
	add_child(view)
	var target := Node2D.new()
	var source := LinkSource.new()
	source.target = target
	add_child(target)
	add_child(source)
	await get_tree().process_frame
	view.call("_register_enemy_support_visual", source)
	view.call("_sync_enemy_link_meshes")
	var entries := view.get("_enemy_link_meshes") as Dictionary
	_expect(entries.size() == 1, "renderer must create one mesh per active support relationship")
	if not entries.is_empty():
		var entry := entries.values()[0] as Dictionary
		var mesh := entry.get("mesh") as MeshInstance3D
		_expect(mesh != null and int(mesh.get_instance_shader_parameter("link_style")) == 1, "renderer must forward relationship shape to the shared shader")
		_expect(mesh != null and is_equal_approx(float(mesh.get_instance_shader_parameter("flow_speed")), 2.4), "renderer must forward semantic flow speed")
	source.queue_free()
	await get_tree().process_frame
	view.call("_sync_enemy_link_meshes")
	_expect((view.get("_enemy_link_meshes") as Dictionary).is_empty(), "freed support sources must release pooled relationship meshes")
	target.queue_free()
	view.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
