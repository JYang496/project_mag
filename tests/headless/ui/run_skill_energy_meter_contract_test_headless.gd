extends Node

const SKILL_ENERGY_METER_SCRIPT := preload("res://UI/scripts/components/skill_energy_meter.gd")

var _failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var meter := SKILL_ENERGY_METER_SCRIPT.new()
	add_child(meter)
	await get_tree().process_frame

	meter.set_energy(100.0, 100.0)
	meter.set_skill_cost(50.0)
	meter.set_cooldown_ratio(0.25)
	var default_size := meter.custom_minimum_size
	_assert_equal(2, int(meter.call("_get_core_count")), "100 max energy should reserve two energy cores.")
	_assert_equal(1, int(meter.call("_get_required_core_count")), "50 skill cost should preview one energy core.")
	_assert_false(bool(meter.call("_has_energy_shortage")), "100 current energy should afford a 50 energy skill.")
	_assert_false(_has_text_or_progress_child(meter), "Skill energy meter should draw cores directly without labels or ProgressBars.")

	meter.set_skill_cost(100.0)
	_assert_equal(2, int(meter.call("_get_required_core_count")), "100 skill cost should preview two energy cores.")
	_assert_false(bool(meter.call("_has_energy_shortage")), "100 current energy should afford a 100 energy skill.")

	meter.set_energy(40.0, 100.0)
	_assert_true(bool(meter.call("_has_energy_shortage")), "Insufficient energy should be detectable for shortage styling.")
	_assert_equal(default_size, meter.custom_minimum_size, "Changing current energy should not resize the meter.")

	meter.set_energy(75.0, 150.0)
	_assert_equal(3, int(meter.call("_get_core_count")), "150 max energy should reserve three energy cores.")

	meter.queue_free()
	await get_tree().process_frame
	_finish()

func _has_text_or_progress_child(root: Node) -> bool:
	for child in root.get_children():
		if child is Label or child is ProgressBar:
			return true
		if _has_text_or_progress_child(child):
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

func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assert_true(expected == actual, "%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])

func _finish() -> void:
	if _failed:
		print("SkillEnergyMeterContractTest: FAIL")
	else:
		print("SkillEnergyMeterContractTest: PASS")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if _failed else 0)
