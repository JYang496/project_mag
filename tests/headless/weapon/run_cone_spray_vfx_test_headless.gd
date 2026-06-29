extends SceneTree

var _failed: bool = false
var _test_scene: Node


func _initialize() -> void:
	create_timer(5.0).timeout.connect(func() -> void:
		_fail("cone spray VFX test timed out")
		_finish()
	)
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://tests/scenes/weapon/heat_passive_test.tscn") as PackedScene
	if packed == null:
		_fail("unable to load heat_passive_test.tscn")
		_finish()
		return
	var scene := packed.instantiate()
	if scene == null:
		_fail("missing heat passive test scene")
		_finish()
		return
	_test_scene = scene
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame

	scene.call("_set_main_weapon", "Flamethrower")
	await physics_frame
	var weapons_by_name: Dictionary = scene.get("_weapons_by_name")
	var weapon := weapons_by_name.get("Flamethrower", null) as Node2D
	if weapon == null or not is_instance_valid(weapon):
		_fail("missing Flamethrower weapon")
		_finish()
		return

	if not weapon.has_method("_refresh_flame_vfx"):
		_fail("flamethrower missing _refresh_flame_vfx")
		_finish()
		return
	weapon.call("_refresh_flame_vfx", Vector2.RIGHT)
	await process_frame

	var vfx := weapon.get_node_or_null("FlameSprayVfx")
	if vfx == null:
		_fail("flamethrower did not create FlameSprayVfx")
		_finish()
		return
	if not vfx.visible:
		_fail("FlameSprayVfx not visible after refresh")
	if not vfx.has_method("is_visible_or_fading") or not bool(vfx.call("is_visible_or_fading")):
		_fail("FlameSprayVfx not active after refresh")

	weapon.set_meta("_benchmark_mouse_target", weapon.global_position + Vector2.RIGHT * 240.0)
	for i in range(36):
		weapon.call("handle_primary_input", true, false, false, 0.016)
		vfx.call("_physics_process", 1.0 / 60.0)
	if not vfx.visible:
		_fail("FlameSprayVfx did not stay visible during held fire")

	weapon.call("handle_primary_input", false, false, true, 0.0)
	for i in range(60):
		weapon.call("handle_primary_input", false, false, false, 1.0 / 60.0)
		vfx.call("_physics_process", 1.0 / 60.0)
	if vfx.visible:
		_fail("FlameSprayVfx did not fade out after fire release. linger=%.3f fade=%.3f" % [
			float(vfx.get("_linger_remaining_sec")),
			float(vfx.get("_fade_remaining_sec")),
		])

	weapon.call("_refresh_flame_vfx", Vector2.RIGHT)
	await process_frame
	weapon.set("current_ammo", 0)
	weapon.set("is_reloading", true)
	for i in range(60):
		weapon.call("handle_primary_input", true, false, false, 1.0 / 60.0)
		vfx.call("_physics_process", 1.0 / 60.0)
	if vfx.visible:
		_fail("FlameSprayVfx did not fade out during empty/reloading held fire. linger=%.3f fade=%.3f" % [
			float(vfx.get("_linger_remaining_sec")),
			float(vfx.get("_fade_remaining_sec")),
		])

	weapon.set("current_ammo", maxi(1, int(weapon.get("magazine_capacity"))))
	weapon.set("is_reloading", false)
	if weapon.has_method("lock_heat_value") and weapon.has_method("get_heat_max_value"):
		var heat_max := maxf(float(weapon.call("get_heat_max_value")), 1.0)
		weapon.call("lock_heat_value", heat_max, 0.2)
	weapon.call("_refresh_flame_vfx", Vector2.RIGHT)
	await process_frame
	for i in range(60):
		weapon.call("handle_primary_input", true, false, false, 1.0 / 60.0)
		vfx.call("_physics_process", 1.0 / 60.0)
	if vfx.visible:
		_fail("FlameSprayVfx did not fade out during overheated held fire. linger=%.3f fade=%.3f" % [
			float(vfx.get("_linger_remaining_sec")),
			float(vfx.get("_fade_remaining_sec")),
		])

	_finish()


func _fail(message: String) -> void:
	_failed = true
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _test_scene != null and is_instance_valid(_test_scene):
		if _test_scene.get_parent() != null:
			_test_scene.get_parent().remove_child(_test_scene)
		_test_scene.free()
	if _failed:
		quit(1)
		return
	print("PASS: cone spray VFX refresh and fade lifecycle")
	quit(0)
