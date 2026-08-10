extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const ELITE_SCENE := preload("res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn")
const SPAWN_TELEGRAPH := preload("res://Npc/enemy/components/enemy_spawn_ground_telegraph.gd")

var _failed := false


func _ready() -> void:
	_test_spawn_ground_semantics()
	await _test_stateful_outline()
	print("FAIL: elite visual" if _failed else "PASS: elite visual")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _test_spawn_ground_semantics() -> void:
	var telegraph := SPAWN_TELEGRAPH.new()
	add_child(telegraph)
	telegraph.set_sequence_progress(0.12, 0.32)
	var warning := telegraph.get_hybrid_aura_visual() as Dictionary
	_expect(warning.get("relationship_kind") == &"elite_spawn_warning", "elite spawn must expose a dedicated ground warning semantic")
	_expect((warning.get("line_color") as Color).r > (warning.get("line_color") as Color).b, "warning phase must read orange before materialization")
	telegraph.set_sequence_progress(0.78, 0.32)
	var materialize := telegraph.get_hybrid_aura_visual() as Dictionary
	_expect((materialize.get("line_color") as Color).b > (materialize.get("line_color") as Color).r, "materialization phase must transition toward data cyan")
	telegraph.queue_free()


func _test_stateful_outline() -> void:
	var elite := ELITE_SCENE.instantiate() as EliteEnemy
	elite.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(elite)
	await get_tree().process_frame
	var material := elite.highlight_material
	_expect(material != null, "elite must create its outline material")
	if material != null:
		elite.skill_ready = false
		_expect(not bool(material.get_shader_parameter("animated")), "elite cooldown must use a quiet static outline")
		_expect(is_equal_approx(float(material.get_shader_parameter("body_brightness")), 1.0), "normal elite state must not continuously brighten the body")
		elite.skill_ready = true
		_expect(bool(material.get_shader_parameter("animated")), "skill ready must use a light pulse")
		elite.set_skill_activation_visual(true)
		_expect(float(material.get_shader_parameter("outline_strength")) >= 0.99, "skill activation must use the strong outline state")
	elite.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
