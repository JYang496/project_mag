extends SceneTree

const CLOSE_VULNERABILITY_STATUS_ID := &"close_vulnerability"
const CLOSE_CHAIN_RULES := preload("res://Player/Weapons/close_quarters_chain_rules.gd")

var _player_data: Node
var _player: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _setup_player_data():
		return
	if not await _assert_orbit_hit_applies_and_refreshes_light_slow():
		return
	if not _assert_chainsaw_accepts_orbit_slow():
		return
	_cleanup()
	await process_frame
	print("PASS: Orbit close-chain slow integration")
	quit(0)


func _setup_player_data() -> bool:
	_player_data = root.get_node_or_null("/root/PlayerData")
	if _player_data == null:
		return _fail("missing PlayerData autoload")
	_player = Node2D.new()
	_player.global_position = Vector2.ZERO
	root.add_child(_player)
	_player_data.set("player", _player)
	return true


func _make_target() -> Node2D:
	var scene := load("res://World/Test/dps_test_dummy_enemy.tscn") as PackedScene
	var target := scene.instantiate() as Node2D
	target.set("max_hp_value", 100)
	target.set("hp", 100)
	target.global_position = Vector2(100.0, 0.0)
	root.add_child(target)
	target.set("movement_speed", 100.0)
	return target


func _make_orbit() -> Node:
	var scene := load("res://Player/Weapons/Instances/orbit.tscn") as PackedScene
	var orbit := scene.instantiate()
	root.add_child(orbit)
	return orbit


func _assert_orbit_hit_applies_and_refreshes_light_slow() -> bool:
	var orbit := _make_orbit()
	var target := _make_target()
	await process_frame
	orbit.call("on_hit_target", target)
	if not bool(target.call("is_slowed")):
		return _fail("Orbit hit did not slow target")
	var speed := float(target.call("get_current_movement_speed"))
	if not is_equal_approx(speed, 85.0):
		return _fail("Orbit slow expected speed 85.000 got %.3f" % speed)
	target.set("slow_remaining", 0.4)
	orbit.call("on_hit_target", target)
	var refreshed_remaining := float(target.get("slow_remaining"))
	if not is_equal_approx(refreshed_remaining, 1.0):
		return _fail("Orbit slow refresh expected 1.000s remaining got %.3f" % refreshed_remaining)
	orbit.free()
	target.free()
	return true


func _assert_chainsaw_accepts_orbit_slow() -> bool:
	var orbit := _make_orbit()
	var target := _make_target()
	orbit.call("on_hit_target", target)
	CLOSE_CHAIN_RULES.apply_chainsaw_vulnerability(target, 1.15, 6.0)
	if not bool(target.call("has_damage_taken_multiplier_status", CLOSE_VULNERABILITY_STATUS_ID)):
		return _fail("Chainsaw did not accept Orbit slow as slowed condition")
	var value := float(target.call("get_damage_taken_multiplier_status_value", CLOSE_VULNERABILITY_STATUS_ID, 1.0))
	if not is_equal_approx(value, 1.15):
		return _fail("Chainsaw vulnerability after Orbit slow expected 1.15 got %.3f" % value)
	orbit.free()
	target.free()
	return true


func _cleanup() -> void:
	if _player_data != null:
		_player_data.set("player", null)
	if _player != null and is_instance_valid(_player):
		_player.free()


func _fail(message: String) -> bool:
	push_error("FAIL: Orbit close-chain slow integration: %s" % message)
	_cleanup()
	quit(1)
	return false
