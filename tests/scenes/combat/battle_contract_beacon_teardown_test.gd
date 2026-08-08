extends Node

const BattleContractCombatBridgeScript := preload("res://Combat/battle_contract/BattleContractCombatBridge.gd")
const TacticalBeaconScript := preload("res://World/battle_contract/tactical_beacon.gd")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failures: PackedStringArray = []

class RecoverySpawner:
	extends Node
	var recovery_position := Vector2(120.0, 80.0)
	var relocation_calls := 0

	func get_random_position() -> Vector2:
		relocation_calls += 1
		return recovery_position

	func get_active_enemy_count() -> int:
		return 1


func _ready() -> void:
	_test_detached_completed_beacon_uses_immediate_cleanup()
	_test_attached_completed_beacon_keeps_completion_animation()
	_test_distant_moving_enemy_is_recovered()
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


func _test_distant_moving_enemy_is_recovered() -> void:
	var original_player = PlayerData.player
	var player := Node2D.new()
	var enemy := Node2D.new()
	var spawner := RecoverySpawner.new()
	add_child(player)
	add_child(enemy)
	add_child(spawner)
	PlayerData.player = player
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(1200.0, 0.0)

	var bridge := BattleContractCombatBridgeScript.new()
	bridge.set("_spawner", spawner)
	bridge.set("_monitor_enemy_stalls", true)
	bridge.set("_enemy_by_id", {1: enemy})
	bridge.call("_on_enemy_spawned", enemy)
	var tracked_id := int(enemy.get_meta("_battle_contract_enemy_id", 0))
	for index in range(33):
		# Continuous tangential motion bypassed the old stationary-only watchdog.
		enemy.global_position.y += 3.0
		bridge.call("_on_combat_frame", 0.25)

	_expect(spawner.relocation_calls == 1, "a distant enemy that keeps moving without approaching the player must be returned to the battlefield")
	_expect(tracked_id > 0, "recovery fixture must track the spawned enemy through the combat bridge")
	bridge.set("_enemy_by_id", {})
	PlayerData.player = original_player
	enemy.queue_free()
	player.queue_free()
	spawner.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
