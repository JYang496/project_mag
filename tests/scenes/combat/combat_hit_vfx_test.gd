extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PROFILE := preload("res://Combat/Vfx/combat_hit_vfx_profile.gd")
const SERVICE := preload("res://Combat/Vfx/combat_hit_vfx_service.gd")

var _failed := false


func _ready() -> void:
	_test_profile_semantics()
	await _test_pool_budget_and_reuse()
	print("FAIL: combat hit vfx" if _failed else "PASS: combat hit vfx")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _test_profile_semantics() -> void:
	_expect(is_equal_approx(SERVICE.EFFECT_SCALE_MULTIPLIER, 0.75), "hit impact visuals must use the reduced global scale")
	var light := DamageResult.new()
	light.final_damage = 5
	light.damage_type = Attack.TYPE_PHYSICAL
	_expect(PROFILE.from_damage_result(light, 100).hit_type == PROFILE.HitType.KINETIC_LIGHT, "small physical damage must use light kinetic feedback")
	var heavy := DamageResult.new()
	heavy.final_damage = 20
	heavy.damage_type = Attack.TYPE_PHYSICAL
	_expect(PROFILE.from_damage_result(heavy, 100).hit_type == PROFILE.HitType.KINETIC_HEAVY, "large physical damage must use heavy kinetic feedback")
	var energy := DamageResult.new()
	energy.final_damage = 5
	energy.damage_type = Attack.TYPE_ENERGY
	_expect(PROFILE.from_damage_result(energy, 100).hit_type == PROFILE.HitType.ENERGY, "energy damage must use cyan energy feedback")
	energy.is_critical = true
	_expect(PROFILE.from_damage_result(energy, 100).hit_type == PROFILE.HitType.CRITICAL_HIT, "critical must take visual priority over damage type")
	for type in PROFILE.HitType.values():
		var profile := PROFILE.create(type)
		_expect(profile.duration_sec >= 0.08 and profile.duration_sec <= 0.24, "all hit profiles must remain short-lived")


func _test_pool_budget_and_reuse() -> void:
	var service := SERVICE.new()
	add_child(service)
	var profile := PROFILE.create(PROFILE.HitType.KINETIC_HEAVY)
	for index in range(SERVICE.MAX_ACTIVE_EFFECTS + 8):
		service.play(Vector2(index, index), profile)
	_expect(service.get_node_or_null("GroundDamageDecalService") == null, "enemy hit feedback must not create persistent ground circles")
	_expect(get_tree().get_nodes_in_group(&"ground_damage_decal_service").is_empty(), "enemy hits must not register a ground decal service")
	var saturated := service.get_pool_metrics()
	_expect(int(saturated.active) == SERVICE.MAX_ACTIVE_EFFECTS, "active hit effects must respect the 32-effect budget")
	_expect(int(saturated.pooled) == SERVICE.MAX_ACTIVE_EFFECTS, "overflow hits must recycle instead of allocating")
	# Allow one scheduling margin beyond the 80-240ms profile contract so a
	# headless frame boundary cannot masquerade as a lifecycle leak.
	await get_tree().create_timer(0.30).timeout
	var settled := service.get_pool_metrics()
	_expect(int(settled.active) == 0, "short hit effects must return to the pool")
	service.play(Vector2.ZERO, profile)
	_expect(int(service.get_pool_metrics().pooled) == SERVICE.MAX_ACTIVE_EFFECTS, "second-use hit feedback must reuse the existing pool")
	service.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
