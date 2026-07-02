extends Node

const PLAYER_HEALTH_METER_SCRIPT := preload("res://UI/scripts/components/player_health_meter.gd")

var _failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var meter := PLAYER_HEALTH_METER_SCRIPT.new()
	add_child(meter)
	await get_tree().process_frame

	meter.set_health(100, 100)
	await get_tree().process_frame
	_assert_false(meter.is_value_visible(), "Full health should not show numeric HP text.")
	_assert_false(_contains_hp_literal(meter), "Health meter should not expose the literal HP label.")
	_assert_false(meter.is_warning(), "Full health should not be warning.")
	_assert_false(meter.is_critical(), "Full health should not be critical.")

	meter.set_health(25, 100)
	await get_tree().process_frame
	_assert_true(meter.is_warning(), "Health at 25 percent should enter warning state.")
	_assert_true(meter.is_value_visible(), "Low health should show short numeric value as auxiliary detail.")
	_assert_false(meter.is_critical(), "Health above the critical threshold should not be critical.")
	_assert_true(meter.has_damage_ghost(), "Dropping health should leave a damage ghost behind the main fill.")

	meter.set_health(12, 100)
	await get_tree().process_frame
	_assert_true(meter.is_critical(), "Health at 12 percent should enter critical state.")
	_assert_true(meter.is_value_visible(), "Critical health should keep the short numeric value visible.")
	_assert_false(_contains_hp_literal(meter), "Critical health should still avoid HP literal text.")

	meter.queue_free()
	await get_tree().process_frame
	_finish()

func _contains_hp_literal(root: Node) -> bool:
	for child in root.get_children():
		if child is Label and str(child.text).find("HP") != -1:
			return true
		if _contains_hp_literal(child):
			return true
	return false

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)

func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)

func _finish() -> void:
	if _failed:
		print("PlayerHealthMeterContractTest: FAIL")
	else:
		print("PlayerHealthMeterContractTest: PASS")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if _failed else 0)
