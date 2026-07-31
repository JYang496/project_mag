extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const PLAYER_STATUS_MODIFIER_SYSTEM := preload("res://Player/Mechas/scripts/player_status_modifier_system.gd")
const COMBAT_RESOURCE_METER := preload("res://UI/scripts/components/combat_resource_meter.gd")

class DummyHeatWeapon:
	extends Node
	var heat_cool_rate: float = 8.0
	func has_heat_trait() -> bool:
		return true

class DummyHeatPlayer:
	extends Node
	var signed_ratio: float = 0.0
	func get_cold_attack_speed_multiplier() -> float:
		return Player.cold_attack_speed_multiplier_for_ratio(signed_ratio)
	func get_cold_reload_duration_multiplier() -> float:
		return Player.cold_reload_duration_multiplier_for_ratio(signed_ratio)
	func get_heat_global_damage_additive(snapshot: Variant = null) -> float:
		var ratio := signed_ratio
		if snapshot is Dictionary:
			ratio = float((snapshot as Dictionary).get("signed_ratio", ratio))
		return Player.heat_global_damage_additive_for_ratio(ratio)
	func get_elemental_heat_damage_multiplier(damage_type: StringName, snapshot: Variant = null) -> float:
		if Attack.normalize_damage_type(damage_type) != Attack.TYPE_FIRE:
			return 1.0
		var ratio := signed_ratio
		if snapshot is Dictionary:
			ratio = float((snapshot as Dictionary).get("signed_ratio", ratio))
		return 1.0 + 0.30 * maxf(ratio, 0.0)
	func get_heat_prepared_fire_damage_multiplier() -> float:
		return 1.0

class SnapshotWeapon:
	extends Weapon
	var snapshot_ratio: float = 0.0
	var ordinary_multiplier: float = 1.0
	func get_signed_heat_ratio() -> float:
		return snapshot_ratio
	func get_total_ordinary_damage_multiplier() -> float:
		return ordinary_multiplier

var _failed := false

func _ready() -> void:
	_test_signed_bounds_and_alignment()
	_test_neutralization_delay_and_lock()
	_test_fixed_shared_pool()
	_test_element_traits_imply_heat()
	_test_heat_tradeoff_curve()
	_test_neutral_crossing_event()
	_test_attack_and_reload_speed()
	_test_additive_damage_formula()
	_test_attack_heat_snapshot()
	await _test_persistent_attack_snapshot()
	await _test_accessible_heat_hud()
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

func _test_heat_tradeoff_curve() -> void:
	var cases := [
		[-1.0, 0.0, 1.0, 1.10, 1.08],
		[-0.5, 0.0, 1.0, 1.05, 1.04],
		[0.0, 0.0, 1.0, 1.0, 1.0],
		[0.5, 0.05, 0.96, 1.0, 1.0],
		[1.0, 0.10, 0.92, 1.0, 1.0],
	]
	for values in cases:
		var ratio := float(values[0])
		_expect(is_equal_approx(Player.heat_global_damage_additive_for_ratio(ratio), float(values[1])), "hot damage curve must match its 10% cap")
		_expect(is_equal_approx(Player.heat_move_speed_multiplier_for_ratio(ratio), float(values[2])), "hot movement curve must match its 8% cap")
		_expect(is_equal_approx(Player.cold_attack_speed_multiplier_for_ratio(ratio), float(values[3])), "cold attack-speed curve must match its 10% cap")
		_expect(is_equal_approx(Player.cold_reload_duration_multiplier_for_ratio(ratio), float(values[4])), "cold reload curve must match its 8% cap")

func _test_neutral_crossing_event() -> void:
	var heat := Heat.new()
	var crossings: Array[Dictionary] = []
	heat.heat_crossed_neutral.connect(func(previous: float, current: float, direction: StringName) -> void:
		crossings.append({"previous": previous, "current": current, "direction": direction})
	)
	heat.set_heat(30.0)
	heat.set_heat(-20.0)
	_expect(crossings.size() == 1 and crossings[0].get("direction") == &"to_cold", "positive-to-negative Heat must emit one cold crossing")
	heat.set_heat(25.0)
	_expect(crossings.size() == 2 and crossings[1].get("direction") == &"to_hot", "negative-to-positive Heat must emit one hot crossing")
	heat.set_heat(0.0)
	heat.set_heat(-25.0)
	_expect(crossings.size() == 2, "touching or leaving neutral must not count as a crossing")
	heat.set_heat(25.0)
	_expect(crossings.size() == 3 and crossings[2].get("direction") == &"to_hot", "a later direct polarity crossing must emit once")
	heat.set_heat(-10.0)
	_expect(crossings.size() == 4 and crossings[3].get("direction") == &"to_cold", "a later reverse crossing must emit once")
	heat.reset_to_neutral()
	_expect(crossings.size() == 4, "resetting Heat to neutral must not emit a module trigger")

func _test_attack_and_reload_speed() -> void:
	var previous_player: Node = PlayerData.player
	var player := DummyHeatPlayer.new()
	player.signed_ratio = -1.0
	PlayerData.player = player
	var weapon := Weapon.new()
	var fire_controller := WeaponFireController.new()
	fire_controller.setup(weapon)
	_expect(is_equal_approx(fire_controller.get_effective_cooldown(1.0), 1.0 / 1.10), "full cold must shorten attack cooldown by a 1.10 speed multiplier")
	weapon.reload_duration_sec = 2.0
	_expect(is_equal_approx(weapon.ammo_controller.get_effective_reload_duration(), 2.16), "full cold must lengthen a two-second reload by 8%")
	player.signed_ratio = 1.0
	_expect(is_equal_approx(fire_controller.get_effective_cooldown(1.0), 1.0), "hot Heat must not change attack speed")
	_expect(is_equal_approx(weapon.ammo_controller.get_effective_reload_duration(), 2.0), "hot Heat must not change reload duration")
	weapon.free()
	player.free()
	PlayerData.player = previous_player

func _test_additive_damage_formula() -> void:
	var previous_crit_rate := float(PlayerData.total_crit_rate)
	PlayerData.total_crit_rate = 0.0
	var player := DummyHeatPlayer.new()
	add_child(player)
	player.signed_ratio = 1.0
	var modifiers = PLAYER_STATUS_MODIFIER_SYSTEM.new()
	modifiers.setup(player)
	modifiers.apply_damage_mul(&"bonus_a", 1.10)
	modifiers.apply_damage_mul(&"bonus_b", 1.20)
	var snapshot := {"signed_ratio": 1.0}
	var ordinary: OutgoingDamageResult = modifiers.compute_outgoing_damage_result(260, Attack.TYPE_FIRE, snapshot, 1.30)
	_expect(ordinary.damage == 400, "weapon, global, hot, and elemental ordinary bonuses must share one additive layer")
	var release: OutgoingDamageResult = modifiers.compute_outgoing_damage_result(455, Attack.TYPE_PHYSICAL, snapshot, 1.30)
	_expect(release.damage == 595, "a 1.75 energy release must remain multiplicative outside the ordinary additive layer")
	remove_child(player)
	player.free()
	PlayerData.total_crit_rate = previous_crit_rate

func _test_attack_heat_snapshot() -> void:
	var weapon := SnapshotWeapon.new()
	weapon.snapshot_ratio = 0.75
	weapon.ordinary_multiplier = 1.25
	var attack_source := Node.new()
	weapon.apply_heat_snapshot_marker(attack_source)
	weapon.snapshot_ratio = -1.0
	weapon.ordinary_multiplier = 2.0
	var snapshot: Dictionary = attack_source.get_meta(Weapon.HEAT_SNAPSHOT_META, {})
	_expect(is_equal_approx(float(snapshot.get("signed_ratio", 0.0)), 0.75), "an attack must preserve Heat from its generation moment")
	_expect(is_equal_approx(float(snapshot.get("weapon_ordinary_multiplier", 0.0)), 1.25), "an attack must preserve its ordinary-damage layer at generation")
	_expect(int(snapshot.get("captured_at_msec", 0)) > 0, "a Heat snapshot must identify when it was captured")
	attack_source.free()
	weapon.free()

func _test_persistent_attack_snapshot() -> void:
	var weapon := SnapshotWeapon.new()
	weapon.snapshot_ratio = 0.60
	weapon.ordinary_multiplier = 1.20
	var area := (load("res://Combat/area_effect/area_effect.tscn") as PackedScene).instantiate() as AreaEffect
	area.source_node = weapon
	area.source_category = DamageData.SOURCE_PLAYER_WEAPON
	area.duration = 5.0
	add_child(area)
	await get_tree().process_frame
	weapon.snapshot_ratio = -0.80
	weapon.ordinary_multiplier = 1.50
	var area_snapshot: Dictionary = area.heat_snapshot as Dictionary
	_expect(is_equal_approx(float(area_snapshot.get("signed_ratio", 0.0)), 0.60), "a persistent area must lock Heat when it is first generated")
	_expect(is_equal_approx(float(area_snapshot.get("weapon_ordinary_multiplier", 0.0)), 1.20), "a persistent area must lock its ordinary multiplier at generation")

	var trail := TrailAreaEffect.new()
	trail.auto_process = false
	trail.draw_enabled = false
	add_child(trail)
	var emitter := Node2D.new()
	emitter.set_meta(Weapon.HEAT_SNAPSHOT_META, {"signed_ratio": -0.40, "weapon_ordinary_multiplier": 1.10})
	add_child(emitter)
	trail.attach_emitter(emitter, 10.0)
	emitter.global_position = Vector2(30.0, 0.0)
	trail.step(0.10)
	var segments: Array = trail.get("_segments") as Array
	_expect(segments.size() == 1, "a moving attack must create one persistent trail segment")
	if segments.size() == 1:
		var trail_snapshot: Dictionary = (segments[0] as Dictionary).get("heat_snapshot", {}) as Dictionary
		_expect(is_equal_approx(float(trail_snapshot.get("signed_ratio", 0.0)), -0.40), "a trail segment must inherit the generating projectile's Heat")
	area.queue_free()
	trail.queue_free()
	emitter.queue_free()
	weapon.free()
	await get_tree().process_frame

func _test_accessible_heat_hud() -> void:
	var meter = COMBAT_RESOURCE_METER.new()
	add_child(meter)
	await get_tree().process_frame
	meter.set_resource(&"heat", 0.5, &"neutral", "+0", "neutral")
	var neutral: Dictionary = meter.get_heat_accessibility_state()
	_expect(str(neutral.get("cold_icon", "")).contains("C"), "Heat HUD must expose a cold icon independent of color")
	_expect(str(neutral.get("hot_icon", "")).contains("H"), "Heat HUD must expose a hot icon independent of color")
	_expect(str(neutral.get("zone", "")) != "", "Heat HUD must expose a textual neutral zone")
	meter.set_resource(&"heat", 0.85, &"high_heat", "+70", "hot")
	var rising: Dictionary = meter.get_heat_accessibility_state()
	_expect(rising.get("direction") == "▶", "rising Heat must expose a right-pointing direction cue")
	_expect(str(rising.get("zone", "")) != str(neutral.get("zone", "")), "hot and neutral zones must remain distinguishable without color")
	meter.set_resource(&"heat", 0.15, &"deep_cold", "-70", "cold")
	var falling: Dictionary = meter.get_heat_accessibility_state()
	_expect(falling.get("direction") == "◀", "falling Heat must expose a left-pointing direction cue")
	_expect(str(falling.get("zone", "")) != str(neutral.get("zone", "")), "cold and neutral zones must remain distinguishable without color")
	meter.queue_free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
