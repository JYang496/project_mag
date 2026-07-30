extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

class DummyHeatWeapon:
	extends Node
	var heat_cool_rate: float = 8.0
	func has_heat_trait() -> bool:
		return true

var _failed := false

func _ready() -> void:
	_test_signed_bounds_and_alignment()
	_test_neutralization_delay_and_lock()
	_test_fixed_shared_pool()
	_test_element_traits_imply_heat()
	print("FAIL bipolar heat" if _failed else "PASS bipolar heat")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _test_signed_bounds_and_alignment() -> void:
	var heat := Heat.new()
	_expect(is_zero_approx(heat.heat_value), "Heat must start at neutral zero")
	heat.add_heat_amount(40.0)
	_expect(is_equal_approx(heat.heat_value, 40.0), "fire Heat must move toward +100")
	_expect(is_equal_approx(heat.get_fire_alignment(), 0.4), "positive Heat must expose fire alignment")
	_expect(is_zero_approx(heat.get_freeze_alignment()), "positive Heat must not expose freeze alignment")
	heat.add_heat_amount(-70.0)
	_expect(is_equal_approx(heat.heat_value, -30.0), "cold must directly cancel heat and cross zero")
	_expect(is_equal_approx(heat.get_freeze_alignment(), 0.3), "negative Heat must expose freeze alignment")
	heat.add_heat_amount(-500.0)
	_expect(is_equal_approx(heat.heat_value, Heat.MIN_HEAT), "Heat must clamp at -100")
	heat.add_heat_amount(500.0)
	_expect(is_equal_approx(heat.heat_value, Heat.MAX_HEAT), "Heat must clamp at +100")
	_expect(is_equal_approx(heat.get_gauge_ratio(), 1.0), "gauge ratio must map +100 to the right endpoint")
	heat.reset_to_neutral()
	_expect(is_equal_approx(heat.get_gauge_ratio(), 0.5), "gauge ratio must map zero to the center")

func _test_neutralization_delay_and_lock() -> void:
	var heat := Heat.new()
	heat.configure(10.0, 999.0, 10.0)
	heat.add_heat_amount(-50.0)
	heat.neutralize(1.0)
	_expect(is_equal_approx(heat.heat_value, -50.0), "Heat must wait before returning to neutral")
	heat.neutralize(1.0)
	heat.neutralize(1.0)
	_expect(heat.heat_value > -50.0, "negative Heat must warm toward zero after the delay")
	heat.lock_to_value(-60.0, 1.0)
	heat.add_heat_amount(40.0)
	_expect(is_equal_approx(heat.heat_value, -60.0), "locked Heat must ignore signed changes")

func _test_fixed_shared_pool() -> void:
	var weapon_a := DummyHeatWeapon.new()
	var weapon_b := DummyHeatWeapon.new()
	add_child(weapon_a)
	add_child(weapon_b)
	var pool := SharedHeatPool.new()
	pool.configure_from_weapons([weapon_a, weapon_b], 8.0)
	_expect(pool.contributor_count == 2, "shared Heat must track contributing weapons")
	_expect(is_equal_approx(pool.max_heat, 100.0), "contributors and legacy multipliers must not expand the fixed bounds")
	pool.add_heat_amount(-125.0)
	_expect(is_equal_approx(pool.heat_value, -100.0), "shared Heat must preserve the negative bound")
	weapon_a.free()
	weapon_b.free()

func _test_element_traits_imply_heat() -> void:
	var fire_traits := WeaponTrait.normalize_array([WeaponTrait.FIRE])
	var freeze_traits := WeaponTrait.normalize_array([WeaponTrait.FREEZE])
	_expect(fire_traits.has(WeaponTrait.HEAT), "FIRE must imply HEAT")
	_expect(freeze_traits.has(WeaponTrait.HEAT), "FREEZE must imply HEAT")
	var physical_traits := WeaponTrait.normalize_array([WeaponTrait.PHYSICAL, WeaponTrait.HEAT])
	_expect(
		physical_traits.has(WeaponTrait.HEAT) and not physical_traits.has(WeaponTrait.FIRE),
		"HEAT must not imply FIRE"
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
