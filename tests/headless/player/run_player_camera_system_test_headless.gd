extends Node

const PlayerCameraConfigType := preload("res://Player/Mechas/scripts/player_camera_config.gd")

var _failed: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PhaseManager.phase = PhaseManager.BATTLE
	var holder := Node2D.new()
	holder.name = "PlayerCameraSystemTestHolder"
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE
	camera.global_position = Vector2(10.0, 20.0)
	holder.add_child(camera)
	add_child(holder)
	await get_tree().process_frame

	var config := PlayerCameraConfigType.new()
	config.camera_zoom_lerp_speed = 100.0
	config.battle_camera_view_mul = 0.5
	config.rest_phase_camera_zoom_factor = 1.25
	config.rest_camera_zoom_transition_enabled = false
	config.camera_lookahead_lerp_speed = 100.0

	var system := PlayerCameraSystem.new()
	system.setup(camera, config, 1.0)
	system.update_zoom_target_by_vision(1.0)
	system.tick(1.0)
	if not _assert_vector(Vector2(2.0, 2.0), camera.zoom, 0.001, "battle zoom uses explicit battle multiplier"):
		return

	PhaseManager.phase = PhaseManager.PREPARE
	system.on_phase_changed()
	system.update_zoom_target_by_vision(1.0)
	system.tick(1.0)
	if not _assert_vector(Vector2(1.25, 1.25), camera.zoom, 0.001, "prepare zoom uses explicit rest factor"):
		return
	system.force_recover_battle_zoom(2.0)
	if not _assert_vector(Vector2(1.0, 1.0), camera.zoom, 0.001, "battle zoom recovery uses stored base zoom and config"):
		return

	system.set_restarea_control_enabled(true, Vector2(100.0, 50.0), true)
	if not camera.top_level:
		_fail("rest-area control did not detach camera with top_level")
		return
	if not _assert_vector(Vector2(100.0, 50.0), camera.global_position, 0.001, "rest-area snap target"):
		return
	system.request_camera_shake(0.3)
	system.tick(1.0 / 60.0)
	if not _assert_vector(Vector2.ZERO, camera.offset, 0.001, "rest-area tick clears shake offset"):
		return

	system.configure_restarea_camera_motion(100.0, 100.0, 1.0)
	system.move_restarea_camera_to(Vector2(200.0, 50.0), 1.0)
	system.tick(0.5)
	if system.is_restarea_camera_close_to(Vector2(200.0, 50.0), 1.0):
		_fail("rest-area camera reached target too early")
		return
	for _i in range(16):
		system.tick(0.1)
	if not system.is_restarea_camera_close_to(Vector2(200.0, 50.0), 0.01):
		_fail("rest-area camera did not reach target")
		return

	PhaseManager.phase = PhaseManager.BATTLE
	system.on_phase_changed()
	if camera.top_level:
		_fail("battle phase did not restore camera parent binding")
		return
	if not _assert_vector(Vector2.ZERO, camera.position, 0.001, "battle phase restores local camera position"):
		return

	if not _assert_camera_system_has_no_player_owner():
		return

	holder.queue_free()
	await get_tree().process_frame
	print("PASS: player camera system")
	get_tree().quit(0)

func _assert_camera_system_has_no_player_owner() -> bool:
	var file := FileAccess.open("res://Player/Mechas/scripts/player_camera_system.gd", FileAccess.READ)
	if file == null:
		return _fail("could not inspect player_camera_system.gd")
	var source := file.get_as_text()
	if source.contains("_player"):
		return _fail("PlayerCameraSystem still contains a Player owner reference")
	if source.contains(".get(\"battle_camera_view_mul\")"):
		return _fail("PlayerCameraSystem still reads Player camera config dynamically")
	return true

func _assert_vector(expected: Vector2, actual: Vector2, tolerance: float, message: String) -> bool:
	if expected.distance_to(actual) <= tolerance:
		return true
	return _fail("%s expected=%s actual=%s" % [message, str(expected), str(actual)])

func _fail(message: String) -> bool:
	if not _failed:
		_failed = true
		push_error("FAIL: player camera system: " + message)
		get_tree().quit(1)
	return false
