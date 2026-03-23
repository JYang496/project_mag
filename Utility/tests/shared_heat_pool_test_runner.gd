extends Node

const TEST_WEAPON_SCENE := preload("res://Utility/tests/mocks/test_weapon.tscn")
const SHARED_HEAT_POOL_SCRIPT := preload("res://Player/Weapons/Heat/shared_heat_pool.gd")

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
