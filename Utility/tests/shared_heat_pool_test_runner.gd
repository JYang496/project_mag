extends Node

const TEST_WEAPON_SCENE := preload("res://Utility/tests/mocks/test_weapon.tscn")
const SHARED_HEAT_POOL_SCRIPT := preload("res://Player/Weapons/Heat/shared_heat_pool.gd")
const THERMAL_CANNON_SCENE := preload("res://Player/Weapons/thermal_cannon.tscn")
const GATLING_THERMAL_SCENE := preload("res://Player/Weapons/gatling_thermal.tscn")
const HEAT_SINK_BURST_SCENE := preload("res://Player/Weapons/heat_sink_burst.tscn")
const PLASMA_LANCE_SCENE := preload("res://Player/Weapons/plasma_lance.tscn")

var _pass_count: int = 0
var _fail_count: int = 0

func _ready() -> void:
	await run_all_tests()

func run_all_tests() -> void:
	print("")
	print("========== Shared Heat Pool Test Runner ==========")
	await _test_pool_aggregation_math()
	await _test_shared_accumulation_across_weapons()
	await _test_overheat_gates_all_heat_weapons()
	await _test_lock_semantics_through_weapon_api()
	await _test_new_heat_weapon_pool_aggregation()
	await _test_new_heat_weapon_overheat_and_recovery()
	_print_summary()

func _test_pool_aggregation_math() -> void:
	var ctx := await _build_fixture(40.0, 7.5, 60.0, 12.5)
	var pool: SharedHeatPool = ctx.pool
	_assert_near(pool.max_heat, 100.0, 0.001, "Aggregation: max heat sums across contributors")
	_assert_near(pool.cooldown_rate, 20.0, 0.001, "Aggregation: cooldown rate sums across contributors")
	_assert_eq_int(pool.contributor_count, 2, "Aggregation: contributor count tracks heat weapons")
	await _teardown_fixture(ctx)

func _test_shared_accumulation_across_weapons() -> void:
	var ctx := await _build_fixture(50.0, 10.0, 70.0, 14.0)
	var pool: SharedHeatPool = ctx.pool
	var weapon_a: TestWeapon = ctx.weapon_a
	var weapon_b: TestWeapon = ctx.weapon_b

	weapon_a.register_shot_heat()
	weapon_b.register_shot_heat()
	var expected: float = 12.0
	_assert_near(pool.heat_value, expected, 0.001, "Accumulation: both weapons add to one shared value")
	_assert_near(weapon_a.get_heat_value(), expected, 0.001, "Accumulation: weapon A reads shared value")
	_assert_near(weapon_b.get_heat_value(), expected, 0.001, "Accumulation: weapon B reads shared value")
	await _teardown_fixture(ctx)

func _test_overheat_gates_all_heat_weapons() -> void:
	var ctx := await _build_fixture(20.0, 10.0, 20.0, 10.0)
	var pool: SharedHeatPool = ctx.pool
	var weapon_a: TestWeapon = ctx.weapon_a
	var weapon_b: TestWeapon = ctx.weapon_b

	# Force pool heat above max (40) so shared overheat lockout must engage.
	weapon_a.register_shot_heat(4.0)
	weapon_b.register_shot_heat(4.0)
	_assert_true(pool.overheated, "Overheat: shared pool overheats once max heat reached")
	_assert_false(weapon_a.can_fire_with_heat(), "Overheat: weapon A blocked while pool overheated")
	_assert_false(weapon_b.can_fire_with_heat(), "Overheat: weapon B blocked while pool overheated")

	# Cool part-way so heat stays above zero and overheat lockout should still apply.
	pool.cool_down(1.0)
	_assert_false(weapon_a.can_fire_with_heat(), "Overheat: still blocked above zero heat")
	_assert_false(weapon_b.can_fire_with_heat(), "Overheat: both remain blocked above zero heat")

	# Finish cooldown to zero, which should clear overheat and unblock firing.
	pool.cool_down(2.0)
	_assert_true(pool.heat_value <= 0.001, "Overheat: pool cooled back to zero")
	_assert_true(weapon_a.can_fire_with_heat(), "Overheat: weapon A unblocks at near-zero heat")
	_assert_true(weapon_b.can_fire_with_heat(), "Overheat: weapon B unblocks at near-zero heat")
	await _teardown_fixture(ctx)

func _test_lock_semantics_through_weapon_api() -> void:
	var ctx := await _build_fixture(60.0, 10.0, 40.0, 6.0)
	var pool: SharedHeatPool = ctx.pool
	var weapon_a: TestWeapon = ctx.weapon_a
	var weapon_b: TestWeapon = ctx.weapon_b

	weapon_a.lock_heat_value(30.0, 2.0)
	_assert_near(pool.heat_value, 30.0, 0.001, "Lock: lock_heat_value sets shared pool value")
	weapon_b.register_shot_heat(3.0)
	_assert_near(pool.heat_value, 30.0, 0.001, "Lock: heat additions ignored while lock is active")

	pool.cool_down(1.0)
	_assert_near(pool.heat_value, 30.0, 0.001, "Lock: cool_down holds locked value until expiry")

	pool.cool_down(1.1)
	weapon_b.register_shot_heat()
	_assert_true(pool.heat_value > 30.0, "Lock: heat can increase after lock expires")
	await _teardown_fixture(ctx)

func _test_new_heat_weapon_pool_aggregation() -> void:
	var ctx := await _build_new_weapons_fixture()
	var pool: SharedHeatPool = ctx.pool
	var weapons: Array = ctx.weapons

	_assert_eq_int(pool.contributor_count, 4, "New weapons: all 4 heat weapons contribute to shared pool")
	_assert_near(pool.max_heat, 400.0, 0.001, "New weapons: shared max heat aggregates to 400")
	_assert_near(pool.cooldown_rate, 90.0, 0.001, "New weapons: shared cooldown rate aggregates to 90")

	for weapon_variant in weapons:
		var weapon := weapon_variant as Weapon
		_assert_true(weapon != null, "New weapons: instantiated weapon is valid")
		if weapon == null:
			continue
		_assert_true(weapon.has_heat_trait(), "New weapons: weapon has HEAT trait -> %s" % weapon.name)
		_assert_true(weapon.can_fire_with_heat(), "New weapons: weapon starts able to fire -> %s" % weapon.name)

	await _teardown_new_weapons_fixture(ctx)

func _test_new_heat_weapon_overheat_and_recovery() -> void:
	var ctx := await _build_new_weapons_fixture()
	var pool: SharedHeatPool = ctx.pool
	var weapons: Array = ctx.weapons

	var total_shot_heat := 0.0
	for weapon_variant in weapons:
		var weapon := weapon_variant as Weapon
		if weapon == null:
			continue
		total_shot_heat += float(weapon.heat_per_shot)
	_assert_near(total_shot_heat, 40.5, 0.001, "New weapons: total per-volley heat is expected (40.5)")

	# 10 volleys exceed 400 max heat (10 * 40.5 = 405) and must overheat the shared pool.
	for _i in range(10):
		for weapon_variant in weapons:
			var weapon := weapon_variant as Weapon
			if weapon == null:
				continue
			weapon.register_shot_heat()

	_assert_true(pool.overheated, "New weapons: shared pool overheats after sustained combined fire")
	_assert_true(pool.heat_value >= pool.max_heat - 0.001, "New weapons: pool heat clamps at shared max")
	for weapon_variant in weapons:
		var weapon := weapon_variant as Weapon
		if weapon == null:
			continue
		_assert_false(weapon.can_fire_with_heat(), "New weapons: firing blocked while shared pool overheated -> %s" % weapon.name)

	# Partial cooldown while heat > 0 should keep overheat lockout.
	pool.cool_down(1.0)
	for weapon_variant in weapons:
		var weapon := weapon_variant as Weapon
		if weapon == null:
			continue
		_assert_false(weapon.can_fire_with_heat(), "New weapons: still blocked while shared heat remains above zero -> %s" % weapon.name)

	# Cool to zero; overheat state should clear for all.
	pool.cool_down(10.0)
	_assert_true(pool.heat_value <= 0.001, "New weapons: pool fully cools to zero")
	for weapon_variant in weapons:
		var weapon := weapon_variant as Weapon
		if weapon == null:
			continue
		_assert_true(weapon.can_fire_with_heat(), "New weapons: firing restored after full cooldown -> %s" % weapon.name)

	await _teardown_new_weapons_fixture(ctx)

func _build_fixture(a_max: float, a_cool: float, b_max: float, b_cool: float) -> Dictionary:
	var fake_player := Player.new()
	var pool := SHARED_HEAT_POOL_SCRIPT.new() as SharedHeatPool
	fake_player.set("_shared_heat_pool", pool)
	PlayerData.player = fake_player

	var weapon_a := TEST_WEAPON_SCENE.instantiate() as TestWeapon
	var weapon_b := TEST_WEAPON_SCENE.instantiate() as TestWeapon
	add_child(weapon_a)
	add_child(weapon_b)
	await _wait_frames(2)

	var heat_flag := CombatTrait.traits_to_flags([CombatTrait.HEAT])
	(weapon_a.modules as WeaponModules).weapon_traits = heat_flag
	(weapon_b.modules as WeaponModules).weapon_traits = heat_flag
	weapon_a.configure_heat(5.0, a_max, a_cool)
	weapon_b.configure_heat(7.0, b_max, b_cool)
	pool.configure_from_weapons([weapon_a, weapon_b])

	return {
		"player": fake_player,
		"pool": pool,
		"weapon_a": weapon_a,
		"weapon_b": weapon_b,
	}

func _build_new_weapons_fixture() -> Dictionary:
	var fake_player := Player.new()
	var pool := SHARED_HEAT_POOL_SCRIPT.new() as SharedHeatPool
	fake_player.set("_shared_heat_pool", pool)
	PlayerData.player = fake_player

	var thermal := THERMAL_CANNON_SCENE.instantiate() as Weapon
	var gatling := GATLING_THERMAL_SCENE.instantiate() as Weapon
	var burst := HEAT_SINK_BURST_SCENE.instantiate() as Weapon
	var lance := PLASMA_LANCE_SCENE.instantiate() as Weapon

	var weapons: Array[Weapon] = []
	for weapon in [thermal, gatling, burst, lance]:
		if weapon != null:
			add_child(weapon)
			weapons.append(weapon)

	await _wait_frames(3)
	pool.configure_from_weapons(weapons)

	return {
		"player": fake_player,
		"pool": pool,
		"weapons": weapons,
	}

func _teardown_fixture(ctx: Dictionary) -> void:
	for key in ["weapon_a", "weapon_b", "player"]:
		var node_variant: Variant = ctx.get(key)
		if node_variant is Node:
			var node_ref := node_variant as Node
			if node_ref != null and is_instance_valid(node_ref):
				if node_ref.get_parent() != null:
					node_ref.queue_free()
				else:
					node_ref.free()
	PlayerData.player = null
	await _wait_frames(2)

func _teardown_new_weapons_fixture(ctx: Dictionary) -> void:
	var weapons_variant: Variant = ctx.get("weapons", [])
	if weapons_variant is Array:
		for weapon_variant in weapons_variant:
			if weapon_variant is Node:
				var weapon_node := weapon_variant as Node
				if weapon_node != null and is_instance_valid(weapon_node):
					if weapon_node.get_parent() != null:
						weapon_node.queue_free()
					else:
						weapon_node.free()

	var player_variant: Variant = ctx.get("player")
	if player_variant is Node:
		var player_node := player_variant as Node
		if player_node != null and is_instance_valid(player_node):
			player_node.free()

	PlayerData.player = null
	await _wait_frames(2)

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % message)
	else:
		_fail_count += 1
		push_error("[FAIL] %s" % message)

func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)

func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_assert_true(absf(actual - expected) <= tolerance, "%s (expected=%.3f actual=%.3f)" % [message, expected, actual])

func _assert_eq_int(actual: int, expected: int, message: String) -> void:
	_assert_true(actual == expected, "%s (expected=%d actual=%d)" % [message, expected, actual])

func _print_summary() -> void:
	print("")
	print("========== Shared Heat Pool Summary ==========")
	print("Passed: %d" % _pass_count)
	print("Failed: %d" % _fail_count)
	if _fail_count == 0:
		print("Result: PASS")
	else:
		print("Result: FAIL")

func _wait_frames(frame_count: int) -> void:
	for _i in range(frame_count):
		await get_tree().process_frame
