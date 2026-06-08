extends SceneTree

var _player_data: Node
var _player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _setup_runtime():
		return
	if not await _assert_orbit_ammo_table():
		return
	if not await _assert_full_magazine_deploy_consumes_all_and_reloads():
		return
	if not await _assert_partial_magazine_deploy_and_satellite_overlap():
		return
	_cleanup()
	await process_frame
	print("PASS: Orbit ammo deploy firing contract")
	quit(0)


func _setup_runtime() -> bool:
	_player_data = root.get_node_or_null("/root/PlayerData")
	if _player_data == null:
		return _fail("missing PlayerData autoload")
	_player = Node2D.new()
	_player.global_position = Vector2.ZERO
	root.add_child(_player)
	_player_data.set("player", _player)
	var phase_manager := root.get_node_or_null("PhaseManager")
	if phase_manager != null and phase_manager.has_method("enter_battle"):
		phase_manager.call("enter_battle")
	return true


func _make_orbit() -> Node:
	var scene := load("res://Player/Weapons/orbit.tscn") as PackedScene
	var orbit := scene.instantiate()
	root.add_child(orbit)
	orbit.call("set_weapon_role", "main")
	orbit.set_meta("_benchmark_mouse_target", Vector2(640.0, 360.0))
	return orbit


func _assert_orbit_ammo_table() -> bool:
	var orbit := _make_orbit()
	await process_frame
	var expected := [2, 2, 3, 3, 4, 5, 6, 7, 8]
	for index in range(expected.size()):
		var level := index + 1
		orbit.call("set_level", level)
		var magazine := int(orbit.get("magazine_capacity"))
		if magazine != expected[index]:
			return _fail("level %d magazine expected %d got %d" % [level, expected[index], magazine])
	orbit.free()
	return true


func _assert_full_magazine_deploy_consumes_all_and_reloads() -> bool:
	var orbit := _make_orbit()
	await process_frame
	orbit.call("set_level", 5)
	orbit.set("is_on_cooldown", false)
	var ammo_before := int(orbit.get("current_ammo"))
	var fired := bool(orbit.call("request_primary_fire"))
	await process_frame
	if not fired:
		return _fail("full magazine Orbit deploy did not fire")
	if ammo_before != 4:
		return _fail("level 5 Orbit expected full magazine 4 got %d" % ammo_before)
	if int(orbit.get("current_ammo")) != 0:
		return _fail("Orbit deploy should consume all ammo, got %d" % int(orbit.get("current_ammo")))
	if not bool(orbit.get("is_reloading")):
		return _fail("Orbit deploy should immediately start reload")
	var reload_left := float(orbit.get("reload_time_left"))
	if reload_left <= 7.9 or reload_left > 8.0:
		return _fail("Orbit reload expected near 8.0s got %.3f" % reload_left)
	var satellites: Array = orbit.call("get_satellites")
	if satellites.size() != ammo_before:
		return _fail("Orbit deploy expected %d satellites got %d" % [ammo_before, satellites.size()])
	orbit.free()
	return true


func _assert_partial_magazine_deploy_and_satellite_overlap() -> bool:
	var orbit := _make_orbit()
	await process_frame
	orbit.call("set_level", 9)
	orbit.set("current_ammo", 3)
	orbit.set("is_reloading", false)
	orbit.set("reload_time_left", 0.0)
	orbit.set("is_on_cooldown", false)
	var first_fired := bool(orbit.call("request_primary_fire"))
	await process_frame
	if not first_fired:
		return _fail("partial magazine Orbit deploy did not fire")
	var first_satellites: Array = orbit.call("get_satellites")
	if first_satellites.size() != 3:
		return _fail("partial Orbit deploy expected 3 satellites got %d" % first_satellites.size())
	orbit.set("current_ammo", 2)
	orbit.set("is_reloading", false)
	orbit.set("reload_time_left", 0.0)
	orbit.set("is_on_cooldown", false)
	var second_fired := bool(orbit.call("request_primary_fire"))
	await process_frame
	if not second_fired:
		return _fail("second partial Orbit deploy did not fire")
	var combined_satellites: Array = orbit.call("get_satellites")
	if combined_satellites.size() != 5:
		return _fail("Orbit should keep old satellites and add new ones, expected 5 got %d" % combined_satellites.size())
	if int(orbit.get("current_ammo")) != 0:
		return _fail("second Orbit deploy should consume all ammo, got %d" % int(orbit.get("current_ammo")))
	orbit.free()
	return true


func _cleanup() -> void:
	if _player_data != null:
		_player_data.set("player", null)
	if _player != null and is_instance_valid(_player):
		_player.free()


func _fail(message: String) -> bool:
	push_error("FAIL: Orbit ammo deploy firing contract: %s" % message)
	_cleanup()
	quit(1)
	return false
