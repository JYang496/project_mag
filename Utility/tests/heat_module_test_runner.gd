extends Node

const TEST_WEAPON_SCENE := preload("res://Utility/tests/mocks/test_weapon.tscn")
const TEST_ENEMY_SCRIPT := preload("res://Utility/tests/mocks/test_enemy.gd")
const SHARED_HEAT_POOL_SCRIPT := preload("res://Player/Weapons/Heat/shared_heat_pool.gd")

const HEAT_CONCENTRATION_SCENE := preload("res://Player/Weapons/Modules/heat_concentration.tscn")
const HEAT_VENT_SCENE := preload("res://Player/Weapons/Modules/heat_vent.tscn")
const THERMAL_IGNITION_SCENE := preload("res://Player/Weapons/Modules/thermal_ignition.tscn")
const OVERHEAT_BOOST_SCENE := preload("res://Player/Weapons/Modules/overheat_boost.tscn")
const HEAT_CAPACITY_SCENE := preload("res://Player/Weapons/Modules/heat_capacity.tscn")

var _pass_count: int = 0
var _fail_count: int = 0

func _ready() -> void:
	await run_all_tests()

func run_all_tests() -> void:
	print("")
	print("========== Heat Module Test Runner ==========")
	await _test_heat_concentration_damage_scaling()
	await _test_heat_vent_dynamic_cooling()
	await _test_thermal_ignition_on_hit_and_unregistration()
	await _test_overheat_boost_damage_and_fire_gate()
	await _test_overheat_boost_is_weapon_local_under_shared_pool()
	await _test_heat_capacity_max_heat_multiplier()
	_print_summary()

func _test_heat_concentration_damage_scaling() -> void:
	var weapon := await _spawn_heat_weapon()
	var module := _instantiate_module(HEAT_CONCENTRATION_SCENE, "Heat Concentration")
	if module == null:
		await _teardown_weapon(weapon)
		return
	weapon.modules.add_child(module)
	await _wait_frames(2)
	weapon.lock_heat_value(50.0, 0.2)
	var projected: Dictionary = module.apply_stat_modifiers({"damage": 10.0})
	var expected := 12.5
	_assert_near(float(projected.get("damage", 0.0)), expected, 0.01, "Heat Concentration: 50% heat adds +25% damage")
	await _teardown_weapon(weapon)

func _test_heat_vent_dynamic_cooling() -> void:
	var weapon := await _spawn_heat_weapon()
	var module := _instantiate_module(HEAT_VENT_SCENE, "Heat Vent")
	if module == null:
		await _teardown_weapon(weapon)
		return
	weapon.modules.add_child(module)
	await _wait_frames(2)

	weapon.lock_heat_value(0.0, 0.2)
	var low_heat: Dictionary = module.apply_stat_modifiers({"heat_cool_rate": 20.0})
	weapon.lock_heat_value(100.0, 0.2)
	var high_heat: Dictionary = module.apply_stat_modifiers({"heat_cool_rate": 20.0})

	_assert_near(float(low_heat.get("heat_cool_rate", 0.0)), 20.0, 0.01, "Heat Vent: low heat keeps base cool rate")
	_assert_near(float(high_heat.get("heat_cool_rate", 0.0)), 30.0, 0.01, "Heat Vent: full heat reaches x1.5 cool rate")
	await _teardown_weapon(weapon)

func _test_thermal_ignition_on_hit_and_unregistration() -> void:
	var weapon := await _spawn_heat_weapon()
	var module := _instantiate_module(THERMAL_IGNITION_SCENE, "Thermal Ignition")
	if module == null:
		await _teardown_weapon(weapon)
		return
	weapon.modules.add_child(module)
	await _wait_frames(2)

	var enemy := TEST_ENEMY_SCRIPT.new() as TestEnemy
	add_child(enemy)
	weapon.on_hit_target(enemy)

	_assert_true(enemy.status_payloads.size() > 0, "Thermal Ignition: hit applies payload")
	if enemy.status_payloads.size() > 0:
		var payload_entry: Dictionary = enemy.status_payloads[0]
		_assert_eq_str(str(payload_entry.get("id", "")), "erosion", "Thermal Ignition: payload status id")
		var payload: Dictionary = payload_entry.get("payload", {})
		_assert_eq_int(int(payload.get("damage", 0)), 3, "Thermal Ignition: payload damage")
		_assert_eq_int(int(payload.get("tick", 0)), 3, "Thermal Ignition: payload duration ticks")

	module.queue_free()
	await _wait_frames(2)
	_assert_false(weapon.on_hit_plugins.has(module), "Thermal Ignition: plugin unregistered on exit")
	if is_instance_valid(enemy):
		enemy.queue_free()
	await _teardown_weapon(weapon)

func _test_overheat_boost_damage_and_fire_gate() -> void:
	var weapon := await _spawn_heat_weapon()
	weapon.configure_heat(60.0, 100.0, 5.0)
	var module := _instantiate_module(OVERHEAT_BOOST_SCENE, "Overheat Boost")
	if module == null:
		await _teardown_weapon(weapon)
		return
	weapon.modules.add_child(module)
	await _wait_frames(2)

	weapon.register_shot_heat(2.0)
	_assert_true(weapon.is_weapon_overheated(), "Overheat Boost: weapon enters overheat")
	var projected: Dictionary = module.apply_stat_modifiers({"damage": 10.0})
	_assert_near(float(projected.get("damage", 0.0)), 5.0, 0.01, "Overheat Boost: overheated damage multiplier applied")
	_assert_true(weapon.can_fire_with_heat(), "Overheat Boost: weapon can fire while overheated")

	await _wait_frames(2)
	_assert_true(weapon.is_weapon_overheated(), "Overheat Boost: overheat state remains active")
	_assert_true(weapon.can_fire_with_heat(), "Overheat Boost: firing remains enabled during overheat")
	await _teardown_weapon(weapon)

func _test_overheat_boost_is_weapon_local_under_shared_pool() -> void:
	var fake_player := Player.new()
	var pool := SHARED_HEAT_POOL_SCRIPT.new() as SharedHeatPool
	fake_player.set("_shared_heat_pool", pool)
	PlayerData.player = fake_player

	var weapon_a := TEST_WEAPON_SCENE.instantiate() as TestWeapon
	var weapon_b := TEST_WEAPON_SCENE.instantiate() as TestWeapon
	add_child(weapon_a)
	add_child(weapon_b)
	await _wait_frames(2)

	weapon_a.modules.weapon_traits = CombatTrait.traits_to_flags([CombatTrait.HEAT, CombatTrait.PROJECTILE])
	weapon_b.modules.weapon_traits = CombatTrait.traits_to_flags([CombatTrait.HEAT, CombatTrait.PROJECTILE])
	weapon_a.configure_heat(20.0, 100.0, 10.0)
	weapon_b.configure_heat(20.0, 100.0, 10.0)
	weapon_a.sync_stats()
	weapon_b.sync_stats()
	var overheat_module := _instantiate_module(OVERHEAT_BOOST_SCENE, "Overheat Boost (Shared Pool)")
	if overheat_module == null:
		await _teardown_weapon(weapon_a)
		await _teardown_weapon(weapon_b)
		PlayerData.player = null
		return
	weapon_a.modules.add_child(overheat_module)
	await _wait_frames(2)

	pool.configure_from_weapons([weapon_a, weapon_b])
	weapon_a.register_shot_heat(5.0)
	_assert_true(pool.overheated, "Overheat Boost (Shared): shared pool overheated")
	_assert_true(weapon_a.is_weapon_overheated(), "Overheat Boost (Shared): boosted weapon reads overheated")
	_assert_true(weapon_b.is_weapon_overheated(), "Overheat Boost (Shared): non-boosted weapon reads overheated")
	_assert_true(weapon_a.can_fire_with_heat(), "Overheat Boost (Shared): boosted weapon can fire")
	_assert_false(weapon_b.can_fire_with_heat(), "Overheat Boost (Shared): other heat weapon remains blocked")

	await _teardown_weapon(weapon_a)
	await _teardown_weapon(weapon_b)
	PlayerData.player = null

func _test_heat_capacity_max_heat_multiplier() -> void:
	var weapon := await _spawn_heat_weapon()
	var module := _instantiate_module(HEAT_CAPACITY_SCENE, "Heat Capacity")
	if module == null:
		await _teardown_weapon(weapon)
		return
	weapon.modules.add_child(module)
	await _wait_frames(2)
	weapon.sync_stats()
	await _wait_frames(1)

	_assert_near(float(weapon.heat_max_value), 150.0, 0.01, "Heat Capacity: runtime heat max increased to x1.5")
	await _teardown_weapon(weapon)

func _spawn_heat_weapon() -> TestWeapon:
	var weapon := TEST_WEAPON_SCENE.instantiate() as TestWeapon
	add_child(weapon)
	await _wait_frames(2)
	weapon.modules.weapon_traits = CombatTrait.traits_to_flags([CombatTrait.HEAT, CombatTrait.PROJECTILE])
	weapon.configure_heat(20.0, 100.0, 20.0)
	weapon.sync_stats()
	await _wait_frames(1)
	return weapon

func _teardown_weapon(weapon: TestWeapon) -> void:
	if weapon != null and is_instance_valid(weapon):
		weapon.queue_free()
	await _wait_frames(2)

func _instantiate_module(scene: PackedScene, label: String) -> Module:
	if scene == null:
		_assert_true(false, "%s: module scene preload failed" % label)
		return null
	var module := scene.instantiate() as Module
	_assert_true(module != null, "%s: scene instantiates Module" % label)
	return module

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % message)
	else:
		_fail_count += 1
		push_error("[FAIL] %s" % message)

func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)

func _assert_eq_int(actual: int, expected: int, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%d actual=%d)" % [message, expected, actual])

func _assert_eq_str(actual: String, expected: String, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%s actual=%s)" % [message, expected, actual])

func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s (expected=%.3f actual=%.3f)" % [message, expected, actual])

func _print_summary() -> void:
	print("")
	print("========== Heat Module Summary ==========")
	print("Passed: %d" % _pass_count)
	print("Failed: %d" % _fail_count)
	if _fail_count == 0:
		print("Result: PASS")
	else:
		print("Result: FAIL")

func _wait_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await get_tree().process_frame
