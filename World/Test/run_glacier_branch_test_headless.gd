extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_handler := root.get_node_or_null("/root/DataHandler")
	if data_handler == null:
		_fail("DataHandler autoload missing")
		return
	data_handler.call("load_weapon_branch_data")

	var glacier_scene := load("res://Player/Weapons/Instances/glacier_projector.tscn") as PackedScene
	if glacier_scene == null:
		_fail("failed to load Glacier Projector scene")
		return
	var glacier := glacier_scene.instantiate()
	root.add_child(glacier)
	await process_frame

	glacier.call("set_level", 1)
	glacier.set("fuse", 3)
	var base_half_angle := float(glacier.get("cone_half_angle_deg"))
	var whiteout_half_angle := base_half_angle * 1.5
	_assert_float(float(glacier.call("_get_effective_cone_half_angle_deg")), base_half_angle, "base cone half angle")
	glacier.call("_refresh_glacier_vfx", Vector2.RIGHT)
	await process_frame
	_assert_glacier_vfx_scale(glacier, 200.0 / 512.0, 0.596, "base glacier spray follows range and angle")
	if not bool(glacier.call("add_branch", "glacier_whiteout_expansion")):
		_fail("failed to add Whiteout Expansion")
		return
	_assert_float(float(glacier.call("_get_effective_cone_half_angle_deg")), whiteout_half_angle, "Whiteout half angle")
	_assert_float(float(glacier.call("_get_effective_attack_range")), 200.0, "Whiteout keeps base level range")
	_assert_int(int(glacier.call("get_runtime_shot_damage")), 6, "Whiteout keeps base level damage")
	glacier.call("_refresh_glacier_vfx", Vector2.RIGHT)
	await process_frame
	_assert_glacier_vfx_scale(glacier, 200.0 / 512.0, 0.85, "Whiteout glacier spray widens with effective cone")

	if not bool(glacier.call("add_branch", "glacier_subzero_battery")):
		_fail("failed to add Subzero Battery")
		return
	if not bool(glacier.call("has_branch", "glacier_whiteout_expansion")) or not bool(glacier.call("has_branch", "glacier_subzero_battery")):
		_fail("Glacier branches should coexist")
		return

	glacier.call("set_weapon_role", "main")
	glacier.set("magazine_capacity", 10)
	glacier.set("current_ammo", 4)
	var refunded := int(glacier.call("_refund_ammo_from_cold_snap_branches"))
	_assert_int(refunded, 6, "Subzero refund amount")
	_assert_int(int(glacier.get("current_ammo")), 10, "Subzero adds ammo")

	glacier.set("current_ammo", 9)
	refunded = int(glacier.call("_refund_ammo_from_cold_snap_branches"))
	_assert_int(refunded, 1, "Subzero refund is capped by magazine")
	_assert_int(int(glacier.get("current_ammo")), 10, "Subzero does not exceed magazine")

	var target := Node2D.new()
	root.add_child(target)
	glacier.set("current_ammo", 4)
	glacier.call("_try_emit_cold_snap_trigger", target)
	_assert_bool(not bool(glacier.call("is_passive_ready")), "Cold Snap is consumed before auto recharge")
	_assert_float(float(glacier.get("_cold_snap_recharge_remaining_sec")), 6.0, "Cold Snap trigger starts recharge")
	glacier.call("_physics_process", 5.9)
	_assert_bool(not bool(glacier.call("is_passive_ready")), "Cold Snap waits for full auto recharge")
	glacier.call("_physics_process", 0.1)
	_assert_bool(bool(glacier.call("is_passive_ready")), "Cold Snap auto recharges after 6 seconds")
	var status := glacier.call("get_passive_status") as Dictionary
	_assert_bool(bool(status.get("ready", false)), "Cold Snap status reports ready after auto recharge")

	glacier.call("notify_offhand_skill_triggered", 0.0)
	glacier.set("_cold_snap_recharge_remaining_sec", 6.0)
	glacier.call("refresh_passive_on_reload")
	_assert_bool(bool(glacier.call("is_passive_ready")), "Cold Snap reload refreshes immediately")
	_assert_float(float(glacier.get("_cold_snap_recharge_remaining_sec")), 0.0, "Cold Snap reload clears recharge")

	if _failed:
		return
	print("PASS: Glacier Projector Whiteout Expansion and Subzero Battery branches")
	quit(0)

func _assert_float(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.001:
		_fail("%s expected %.3f, got %.3f" % [label, expected, actual])

func _assert_int(actual: int, expected: int, label: String) -> void:
	if actual != expected:
		_fail("%s expected %d, got %d" % [label, expected, actual])

func _assert_bool(actual: bool, label: String) -> void:
	if not actual:
		_fail(label)

func _assert_glacier_vfx_scale(glacier: Node, expected_x: float, expected_y: float, label: String) -> void:
	var vfx := glacier.get_node_or_null("GlacierSprayVfx")
	if vfx == null:
		_fail("%s missing GlacierSprayVfx" % label)
		return
	if not vfx.visible:
		_fail("%s expected GlacierSprayVfx visible" % label)
		return
	var sprite := vfx.get_node_or_null("SprayRoot/Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		_fail("%s missing glacier SpriteFrames" % label)
		return
	if sprite.sprite_frames.get_frame_count(&"spray") != 8:
		_fail("%s expected 8 glacier spray frames" % label)
		return
	var spray_root := vfx.get_node_or_null("SprayRoot") as Node2D
	if spray_root == null:
		_fail("%s missing SprayRoot" % label)
		return
	_assert_float(spray_root.scale.x, expected_x, "%s length scale" % label)
	_assert_float(spray_root.scale.y, expected_y, "%s width scale" % label)

func _fail(message: String) -> void:
	_failed = true
	push_error("FAIL: %s" % message)
	quit(1)
