extends SceneTree

const CLOSE_VULNERABILITY_STATUS_ID := &"close_vulnerability"
const CLOSE_CHAIN_RULES := preload("res://Player/Weapons/close_quarters_chain_rules.gd")

var _player: Node2D
var _player_data: Node
var _damage_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _setup_player_data():
		return
	_damage_manager = root.get_node_or_null("/root/DamageManager")
	if _damage_manager == null:
		_fail("missing DamageManager autoload")
		return
	if not _assert_dash_blade_applies_slow():
		return
	if not _assert_chainsaw_applies_vulnerability_only_to_slowed_targets():
		return
	if not await _assert_close_vulnerability_affects_player_sources_only():
		return
	if not await _assert_shotgun_same_volley_bonus_and_no_on_hit_recursion():
		return
	_cleanup()
	await process_frame
	print("PASS: close quarters chain Dash/Chainsaw/Shotgun")
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


func _make_target(hp_value: int = 100) -> Node2D:
	var scene := load("res://tests/fixtures/enemies/dps_test_dummy_enemy.tscn") as PackedScene
	var target := scene.instantiate() as Node2D
	target.set("max_hp_value", hp_value)
	target.set("hp", hp_value)
	target.global_position = Vector2(100.0, 0.0)
	root.add_child(target)
	return target


func _assert_dash_blade_applies_slow() -> bool:
	var target := _make_target()
	CLOSE_CHAIN_RULES.apply_dash_slow(target, 0.7, 3.0)
	if not bool(target.call("is_slowed")):
		return _fail("Dash Blade hit did not slow target")
	var speed := float(target.call("get_current_movement_speed"))
	var base_speed := float(target.get("movement_speed"))
	if not is_equal_approx(speed, base_speed * 0.7):
		return _fail("Dash Blade slow expected %.3f got %.3f" % [base_speed * 0.7, speed])
	target.free()
	return true


func _assert_chainsaw_applies_vulnerability_only_to_slowed_targets() -> bool:
	var normal_target := _make_target()
	CLOSE_CHAIN_RULES.apply_chainsaw_vulnerability(normal_target, 1.15, 6.0)
	if bool(normal_target.call("has_damage_taken_multiplier_status", CLOSE_VULNERABILITY_STATUS_ID)):
		return _fail("Chainsaw applied vulnerability to non-slowed target")
	var slowed_target := _make_target()
	slowed_target.call("apply_slow", 0.7, 3.0)
	CLOSE_CHAIN_RULES.apply_chainsaw_vulnerability(slowed_target, 1.15, 6.0)
	if not bool(slowed_target.call("has_damage_taken_multiplier_status", CLOSE_VULNERABILITY_STATUS_ID)):
		return _fail("Chainsaw did not apply vulnerability to slowed target")
	var value := float(slowed_target.call("get_damage_taken_multiplier_status_value", CLOSE_VULNERABILITY_STATUS_ID, 1.0))
	if not is_equal_approx(value, 1.15):
		return _fail("Chainsaw vulnerability expected 1.15 got %.3f" % value)
	CLOSE_CHAIN_RULES.apply_chainsaw_vulnerability(slowed_target, 1.15, 6.0)
	if not is_equal_approx(float(slowed_target.call("get_damage_taken_multiplier_status_value", CLOSE_VULNERABILITY_STATUS_ID, 1.0)), 1.15):
		return _fail("Chainsaw vulnerability stacked instead of refreshing")
	normal_target.free()
	slowed_target.free()
	return true


func _assert_close_vulnerability_affects_player_sources_only() -> bool:
	var target := _make_target(100)
	var weapon_source := Node2D.new()
	weapon_source.set_meta("player_weapon_damage_source", true)
	root.add_child(weapon_source)
	target.call("apply_damage_taken_multiplier_status", CLOSE_VULNERABILITY_STATUS_ID, 1.15, 6.0)
	var player_damage = _damage_manager.call(
		"build_damage_data",
		weapon_source,
		20,
		&"physical",
		{"amount": 0, "angle": Vector2.ZERO}
	)
	_damage_manager.call("apply_to_target", target, player_damage)
	if int(target.get("hp")) != 77:
		return _fail("player source vulnerability expected hp 77 got %d" % int(target.get("hp")))
	var enemy_damage = _damage_manager.call(
		"build_damage_data",
		null,
		20,
		&"physical",
		{"amount": 0, "angle": Vector2.ZERO}
	)
	_damage_manager.call("apply_to_target", target, enemy_damage)
	if int(target.get("hp")) != 57:
		return _fail("non-player source should not consume vulnerability, hp got %d" % int(target.get("hp")))
	await create_timer(0.1).timeout
	weapon_source.free()
	target.free()
	return true


func _assert_shotgun_same_volley_bonus_and_no_on_hit_recursion() -> bool:
	var target := _make_target(100)
	var weapon_source := Node2D.new()
	weapon_source.set_meta("player_weapon_damage_source", true)
	root.add_child(weapon_source)
	var hp_before := int(target.get("hp"))
	CLOSE_CHAIN_RULES.apply_final_bonus_damage(
		weapon_source,
		target,
		&"physical",
		20,
		0.25,
		&"shotgun_test_bonus"
	)
	if int(target.get("hp")) != hp_before - 5:
		return _fail("second Shotgun pellet expected 5 bonus damage, hp got %d" % int(target.get("hp")))
	target.call("apply_damage_taken_multiplier_status", CLOSE_VULNERABILITY_STATUS_ID, 1.15, 6.0)
	CLOSE_CHAIN_RULES.apply_final_bonus_damage(
		weapon_source,
		target,
		&"physical",
		20,
		0.25,
		&"shotgun_test_final_bonus"
	)
	if int(target.get("hp")) != hp_before - 10:
		return _fail("Shotgun final bonus should not be multiplied again, hp got %d" % int(target.get("hp")))
	await create_timer(0.1).timeout
	weapon_source.free()
	target.free()
	return true


func _cleanup() -> void:
	if _player_data != null:
		_player_data.set("player", null)
	if _player != null and is_instance_valid(_player):
		_player.free()


func _fail(message: String) -> bool:
	push_error("FAIL: Close quarters chain: %s" % message)
	_cleanup()
	quit(1)
	return false
