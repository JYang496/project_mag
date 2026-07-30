extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
var _failed := false

class DummyControlTarget:
	extends Node2D
	var received_statuses: Array[Dictionary] = []

	func apply_status_payload(status_id: StringName, payload: Dictionary) -> void:
		received_statuses.append({
			"id": status_id,
			"payload": payload.duplicate(true),
		})

class DummyDamageTarget:
	extends Node
	var hp: int = 100
	var accept_damage: bool = true

	func damaged(attack: Attack) -> bool:
		if not accept_damage:
			return false
		hp = maxi(hp - maxi(attack.damage, 0), 0)
		return true

class DummyHeatRatioPlayer:
	extends Node
	var heat_ratio: float = 0.0

	func get_total_heat_ratio() -> float:
		return heat_ratio

	func has_heat_prepared() -> bool:
		return false


func _ready() -> void:
	_validate_weapon_scenes()
	_validate_projectile_scenes()
	_validate_glacier_cold_snap()
	_validate_energy_hit_cycle()

	print("FAIL weapon runtime chain" if _failed else "PASS weapon runtime chain")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _validate_weapon_scenes() -> void:
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Instances"):
		if not file_name.ends_with(".tscn"):
			continue
		var scene_path := "res://Player/Weapons/Instances/%s" % file_name
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s must load" % file_name)
		if packed == null:
			continue
		var instance := packed.instantiate()
		_expect(instance is Weapon, "%s root must inherit Weapon" % file_name)
		if instance is Weapon:
			var weapon := instance as Weapon
			_expect(not weapon.has_weapon_active_skill(), "%s must not implement a weapon active skill" % file_name)
			var active_result := weapon.request_weapon_active()
			_expect(
				not bool(active_result.get("ok", true)) and str(active_result.get("reason", "")) == "unsupported",
				"%s must inherit the reserved unsupported weapon-active interface" % file_name
			)
		instance.free()


func _validate_projectile_scenes() -> void:
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Projectiles"):
		if not file_name.ends_with(".tscn"):
			continue
		var scene_path := "res://Player/Weapons/Projectiles/%s" % file_name
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s must load" % file_name)
		if packed == null:
			continue
		var instance := packed.instantiate()
		if instance is Projectile:
			_expect(instance.get_node_or_null("HitboxAnchor") != null, "%s must keep HitboxAnchor" % file_name)
			_expect(
				instance.get_node_or_null("CollisionArmingTimer") != null,
				"%s must keep CollisionArmingTimer" % file_name
			)
		instance.free()


func _validate_glacier_cold_snap() -> void:
	var packed := load("res://Player/Weapons/Instances/glacier_projector.tscn") as PackedScene
	var weapon := packed.instantiate() as Weapon
	weapon.force_skill_cooldowns_ready()
	_expect(str(weapon.get_passive_status().get("state", "")) == "armed", "Cold Snap must advertise that the next attack is armed")
	_expect(bool(weapon.call("_consume_cold_snap_for_next_attack")), "the first attack must consume the armed Cold Snap")
	_expect(not bool(weapon.call("_consume_cold_snap_for_next_attack")), "a second attack during recharge must not receive Cold Snap")

	var normal_target := DummyControlTarget.new()
	weapon.call("_apply_cold_snap_control", normal_target)
	_expect(normal_target.received_statuses.size() == 1, "Cold Snap must apply one control status to a normal enemy")
	if normal_target.received_statuses.size() == 1:
		var normal_status: Dictionary = normal_target.received_statuses[0]
		_expect(normal_status.get("id") == &"stun", "non-boss enemies must be frozen instead of slowed")
		_expect(is_equal_approx(float((normal_status.get("payload", {}) as Dictionary).get("duration", 0.0)), 1.0), "non-boss freeze must last one second")

	var elite_target := DummyControlTarget.new()
	elite_target.set_meta(&"is_elite", true)
	weapon.call("_apply_cold_snap_control", elite_target)
	_expect(elite_target.received_statuses.size() == 1 and elite_target.received_statuses[0].get("id") == &"stun", "elite enemies must use the same one-second freeze as normal enemies")

	var boss_target := DummyControlTarget.new()
	boss_target.set_meta(&"is_boss", true)
	weapon.call("_apply_cold_snap_control", boss_target)
	_expect(boss_target.received_statuses.size() == 1, "Cold Snap must apply one control status to a boss")
	if boss_target.received_statuses.size() == 1:
		var boss_status: Dictionary = boss_target.received_statuses[0]
		var boss_payload := boss_status.get("payload", {}) as Dictionary
		_expect(boss_status.get("id") == &"slow", "bosses must be slowed instead of frozen")
		_expect(is_equal_approx(float(boss_payload.get("multiplier", 0.0)), 0.5), "boss movement multiplier must be 50%")
		_expect(is_equal_approx(float(boss_payload.get("duration", 0.0)), 1.0), "boss slow must last one second")

	weapon.call("_update_cold_snap_recharge", 6.0)
	_expect(bool(weapon.call("_consume_cold_snap_for_next_attack")), "Cold Snap must rearm after six seconds")
	weapon.call("clear_timed_effects_for_prepare")
	_expect(bool(weapon.call("_consume_cold_snap_for_next_attack")), "a new battle prepare must restore Cold Snap")

	normal_target.free()
	elite_target.free()
	boss_target.free()
	weapon.free()


func _validate_energy_hit_cycle() -> void:
	var laser := (load("res://Player/Weapons/Instances/laser.tscn") as PackedScene).instantiate() as Weapon
	var charged := (load("res://Player/Weapons/Instances/charged_blaster.tscn") as PackedScene).instantiate() as Weapon
	var plasma := (load("res://Player/Weapons/Instances/plasma_lance.tscn") as PackedScene).instantiate() as Weapon
	for weapon in [laser, charged, plasma]:
		var status: Dictionary = weapon.get_passive_status()
		_expect(bool(status.get("energy_hit_cycle", false)), "%s must expose the shared energy-hit cycle" % weapon.name)
		_expect(int(status.get("required", 0)) == 5, "%s must require exactly five valid energy hits" % weapon.name)

	var target_a := DummyDamageTarget.new()
	var target_b := DummyDamageTarget.new()
	var data := _make_energy_hit_data(laser)
	for _index in range(3):
		DamageManager.apply_to_target_result(target_a, data)
	DamageManager.apply_to_target_result(target_b, data)
	_expect(laser.get_energy_hit_pulse_count() == 4, "different targets must each advance the same shared five-hit cycle")

	var suppressed := _make_energy_hit_data(laser)
	suppressed.suppress_reactive_effects = true
	DamageManager.apply_to_target_result(target_a, suppressed)
	_expect(laser.get_energy_hit_pulse_count() == 4, "reactive discharge damage must not recursively advance the cycle")

	var physical_data := _make_energy_hit_data(laser)
	physical_data.damage_type = Attack.TYPE_PHYSICAL
	DamageManager.apply_to_target_result(target_a, physical_data)
	_expect(laser.get_energy_hit_pulse_count() == 4, "physical damage must not advance an energy-hit cycle")

	target_a.accept_damage = false
	DamageManager.apply_to_target_result(target_a, data)
	_expect(laser.get_energy_hit_pulse_count() == 4, "rejected or zero damage must not advance the cycle")

	target_a.accept_damage = true
	DamageManager.apply_to_target_result(target_a, data)
	_expect(laser.get_energy_hit_pulse_count() == 0, "the fifth valid energy hit must discharge and immediately restart the cycle")
	DamageManager.apply_to_target_result(target_a, data)
	laser.clear_timed_effects_for_prepare()
	_expect(laser.get_energy_hit_pulse_count() == 0, "battle preparation must clear stale energy-hit progress")

	var branch_expectations := {
		"res://Player/Weapons/Branches/pistol_arc_branch.tscn": &"pistol_arc_energy_cycle",
		"res://Player/Weapons/Branches/orbit_energy_branch.tscn": &"orbit_energy_cycle",
		"res://Player/Weapons/Branches/cannon_zero_branch.tscn": &"cannon_zero_energy_cycle",
	}
	for scene_path in branch_expectations:
		var behavior := (load(scene_path) as PackedScene).instantiate() as WeaponBranchBehavior
		_expect(behavior.get_energy_hit_passive_id() == branch_expectations[scene_path], "%s must bind to its five-hit energy passive" % scene_path)
		behavior.free()

	var previous_player: Node = PlayerData.player
	var heat_player := DummyHeatRatioPlayer.new()
	PlayerData.player = heat_player
	heat_player.heat_ratio = 0.0
	_expect(is_equal_approx(float(plasma.call("_get_heat_damage_multiplier")), 1.0), "plasma must have no heat bonus at zero stored heat")
	heat_player.heat_ratio = 1.0
	_expect(is_equal_approx(float(plasma.call("_get_heat_damage_multiplier")), 1.75), "plasma must reach its full continuous damage bonus at full stored heat")
	PlayerData.player = previous_player
	heat_player.free()

	add_child(target_a)
	target_a.add_to_group("enemies")
	target_a.set_meta(DamagePipeline.DAMAGE_STATE_META, {"energy_damage_recorded": 50})
	var zero_behavior := (load("res://Player/Weapons/Branches/cannon_zero_branch.tscn") as PackedScene).instantiate() as WeaponBranchBehavior
	zero_behavior.setup(laser)
	var zero_result := DamageResult.new()
	zero_result.applied = true
	zero_result.final_damage = 1
	zero_result.damage_type = Attack.TYPE_ENERGY
	var zero_detail := zero_behavior.on_energy_hit_cycle_triggered(target_a, data, zero_result)
	_expect(int(zero_detail.get("consumed_recorded_damage", 0)) == 50, "Zero Burst must consume the struck target's recorded energy damage")
	_expect(DamagePipeline.get_recorded_energy_damage(target_a) == 0, "Zero Burst must clear the consumed energy-damage record")
	_expect(int(zero_detail.get("burst_damage", 0)) == 10, "Zero Burst must detonate 20% of the consumed record")
	zero_behavior.free()

	remove_child(target_a)
	target_a.free()
	target_b.free()
	laser.free()
	charged.free()
	plasma.free()


func _make_energy_hit_data(source_weapon: Weapon) -> DamageData:
	return DamageData.new().setup(
		1,
		Attack.TYPE_ENERGY,
		{"amount": 0, "angle": Vector2.ZERO},
		source_weapon,
		null,
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.PROJECTILE
	)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
