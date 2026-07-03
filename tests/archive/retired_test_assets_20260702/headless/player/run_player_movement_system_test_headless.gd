extends Node

const MOVEMENT_SYSTEM_SCRIPT := preload("res://Player/Mechas/scripts/player_movement_system.gd")
const FRAME_INPUT_SCRIPT := preload("res://Player/Mechas/scripts/movement_frame_input.gd")
const FRAME_RESULT_SCRIPT := preload("res://Player/Mechas/scripts/movement_frame_result.gd")
const REPEATED_TICK_COUNT: int = 100000
const REPEATED_TICK_BUDGET_USEC: int = 2000000

var _failed: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_run_manual_movement_table()
	_test_auto_navigation_progress()
	_test_auto_navigation_speed_multiplier()
	_test_auto_navigation_arrival_and_snap()
	_test_repeated_tick_reuses_frame_objects()
	_test_system_has_no_player_reference()
	if _failed:
		return
	print("PASS: player movement system")
	get_tree().quit(0)

func _run_manual_movement_table() -> void:
	var cases := [
		{
			"name": "acceleration",
			"velocity": Vector2.ZERO,
			"direction": Vector2.RIGHT,
			"allowed": true,
			"accel": 50.0,
			"decel": 40.0,
			"penalty": 0.25,
			"expected": Vector2(25.0, 0.0),
		},
		{
			"name": "deceleration",
			"velocity": Vector2(100.0, 0.0),
			"direction": Vector2.ZERO,
			"allowed": true,
			"accel": 50.0,
			"decel": 40.0,
			"penalty": 0.25,
			"expected": Vector2(80.0, 0.0),
		},
		{
			"name": "reverse turn penalty",
			"velocity": Vector2(50.0, 0.0),
			"direction": Vector2.LEFT,
			"allowed": true,
			"accel": 100.0,
			"decel": 40.0,
			"penalty": 0.25,
			"expected": Vector2(12.5, 0.0),
		},
		{
			"name": "PREPARE blocks manual input",
			"velocity": Vector2(50.0, 0.0),
			"direction": Vector2.RIGHT,
			"allowed": false,
			"accel": 100.0,
			"decel": 40.0,
			"penalty": 0.25,
			"expected": Vector2(30.0, 0.0),
		},
	]
	var system := MOVEMENT_SYSTEM_SCRIPT.new() as PlayerMovementSystem
	var frame_input := FRAME_INPUT_SCRIPT.new()
	var frame_result := FRAME_RESULT_SCRIPT.new()
	for case_data in cases:
		_set_default_input(frame_input)
		frame_input.current_velocity = case_data["velocity"]
		frame_input.manual_direction = case_data["direction"]
		frame_input.manual_input_allowed = case_data["allowed"]
		frame_input.move_accel = case_data["accel"]
		frame_input.move_decel = case_data["decel"]
		frame_input.move_turn_penalty = case_data["penalty"]
		system.tick(frame_input, frame_result)
		_assert_vector(
			case_data["expected"],
			frame_result.next_velocity,
			0.0001,
			"manual case '%s'" % case_data["name"]
		)

func _test_auto_navigation_progress() -> void:
	var system := MOVEMENT_SYSTEM_SCRIPT.new() as PlayerMovementSystem
	var frame_input := FRAME_INPUT_SCRIPT.new()
	var frame_result := FRAME_RESULT_SCRIPT.new()
	_set_default_input(frame_input)
	frame_input.auto_navigation_enabled = true
	frame_input.current_position = Vector2.ZERO
	frame_input.auto_navigation_destination = Vector2(100.0, 0.0)
	frame_input.move_accel = 50.0
	frame_input.delta = 1.0
	system.tick(frame_input, frame_result)
	_assert_vector(Vector2(50.0, 0.0), frame_result.next_velocity, 0.0001, "auto navigation acceleration")
	_assert_true(not frame_result.reached_target, "auto navigation reported arrival while target remained far away")
	_assert_true(not frame_result.should_snap_position, "auto navigation requested an early position snap")

func _test_auto_navigation_arrival_and_snap() -> void:
	var system := MOVEMENT_SYSTEM_SCRIPT.new() as PlayerMovementSystem
	var frame_input := FRAME_INPUT_SCRIPT.new()
	var frame_result := FRAME_RESULT_SCRIPT.new()
	_set_default_input(frame_input)
	frame_input.auto_navigation_enabled = true
	frame_input.current_velocity = Vector2(120.0, 0.0)
	frame_input.current_position = Vector2(8.0, 3.0)
	frame_input.auto_navigation_destination = Vector2(10.0, 3.0)
	system.tick(frame_input, frame_result)
	_assert_vector(Vector2.ZERO, frame_result.next_velocity, 0.0001, "arrival velocity")
	_assert_true(frame_result.reached_target, "arrival did not set reached_target")
	_assert_true(frame_result.should_snap_position, "arrival did not request position snap")
	_assert_vector(
		frame_input.auto_navigation_destination,
		frame_result.snap_position,
		0.0001,
		"arrival snap position"
	)
	_assert_true(frame_result.auto_navigation_completed, "arrival did not complete auto navigation")

func _test_auto_navigation_speed_multiplier() -> void:
	var system := MOVEMENT_SYSTEM_SCRIPT.new() as PlayerMovementSystem
	var frame_input := FRAME_INPUT_SCRIPT.new()
	var frame_result := FRAME_RESULT_SCRIPT.new()
	_set_default_input(frame_input)
	frame_input.auto_navigation_enabled = true
	frame_input.auto_navigation_destination = Vector2(1000.0, 0.0)
	frame_input.move_accel = 1000.0
	frame_input.delta = 1.0
	system.configure_auto_nav_speed_mul(2.0)
	system.tick(frame_input, frame_result)
	_assert_vector(Vector2(200.0, 0.0), frame_result.next_velocity, 0.0001, "auto navigation speed multiplier")
	system.reset_auto_nav_speed_mul()
	frame_input.current_velocity = Vector2.ZERO
	system.tick(frame_input, frame_result)
	_assert_vector(Vector2(100.0, 0.0), frame_result.next_velocity, 0.0001, "auto navigation speed reset")

func _test_repeated_tick_reuses_frame_objects() -> void:
	var system := MOVEMENT_SYSTEM_SCRIPT.new() as PlayerMovementSystem
	var frame_input := FRAME_INPUT_SCRIPT.new()
	var frame_result := FRAME_RESULT_SCRIPT.new()
	_set_default_input(frame_input)
	frame_input.delta = 1.0 / 60.0
	var input_id := frame_input.get_instance_id()
	var result_id := frame_result.get_instance_id()
	system.tick(frame_input, frame_result)
	var object_count_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var started_usec := Time.get_ticks_usec()
	for _index in range(REPEATED_TICK_COUNT):
		frame_input.current_velocity = frame_result.next_velocity
		system.tick(frame_input, frame_result)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	var object_count_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_assert_true(frame_input.get_instance_id() == input_id, "repeated tick replaced MovementFrameInput")
	_assert_true(frame_result.get_instance_id() == result_id, "repeated tick replaced MovementFrameResult")
	_assert_true(
		object_count_after == object_count_before,
		"repeated tick changed ObjectDB count: before=%d after=%d" % [object_count_before, object_count_after]
	)
	_assert_true(
		elapsed_usec <= REPEATED_TICK_BUDGET_USEC,
		"repeated tick exceeded budget: %d ticks took %d usec" % [REPEATED_TICK_COUNT, elapsed_usec]
	)
	print("MovementTickBenchmark ticks=", REPEATED_TICK_COUNT, " elapsed_usec=", elapsed_usec)

func _test_system_has_no_player_reference() -> void:
	var file := FileAccess.open(
		"res://Player/Mechas/scripts/player_movement_system.gd",
		FileAccess.READ
	)
	_assert_true(file != null, "could not inspect player_movement_system.gd")
	if file == null:
		return
	var source := file.get_as_text()
	_assert_true(not source.contains("_player"), "PlayerMovementSystem still contains a Player owner reference")

func _set_default_input(frame_input: RefCounted) -> void:
	frame_input.delta = 0.5
	frame_input.current_velocity = Vector2.ZERO
	frame_input.current_position = Vector2.ZERO
	frame_input.movement_enabled = true
	frame_input.auto_navigation_enabled = false
	frame_input.auto_navigation_destination = Vector2.ZERO
	frame_input.manual_input_allowed = true
	frame_input.manual_direction = Vector2.RIGHT
	frame_input.move_speed = 100.0
	frame_input.move_accel = 50.0
	frame_input.move_decel = 40.0
	frame_input.move_turn_penalty = 0.25

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	_fail(message)

func _assert_vector(expected: Vector2, actual: Vector2, tolerance: float, message: String) -> void:
	if expected.distance_to(actual) <= tolerance:
		return
	_fail("%s expected=%s actual=%s" % [message, str(expected), str(actual)])

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("FAIL: player movement system: " + message)
	get_tree().quit(1)
