extends SceneTree

const MovementFrameInputType := preload("res://Player/Mechas/scripts/movement_frame_input.gd")
const MovementFrameResultType := preload("res://Player/Mechas/scripts/movement_frame_result.gd")
const PLAYER_PATH := "res://Player/Mechas/scripts/Player.gd"
const INERTIAL_AIM_PATH := "res://Player/Weapons/Modules/wmod_inertial_aim.gd"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var system := PlayerMovementSystem.new()
	var frame_input := MovementFrameInputType.new()
	var frame_result := MovementFrameResultType.new()

	frame_input.delta = 0.1
	frame_input.current_velocity = Vector2.ZERO
	frame_input.movement_enabled = true
	frame_input.manual_input_allowed = true
	frame_input.manual_direction = Vector2.RIGHT
	frame_input.move_speed = 100.0
	frame_input.move_accel = 300.0
	frame_input.move_decel = 240.0
	system.tick(frame_input, frame_result)
	_assert_true(system.get_status().get("mode") == &"manual_move", "manual movement status")
	_assert_true(frame_result.next_velocity.is_equal_approx(Vector2.RIGHT * 30.0), "manual movement starts below full speed")

	frame_input.current_velocity = frame_result.next_velocity
	system.tick(frame_input, frame_result)
	_assert_true(frame_result.next_velocity.is_equal_approx(Vector2.RIGHT * 60.0), "manual movement keeps accelerating")

	frame_input.current_velocity = Vector2.RIGHT * 100.0
	frame_input.manual_direction = Vector2.ZERO
	system.tick(frame_input, frame_result)
	_assert_true(system.get_status().get("mode") == &"brake", "brake status")
	_assert_true(frame_result.next_velocity.x > 70.0, "weak slide preserves some velocity")

	var started := system.request_dash(Vector2.ZERO, Vector2(120.0, 0.0), 0.12, &"test_dash")
	_assert_true(started, "dash request accepted")
	frame_input.delta = 0.06
	frame_input.current_position = Vector2.ZERO
	frame_input.current_velocity = Vector2.ZERO
	system.tick(frame_input, frame_result)
	_assert_true(system.get_status().get("mode") == &"dash", "dash status")
	_assert_true(frame_result.next_velocity.is_equal_approx(Vector2.RIGHT * 1000.0), "dash velocity")

	frame_input.delta = 0.07
	frame_input.current_position = Vector2.RIGHT * 60.0
	frame_input.current_velocity = frame_result.next_velocity
	system.tick(frame_input, frame_result)
	_assert_true(frame_result.should_snap_position, "dash snaps to projected target")
	_assert_true(frame_result.snap_position.is_equal_approx(Vector2(120.0, 0.0)), "dash target")
	_assert_true(system.get_status().get("mode") == &"idle", "dash ends idle")
	_check_source_contracts()

	print("PASS: player movement system status and dash")
	quit(0)

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: %s" % message)
	quit(1)

func _check_source_contracts() -> void:
	var player_source := _read_source(PLAYER_PATH)
	_assert_true(player_source.contains("@export var move_accel: float = 450.0"), "player default has visible start acceleration")
	_assert_true(player_source.contains("signal movement_state_changed"), "player exposes movement state event")
	_assert_true(player_source.contains("signal dash_started"), "player exposes dash start event")
	_assert_true(player_source.contains("signal dash_finished"), "player exposes dash finish event")
	_assert_true(player_source.contains("signal hard_turn_triggered"), "player exposes hard-turn event")
	_assert_true(player_source.contains("movement_state_changed.emit"), "player emits movement state event")
	_assert_true(player_source.contains("dash_finished.emit"), "player emits dash finish event")

	var inertial_source := _read_source(INERTIAL_AIM_PATH)
	_assert_true(inertial_source.contains("get_movement_status"), "inertial aim consumes movement status")
	_assert_true(not inertial_source.contains("player.get(\"velocity\") != null and"), "inertial aim no longer depends on inline velocity polling")

func _read_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_assert_true(file != null, "can read %s" % path)
	return file.get_as_text()
