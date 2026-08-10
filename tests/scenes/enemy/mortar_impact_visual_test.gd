extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const MORTAR_SCENE := preload("res://Npc/enemy/scenes/enemy_mortar_turret.tscn")
const DESCENT_SCENE := preload("res://Npc/enemy/scenes/mortar_shell_descent_vfx.tscn")

var _failed := false


func _ready() -> void:
	var descent := DESCENT_SCENE.instantiate() as MortarShellDescentVfx
	add_child(descent)
	await get_tree().process_frame
	_expect_descent_frame(descent, 0.0, 0)
	_expect_descent_frame(descent, 0.4, 1)
	_expect_descent_frame(descent, 0.8, 2)
	var descent_frames := descent.animated_sprite.sprite_frames
	_expect(descent_frames.get_frame_count(&"descent") == 3, "mortar descent must contain three frames")
	_expect(
		descent_frames.get_frame_texture(&"descent", 0).get_size() == Vector2(128.0, 128.0),
		"mortar descent frames must use the effect-large 128x128 policy",
	)

	var mortar := MORTAR_SCENE.instantiate() as EnemyMortarTurret
	mortar.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(mortar)
	var impact_lead_time := float(mortar.call("_get_impact_lead_time"))
	_expect(is_equal_approx(impact_lead_time, 0.1), "mortar impact must begin two 20 FPS frames before damage")
	mortar.call("_spawn_mortar_impact", Vector2(40.0, 60.0), impact_lead_time)
	await get_tree().process_frame
	await get_tree().process_frame

	var area: AreaEffect = null
	for child in get_children():
		if child is AreaEffect:
			area = child as AreaEffect
			break
	_expect(area != null, "mortar impact must spawn an AreaEffect")
	if area != null:
		_expect(is_equal_approx(area.activation_delay, impact_lead_time), "mortar damage must wait for the two-frame explosion lead")
		_expect(area.visual_enabled and area.use_animated_visual, "mortar impact must enable its animated visual")
		_expect(not area.animated_visual_is_ground, "mortar fireball must remain an upright projected effect")
		_expect(not area.draw_enabled, "mortar impact must suppress the legacy range circle")
		_expect(area.visual_frames != null, "mortar impact must bind its SpriteFrames resource")
		if area.visual_frames != null:
			_expect(area.visual_frames.get_frame_count(&"impact") == 5, "mortar impact must contain five frames")
			_expect(not area.visual_frames.get_animation_loop(&"impact"), "mortar impact animation must not loop")
		_expect(is_equal_approx(area.radius, mortar.aoe_radius), "visual replacement must preserve the mortar damage radius")

	print("FAIL mortar impact visual" if _failed else "PASS mortar impact visual")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect_descent_frame(descent: MortarShellDescentVfx, progress: float, expected_frame: int) -> void:
	descent.set_descent_progress(progress)
	_expect(descent.animated_sprite.frame == expected_frame, "descent progress %.2f must select frame %d" % [progress, expected_frame])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
