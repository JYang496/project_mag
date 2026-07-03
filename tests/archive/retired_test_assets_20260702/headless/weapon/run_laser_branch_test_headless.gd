extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data_handler := root.get_node_or_null("/root/DataHandler")
	if data_handler == null:
		_fail("DataHandler autoload missing")
		return
	data_handler.call("load_weapon_branch_data")
	var laser_scene := load("res://Player/Weapons/Instances/laser.tscn") as PackedScene
	if laser_scene == null:
		_fail("failed to load laser scene")
		return
	var laser := laser_scene.instantiate()
	root.add_child(laser)
	await process_frame
	laser.call("set_level", 5)
	laser.set("fuse", 3)
	_assert_profile_count(laser, 1, "base laser has one beam")
	_assert_damage_multiplier(laser, 0, 1.0, "base laser damage")

	if bool(laser.call("add_branch", "laser_focus_capacitor")):
		_fail("old Focus Capacitor branch should no longer be selectable")
		return

	if not bool(laser.call("add_branch", "laser_prism_splitter")):
		_fail("failed to add Prism Splitter. scene_file_path=%s laser_options=%s branch_keys=%s" % [
			str(laser.scene_file_path),
			_describe_laser_options(data_handler, str(laser.scene_file_path)),
			_describe_branch_keys(),
		])
		return
	_assert_profile_count(laser, 3, "prism splits into three beams")
	_assert_damage_multiplier(laser, 0, 1.0, "prism main keeps full damage")
	_assert_damage_multiplier(laser, 1, 0.55, "prism side uses side multiplier")

	laser.queue_free()
	await process_frame
	laser = laser_scene.instantiate()
	root.add_child(laser)
	await process_frame
	laser.call("set_level", 5)
	laser.set("fuse", 3)
	if not bool(laser.call("add_branch", "laser_tracking_lens")):
		_fail("failed to add Tracking Lens")
		return
	var solo_target := _spawn_tracking_target("SoloTarget", Vector2(800.0, 180.0))
	await process_frame
	_assert_profile_count(laser, 1, "tracking keeps one beam")
	_assert_damage_multiplier(laser, 0, 1.0, "tracking keeps base damage")
	_assert_tracking_target(laser, 0, solo_target, "tracking corrects base beam within 15 degrees")
	_clear_tracking_targets()
	await process_frame

	if not bool(laser.call("add_branch", "laser_prism_splitter")):
		_fail("failed to add Prism Splitter after Tracking Lens")
		return
	var left_target := _spawn_tracking_target("LeftTarget", _polar(700.0, -27.0))
	var main_target := _spawn_tracking_target("MainTarget", _polar(800.0, 0.0))
	var right_target := _spawn_tracking_target("RightTarget", _polar(700.0, 27.0))
	await process_frame
	_assert_profile_count(laser, 3, "tracking and prism coexist")
	_assert_damage_multiplier(laser, 0, 1.0, "tracked prism main damage")
	_assert_damage_multiplier(laser, 1, 1.0, "tracked prism side keeps full damage")
	_assert_damage_multiplier(laser, 2, 1.0, "tracked prism side keeps full damage")
	_assert_tracking_target(laser, 0, main_target, "tracked prism main chooses center target")
	_assert_tracking_target(laser, 1, left_target, "tracked prism left chooses independent target")
	_assert_tracking_target(laser, 2, right_target, "tracked prism right chooses independent target")

	print("PASS: Laser branch Tracking Lens and Prism Splitter profiles")
	quit(0)

func _profiles(laser: Node) -> Array:
	return laser.call("build_laser_beam_profiles", Vector2.RIGHT * 1000.0)

func _assert_profile_count(laser: Node, expected: int, label: String) -> void:
	var profiles := _profiles(laser)
	if profiles.size() != expected:
		_fail("%s expected %d profiles, got %d" % [label, expected, profiles.size()])

func _assert_damage_multiplier(laser: Node, index: int, expected: float, label: String) -> void:
	var profiles := _profiles(laser)
	if index < 0 or index >= profiles.size():
		_fail("%s missing profile %d" % [label, index])
		return
	var profile := profiles[index] as Dictionary
	var actual := float(profile.get("damage_multiplier", 0.0))
	if not is_equal_approx(actual, expected):
		_fail("%s expected damage %.3f, got %.3f" % [label, expected, actual])

func _assert_width_multiplier(laser: Node, index: int, expected: float, label: String) -> void:
	var profiles := _profiles(laser)
	if index < 0 or index >= profiles.size():
		_fail("%s missing profile %d" % [label, index])
		return
	var profile := profiles[index] as Dictionary
	var actual := float(profile.get("width_multiplier", 0.0))
	if not is_equal_approx(actual, expected):
		_fail("%s expected width %.3f, got %.3f" % [label, expected, actual])

func _assert_tracking_target(laser: Node, index: int, expected: Node2D, label: String) -> void:
	var profiles := _profiles(laser)
	if index < 0 or index >= profiles.size():
		_fail("%s missing profile %d" % [label, index])
		return
	var profile := profiles[index] as Dictionary
	if not bool(profile.get("tracking_applied", false)):
		_fail("%s expected tracking_applied=true" % label)
		return
	var actual := profile.get("tracking_target", null) as Node2D
	if actual != expected:
		_fail("%s expected target %s, got %s" % [label, expected.name, actual.name if actual != null else "null"])

func _spawn_tracking_target(target_name: String, target_position: Vector2) -> Node2D:
	var target := Node2D.new()
	target.name = target_name
	target.global_position = target_position
	target.add_to_group("enemies")
	root.add_child(target)
	var registry := root.get_node_or_null("EnemyRegistry")
	if registry != null and registry.has_method("register_enemy"):
		registry.call("register_enemy", target)
	return target

func _clear_tracking_targets() -> void:
	for node in root.get_tree().get_nodes_in_group("enemies"):
		var target := node as Node
		if target != null and str(target.name).ends_with("Target"):
			var registry := root.get_node_or_null("EnemyRegistry")
			if registry != null and registry.has_method("unregister_enemy"):
				registry.call("unregister_enemy", target)
			target.queue_free()

func _polar(distance: float, angle_deg: float) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * distance

func _fail(message: String) -> void:
	push_error("FAIL: %s" % message)
	quit(1)

func _describe_branch_keys() -> String:
	var global_variables := root.get_node_or_null("/root/GlobalVariables")
	if global_variables == null:
		return "GlobalVariables missing"
	var branch_list: Dictionary = global_variables.get("weapon_branch_list")
	return ", ".join(branch_list.keys())

func _describe_laser_options(data_handler: Node, scene_path: String) -> String:
	var options: Array = data_handler.call("read_weapon_branch_options", scene_path, 999)
	var ids: PackedStringArray = []
	for option in options:
		ids.append(str(option.branch_id))
	return ", ".join(ids)
