extends Node

const COMBAT_RESOURCE_METER_SCRIPT := preload("res://UI/scripts/components/combat_resource_meter.gd")

var _failed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var ammo_meter := COMBAT_RESOURCE_METER_SCRIPT.new()
	add_child(ammo_meter)
	await get_tree().process_frame

	ammo_meter.set_resource(&"ammo", 1.0, &"normal", "", "Ammo: 40/40")
	_assert_false(ammo_meter.is_status_visible(), "Full ammo should not show persistent ammo text.")
	_assert_false(_contains_literal(ammo_meter, "AMMO"), "Ammo meter should not expose the AMMO literal in normal state.")

	ammo_meter.set_resource(&"ammo", 0.1, &"warning", "4/40", "Ammo: 4/40")
	_assert_true(ammo_meter.is_status_visible(), "Low ammo should show a compact numeric status.")
	_assert_false(_contains_literal(ammo_meter, "AMMO"), "Low ammo status should stay compact and avoid the AMMO literal.")

	ammo_meter.set_resource(&"ammo", 0.3, &"reloading", "1.2s", "Ammo: 12/40 (Reloading 1.2s)")
	_assert_true(ammo_meter.is_status_visible(), "Reloading should show a compact countdown status.")
	_assert_false(_contains_literal(ammo_meter, "AMMO"), "Reloading status should avoid the AMMO literal.")

	var heat_meter := COMBAT_RESOURCE_METER_SCRIPT.new()
	add_child(heat_meter)
	await get_tree().process_frame

	heat_meter.set_resource(&"heat", 0.0, &"normal", "", "Heat: 0/100 (0%)")
	_assert_false(heat_meter.is_status_visible(), "Zero heat should not show persistent heat text.")
	_assert_false(_contains_literal(heat_meter, "HEAT"), "Heat meter should not expose the HEAT literal in normal state.")

	heat_meter.set_resource(&"heat", 0.85, &"warning", "85%", "Heat: 85/100 (85%)")
	_assert_true(heat_meter.is_status_visible(), "High heat should show a compact percentage.")
	_assert_false(_contains_literal(heat_meter, "HEAT"), "High heat status should avoid the HEAT literal.")

	heat_meter.set_resource(&"heat", 1.0, &"locked", "LOCK", "Heat: 100/100 (100%) (OVERHEAT)")
	_assert_true(heat_meter.is_status_visible(), "Overheat should show a compact lock status.")
	_assert_false(_contains_literal(heat_meter, "HEAT"), "Overheat status should avoid the HEAT literal.")

	ammo_meter.queue_free()
	heat_meter.queue_free()
	await get_tree().process_frame
	_finish()

func _contains_literal(root: Node, literal: String) -> bool:
	for child in root.get_children():
		if child is Label and str(child.text).find(literal) != -1:
			return true
		if _contains_literal(child, literal):
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
		print("CombatResourceMeterContractTest: FAIL")
	else:
		print("CombatResourceMeterContractTest: PASS")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if _failed else 0)
