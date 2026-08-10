extends Node2D

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const CAPTURE := preload("res://tests/infrastructure/presentation_capture.gd")
const SCENES := [
	preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn"),
	preload("res://Npc/enemy/scenes/enemy_repair_unit.tscn"),
	preload("res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn"),
]

var _failed := false


func _ready() -> void:
	_build_backdrop()
	for index in range(SCENES.size()):
		var enemy := SCENES[index].instantiate() as BaseEnemy
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.position = Vector2(185.0 + index * 290.0, 390.0)
		enemy.scale = Vector2.ONE * 2.25
		add_child(enemy)
		if index == 2:
			var skill_warning := enemy.get_node_or_null("SkillWarningTelegraph") as CanvasItem
			if skill_warning != null:
				skill_warning.visible = false
	var boss := SCENES[0].instantiate() as BaseEnemy
	boss.is_boss = true
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	boss.position = Vector2(1055.0, 390.0)
	boss.scale = Vector2.ONE * 2.7
	add_child(boss)
	var boss_marker := boss.get_node_or_null("AffiliationMarker") as Node2D
	if boss_marker != null:
		boss_marker.set("ground_footprint_size", Vector2(44.0, 44.0))
		boss_marker.set("radius", 22.0)
	await get_tree().process_frame
	_expect(await CAPTURE.capture(self, "presentation.enemy_hierarchy"), "enemy hierarchy presentation must satisfy the 1280x720 capture contract")
	print("FAIL: presentation enemy hierarchy" if _failed else "PASS: presentation enemy hierarchy")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: %s" % message)


func _build_backdrop() -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1280.0, 720.0)
	background.color = Color("10151d")
	background.z_index = -10
	add_child(background)
	_add_caption(Vector2(64.0, 98.0), "ENEMY READABILITY · COMBAT RANK HIERARCHY", 24)
	var names := ["STANDARD", "SUPPORT", "ELITE", "BOSS"]
	var descriptions := ["hostile marker", "repair relationship", "rank outline", "footprint + global HP"]
	for index in range(names.size()):
		var x := 120.0 + index * 290.0
		_add_caption(Vector2(x, 560.0), names[index], 17)
		_add_caption(Vector2(x, 590.0), descriptions[index], 12)


func _add_caption(at: Vector2, text: String, font_size: int) -> void:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("b9d5df"))
	add_child(label)
