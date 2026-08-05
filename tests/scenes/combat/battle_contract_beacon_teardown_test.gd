extends Node

const BattleContractCombatBridgeScript := preload("res://Combat/battle_contract/BattleContractCombatBridge.gd")
const TacticalBeaconScript := preload("res://World/battle_contract/tactical_beacon.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures: PackedStringArray = []


func _ready() -> void:
	_test_detached_completed_beacon_uses_immediate_cleanup()
	_test_attached_completed_beacon_keeps_completion_animation()
	if _failures.is_empty():
		print("PASS combat.battle_contract_beacon_teardown")
		await TEST_TEARDOWN.finish(self, 0)
		return
	for failure in _failures:
		push_error(failure)
	print("FAIL combat.battle_contract_beacon_teardown (%d assertions)" % _failures.size())
	await TEST_TEARDOWN.finish(self, 1)


func _test_detached_completed_beacon_uses_immediate_cleanup() -> void:
	var bridge := BattleContractCombatBridgeScript.new()
	var beacon := TacticalBeaconScript.new()
	add_child(beacon)
	beacon.set_progress(1.0)
	remove_child(beacon)
	bridge.set("_beacons", {1: beacon})

	bridge.request_remove_beacons()

	_expect(not bool(beacon.get("_removal_scheduled")), "detached completed beacon must not start a SceneTreeTimer-backed completion animation")
	_expect((bridge.get("_beacons") as Dictionary).is_empty(), "detached beacon references must be cleared during teardown")
	if is_instance_valid(beacon):
		beacon.free()


func _test_attached_completed_beacon_keeps_completion_animation() -> void:
	var bridge := BattleContractCombatBridgeScript.new()
	var beacon := TacticalBeaconScript.new()
	add_child(beacon)
	beacon.set_progress(1.0)
	bridge.set("_beacons", {1: beacon})

	bridge.request_remove_beacons()

	_expect(bool(beacon.get("_removal_scheduled")), "attached completed beacon must retain its completion animation")
	_expect((bridge.get("_beacons") as Dictionary).is_empty(), "attached beacon references must be cleared after scheduling removal")
	if is_instance_valid(beacon):
		beacon.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
