extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const GLOBAL_ENERGY_POOL_SCRIPT := preload("res://Player/Mechas/scripts/player_global_weapon_energy_pool.gd")
const HUD_PRESENTER_SCRIPT := preload("res://UI/scripts/components/hud_presenter.gd")
const RETURN_ON_TIMEOUT_SCRIPT := preload("res://Player/Weapons/Effects/return_on_timeout.gd")
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

class DummyAuthoritativeDamageTarget:
	extends Node
	var hp: int = 10
	var max_hp: int = 10
	var is_dead: bool = false

	func read_hp() -> int:
		return hp

	func write_hp(value: int) -> void:
		hp = value

	func read_max_hp() -> int:
		return max_hp

	func read_dead() -> bool:
		return is_dead

	func write_dead(value: bool) -> void:
		is_dead = value

	func damaged(attack: Attack) -> DamageResult:
		var profile := DamageProfile.new()
		profile.use_damage_reduction = false
		profile.use_armor = false
		profile.get_hp = Callable(self, "read_hp")
		profile.set_hp = Callable(self, "write_hp")
		profile.get_max_hp = Callable(self, "read_max_hp")
		profile.get_is_dead = Callable(self, "read_dead")
		profile.set_is_dead = Callable(self, "write_dead")
		return DamagePipeline.new().apply_incoming_damage(self, attack, profile)

	func get_health_ratio() -> float:
		return float(hp) / float(maxi(max_hp, 1))

class DummyBeam:
	extends Node
	var damage: int = 155

class DummyVulnerabilityTarget:
	extends Node
	var applications: int = 0
	var last_multiplier: float = 1.0
	var last_duration: float = 0.0

	func apply_damage_taken_multiplier_status(_id: StringName, multiplier: float, duration: float) -> void:
		applications += 1
		last_multiplier = multiplier
		last_duration = duration

class DummyHeatRatioPlayer:
	extends Node
	var heat_ratio: float = 0.0

	func get_total_heat_ratio() -> float:
		return heat_ratio

	func has_heat_prepared() -> bool:
		return false

class DummyGlobalEnergyPlayer:
	extends Node
	var energy: float = 0.0
	var maximum: float = 100.0
	var heat_value: float = 0.0

	func add_global_weapon_energy(raw_gain: float, _source_attack: Node = null) -> float:
		var accepted := minf(maxf(raw_gain, 0.0), maximum - energy)
		energy += accepted
		return accepted

	func consume_all_global_weapon_energy() -> float:
		var consumed := energy
		energy = 0.0
		return consumed

	func consume_global_weapon_energy(amount: float) -> float:
		var consumed := minf(maxf(amount, 0.0), energy)
		energy -= consumed
		return consumed

	func get_total_heat_ratio() -> float:
		return clampf(heat_value / 100.0, 0.0, 1.0)

	func consume_shared_heat(amount: float) -> float:
		var consumed := minf(maxf(amount, 0.0), heat_value)
		heat_value -= consumed
		return consumed

	func get_global_weapon_energy_max() -> float:
		return maximum

	func get_global_weapon_energy() -> float:
		return energy

	func has_equipped_energy_weapon() -> bool:
		return true

	func is_global_weapon_energy_ready() -> bool:
		return energy >= maximum - 0.001


func _ready() -> void:
	_validate_enemy_query_contract()
	_validate_weapon_scenes()
	_validate_projectile_scenes()
	_validate_glacier_cold_snap()
	_validate_global_energy_pool()
	_validate_global_energy_hud()
	_validate_full_energy_fire_cycle()
	_validate_secondary_weapon_branches()
	_validate_machine_gun_fuse_branch_visual()
	_validate_zero_cannon_fuse_branch_visual()
	_validate_overkill_modules()
	_validate_return_on_timeout_without_linear_module()

	print("FAIL weapon runtime chain" if _failed else "PASS weapon runtime chain")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _validate_return_on_timeout_without_linear_module() -> void:
	var projectile := Projectile.new()
	projectile.base_displacement = Vector2(240.0, -180.0)
	var effect := RETURN_ON_TIMEOUT_SCRIPT.new()
	effect.projectile = projectile
	_expect(bool(effect.call("_capture_and_stop_projectile")), "return timeout must stop authoritative projectile motion without a LinearMovement node")
	_expect(projectile.base_displacement == Vector2.ZERO, "return timeout must stop the outbound projectile at its timeout")
	_expect(effect.get("saved_displacement") == Vector2(240.0, -180.0), "return timeout must preserve the outbound displacement")
	_expect(is_equal_approx(float(effect.get("return_speed")), 300.0), "return timeout must preserve outbound speed for the return leg")
	effect.projectile = null
	_expect(not bool(effect.call("_capture_and_stop_projectile")), "return timeout must safely ignore an unavailable projectile")
	effect.free()
	projectile.free()


func _validate_machine_gun_fuse_branch_visual() -> void:
	DataHandler.load_weapon_branch_data()
	var weapon := (load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene).instantiate() as Weapon
	add_child(weapon)
	var base_texture := weapon.sprite.texture
	weapon.fuse = 2
	_expect(weapon.sprite.texture == base_texture, "machine-gun fuse alone must retain its base visual until a branch is selected")
	_expect(weapon.branch_runtime.add_branch("gatling_mg"), "machine-gun fuse 2 must accept the Gatling branch")
	_expect(
		weapon.sprite.texture != null and weapon.sprite.texture.resource_path == "res://asset/images/weapons/mg2.png",
		"Gatling machine-gun branch must apply its evolved weapon visual"
	)
	weapon.branch_runtime.clear_branch_behaviors()
	_expect(weapon.sprite.texture == base_texture, "removing the Gatling branch must restore the fuse base visual")
	weapon.queue_free()


func _validate_zero_cannon_fuse_branch_visual() -> void:
	DataHandler.load_weapon_branch_data()
	var weapon := (load("res://Player/Weapons/Instances/cannon.tscn") as PackedScene).instantiate() as Weapon
	add_child(weapon)
	var base_texture := weapon.sprite.texture
	weapon.fuse = 2
	_expect(weapon.sprite.texture == base_texture, "cannon fuse alone must retain its base visual until a branch is selected")
	_expect(weapon.branch_runtime.add_branch("zero_cannon_branch"), "cannon fuse 2 must accept the Zero Cannon branch")
	_expect(
		weapon.sprite.texture != null and weapon.sprite.texture.resource_path == "res://asset/images/weapons/cannon3.png",
		"Zero Cannon branch must apply its evolved weapon visual"
	)
	weapon.branch_runtime.clear_branch_behaviors()
	_expect(weapon.sprite.texture == base_texture, "removing the Zero Cannon branch must restore the fuse base visual")
	weapon.queue_free()


func _validate_enemy_query_contract() -> void:
	var registered := Node2D.new()
	registered.global_position = Vector2(24.0, 12.0)
	add_child(registered)
	EnemyRegistry.register_enemy(registered)
	var unregistered_group_member := Node2D.new()
	unregistered_group_member.global_position = Vector2(28.0, 12.0)
	unregistered_group_member.add_to_group(&"enemies")
	add_child(unregistered_group_member)
	var nearby := WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), Vector2(24.0, 12.0), 16.0)
	_expect(nearby == [registered], "weapon radius queries must use EnemyRegistry as the authoritative source")
	var in_rect := WeaponModuleRuntimeUtils.get_enemies_in_rect(get_tree(), Rect2(Vector2(20.0, 8.0), Vector2(12.0, 8.0)))
	_expect(in_rect == [registered], "weapon rectangle queries must use EnemyRegistry as the authoritative source")
	EnemyRegistry.unregister_enemy(registered)
	registered.queue_free()
	unregistered_group_member.queue_free()

	var weapon_root := "res://Player/Weapons"
	var pending: Array[String] = [weapon_root]
	while not pending.is_empty():
		var directory: String = pending.pop_back()
		for child_directory in DirAccess.get_directories_at(directory):
			pending.append("%s/%s" % [directory, child_directory])
		for file_name in DirAccess.get_files_at(directory):
			if not file_name.ends_with(".gd"):
				continue
			var source := FileAccess.get_file_as_string("%s/%s" % [directory, file_name])
			_expect(
				not (source.contains("get_nodes_in_group") and source.contains("enemies")),
				"%s must not scan the enemies group in a weapon hot path" % file_name
			)


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
			_expect((instance as Weapon).is_passive_ready(), "%s passive charge should initialize ready" % file_name)
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


func _validate_full_energy_fire_cycle() -> void:
	var laser := (load("res://Player/Weapons/Instances/laser.tscn") as PackedScene).instantiate() as Weapon
	var charged := (load("res://Player/Weapons/Instances/charged_blaster.tscn") as PackedScene).instantiate() as Weapon
	var plasma := (load("res://Player/Weapons/Instances/plasma_lance.tscn") as PackedScene).instantiate() as Weapon
	var target_a := DummyDamageTarget.new()
	var energy_player := DummyGlobalEnergyPlayer.new()
	var original_player: Node = PlayerData.player
	PlayerData.player = energy_player
	for weapon in [laser, charged, plasma]:
		var status: Dictionary = weapon.get_passive_status()
		_expect(bool(status.get("energy_full_fire_cycle", false)), "%s must expose the full-energy fire cycle" % weapon.name)
		_expect(int(status.get("required", 0)) == 100, "%s must use the global pool maximum as its only trigger condition" % weapon.name)
		_expect(status.get("trigger_hint") == "fire_at_full_global_energy", "%s must trigger by firing while the global pool is full" % weapon.name)
	_expect(is_equal_approx(laser.get_energy_gain_per_damage_event(), 6.0), "balanced Laser must gain 6 global energy per damage event")
	_expect(is_equal_approx(charged.get_energy_gain_per_damage_event(), 3.0), "release-focused Charged Blaster must gain 3 global energy per damage event")
	_expect(is_equal_approx(plasma.get_energy_gain_per_damage_event(), 10.0), "slow release-focused Plasma Lance must gain 10 global energy per damage event")
	_expect(is_equal_approx(laser.get_energy_release_bonus_at_full(), 0.30), "Laser focus channel must use a +30% sustained multiplier")
	_expect(is_equal_approx(charged.get_energy_release_bonus_at_full(), 0.55), "Charged Blaster resonance must start at +55% before same-target ramp")
	_expect(is_equal_approx(plasma.get_energy_release_bonus_at_full(), 0.55), "Plasma discharge must start at +55% before Heat scaling")

	var lethal_target := DummyAuthoritativeDamageTarget.new()
	var lethal_data := _make_energy_hit_data(laser, energy_player, 100)
	var lethal_result := DamageManager.apply_to_target_result(lethal_target, lethal_data)
	_expect(lethal_result.final_damage == 100, "a lethal energy hit must retain its full resolved damage")
	_expect(lethal_result.health_damage == 10, "a lethal energy hit must expose only the consumed enemy HP")
	_expect(lethal_result.overkill_damage == 90, "a lethal energy hit must expose overkill separately")
	_expect(is_equal_approx(energy_player.energy, 6.0), "overkill must still grant exactly one fixed Laser energy event")
	lethal_target.free()
	energy_player.energy = 0.0

	var data := _make_energy_hit_data(laser, energy_player, 50)
	DamageManager.apply_to_target_result(target_a, data)
	_expect(is_equal_approx(energy_player.energy, 6.0), "one Laser damage event must grant a fixed 6 energy regardless of damage")
	var laser_status: Dictionary = laser.get_passive_status()
	_expect(is_equal_approx(float(laser_status.get("progress", 0.0)), 0.06), "weapon skill status must mirror the global energy ratio")
	var suppressed := _make_energy_hit_data(laser, energy_player)
	suppressed.suppress_reactive_effects = true
	DamageManager.apply_to_target_result(target_a, suppressed)
	_expect(is_equal_approx(energy_player.energy, 6.0), "reactive damage must not add global energy")

	var physical_data := _make_energy_hit_data(laser, energy_player)
	physical_data.damage_type = Attack.TYPE_PHYSICAL
	DamageManager.apply_to_target_result(target_a, physical_data)
	_expect(is_equal_approx(energy_player.energy, 6.0), "physical damage must not add global energy")

	target_a.accept_damage = false
	DamageManager.apply_to_target_result(target_a, data)
	_expect(is_equal_approx(energy_player.energy, 6.0), "rejected damage must not add global energy")

	target_a.accept_damage = true
	energy_player.energy = 99.0
	_expect(not bool(laser.get_passive_status().get("ready", true)), "99 energy must not advertise the full-energy skill as ready")
	var below_full_state := laser.prepare_energy_release_attack()
	_expect(not bool(below_full_state.get("triggered", true)), "99 energy must not trigger a full-energy attack")
	_expect(is_equal_approx(energy_player.energy, 99.0), "firing below full energy must not consume the pool")
	_expect(is_equal_approx(float(below_full_state.get("multiplier", 0.0)), 1.0), "firing below full energy must remain unmodified")
	laser.finish_energy_release_attack()

	energy_player.energy = 100.0
	_expect(bool(laser.get_passive_status().get("ready", false)), "100 energy must advertise the next attack as ready")
	var release_state := laser.prepare_energy_release_attack()
	_expect(bool(release_state.get("triggered", false)), "firing with a full pool must trigger the energy skill without a hit counter")
	_expect(is_equal_approx(float(release_state.get("spent", -1.0)), 0.0), "Laser focus must defer energy spending instead of emptying the pool at attack start")
	_expect(energy_player.energy == 100.0, "Laser focus must begin with the full shared pool available for channel drain")
	_expect(release_state.get("release_mode") == &"focus_channel", "Laser must identify its release as a focus channel")
	_expect(is_equal_approx(float(release_state.get("multiplier", 1.0)), 1.30), "Laser focus must apply its sustained +30% multiplier")
	_expect(laser.get_runtime_damage_value(100.0) == 130, "Laser focus multiplier must affect actual runtime attack damage")
	laser.call("_update_focus_channel", 1.25)
	_expect(is_equal_approx(energy_player.energy, 50.0), "half of the Laser focus duration must drain half of the shared pool")
	var release_source := Node.new()
	laser.add_child(release_source)
	laser.apply_energy_release_marker(release_source)
	var release_data := _make_energy_hit_data(laser, energy_player)
	release_data.source_node = release_source
	DamageManager.apply_to_target_result(target_a, release_data)
	_expect(is_equal_approx(energy_player.energy, 50.0), "a focus-channel attack hit must not refill its draining global pool")
	laser.call("_update_focus_channel", 1.25)
	_expect(is_equal_approx(energy_player.energy, 0.0), "the completed Laser focus duration must drain the remaining pool")
	laser.finish_energy_release_attack()
	release_source.free()

	energy_player.energy = 100.0
	var cross_weapon_release := charged.prepare_energy_release_attack()
	_expect(bool(cross_weapon_release.get("triggered", false)), "any energy weapon must be able to release a full pool accumulated by another weapon")
	_expect(is_equal_approx(float(cross_weapon_release.get("multiplier", 1.0)), 1.55), "Charged Blaster must begin resonance at +55% before repeated-hit ramp")
	charged.finish_energy_release_attack()

	energy_player.energy = 100.0
	energy_player.heat_value = 80.0
	var plasma_release := plasma.prepare_energy_release_attack()
	_expect(plasma_release.get("release_mode") == &"heat_exchange", "Plasma Lance must identify its release as a Heat exchange")
	_expect(is_equal_approx(float(plasma_release.get("multiplier", 0.0)), 2.11), "Plasma discharge must scale its energy multiplier from the pre-spend Heat snapshot")
	_expect(is_equal_approx(float(plasma_release.get("heat_spent", 0.0)), 35.0), "Plasma discharge must spend 35 shared Heat")
	_expect(is_equal_approx(energy_player.heat_value, 45.0), "Plasma Heat exchange must reduce the authoritative shared Heat pool")
	plasma.finish_energy_release_attack()

	energy_player.energy = 100.0
	laser.prepare_energy_release_attack()
	var grouped_source_a := Node.new()
	var grouped_source_b := Node.new()
	laser.add_child(grouped_source_a)
	laser.add_child(grouped_source_b)
	laser.apply_energy_release_marker(grouped_source_a)
	laser.apply_energy_release_marker(grouped_source_b)
	var first_attack_group: Variant = grouped_source_a.get_meta(&"_global_energy_attack_group", null)
	_expect(first_attack_group != null and first_attack_group == grouped_source_b.get_meta(&"_global_energy_attack_group", null), "all child sources spawned by one attack must share one energy-cap group")
	laser.finish_energy_release_attack()
	laser.prepare_energy_release_attack()
	var grouped_source_c := Node.new()
	laser.add_child(grouped_source_c)
	laser.apply_energy_release_marker(grouped_source_c)
	_expect(grouped_source_c.get_meta(&"_global_energy_attack_group", null) != first_attack_group, "a later player attack must receive a new energy-cap group")
	laser.finish_energy_release_attack()
	grouped_source_a.free()
	grouped_source_b.free()
	grouped_source_c.free()

	var branch_expectations := {
		"res://Player/Weapons/Branches/pistol_arc_branch.tscn": &"pistol_arc_energy_cycle",
		"res://Player/Weapons/Branches/orbit_energy_branch.tscn": &"orbit_energy_cycle",
		"res://Player/Weapons/Branches/cannon_zero_branch.tscn": &"cannon_zero_energy_cycle",
	}
	for scene_path in branch_expectations:
		var behavior := (load(scene_path) as PackedScene).instantiate() as WeaponBranchBehavior
		_expect(behavior.get_energy_full_fire_passive_id() == branch_expectations[scene_path], "%s must bind to its full-energy fire passive" % scene_path)
		if scene_path.ends_with("pistol_arc_branch.tscn") or scene_path.ends_with("orbit_energy_branch.tscn"):
			_expect(behavior.get_damage_type_override() == Attack.TYPE_ENERGY, "%s must convert its direct hits to energy damage" % scene_path)
		if scene_path.ends_with("pistol_arc_branch.tscn"):
			_expect(is_equal_approx(behavior.get_energy_gain_per_damage_event(), 12.0), "Arc Pistol must gain 12 energy per damage event")
			_expect(is_equal_approx(behavior.get_energy_release_bonus_at_full(), 0.15), "Arc Pistol must retain only a small direct bonus before chain discharge")
		elif scene_path.ends_with("orbit_energy_branch.tscn"):
			_expect(is_equal_approx(behavior.get_energy_gain_per_damage_event(), 8.0), "Energy Orbit must gain 8 energy per damage event")
			_expect(is_equal_approx(behavior.get_energy_release_bonus_at_full(), 0.0), "Energy Orbit must spend its release on deployment rather than direct damage")
			var deployment: Dictionary = behavior.call("get_energy_deployment_config")
			_expect(int(deployment.get("extra_satellites", 0)) == 2, "Energy Orbit release must deploy two extra satellites")
		else:
			_expect(is_equal_approx(behavior.get_energy_gain_per_damage_event(), 10.0), "Zero Cannon must gain 10 energy per damage event")
			_expect(is_equal_approx(behavior.get_energy_release_bonus_at_full(), 1.0), "Zero Cannon must trade part of its old direct multiplier for a secondary impact")
		behavior.free()
	var branch_weapon_cases := [
		{
			"scene": "res://Player/Weapons/Instances/pistol.tscn",
			"branch": "arc_coil",
			"gain": 12.0,
		},
		{
			"scene": "res://Player/Weapons/Instances/orbit.tscn",
			"branch": "energy_orbit",
			"gain": 8.0,
		},
		{
			"scene": "res://Player/Weapons/Instances/cannon.tscn",
			"branch": "zero_cannon_branch",
			"gain": 10.0,
		},
	]
	for branch_case in branch_weapon_cases:
		var branch_weapon := (load(str(branch_case["scene"])) as PackedScene).instantiate() as Weapon
		branch_weapon.fuse = 2
		_expect(branch_weapon.branch_runtime.add_branch(str(branch_case["branch"])), "%s must attach its energy branch" % str(branch_case["scene"]))
		_expect(is_equal_approx(branch_weapon.get_energy_gain_per_damage_event(), float(branch_case["gain"])), "%s must route its fixed per-event gain through Weapon" % str(branch_case["branch"]))
		_expect(bool(branch_weapon.get_energy_full_fire_status().get("energy_full_fire_cycle", false)), "%s must use the shared full-energy fire rule" % str(branch_case["branch"]))
		branch_weapon.free()

	var previous_player: Node = PlayerData.player
	var heat_player := DummyHeatRatioPlayer.new()
	PlayerData.player = heat_player
	heat_player.heat_ratio = 0.0
	_expect(is_equal_approx(float(plasma.call("_get_heat_damage_multiplier")), 1.0), "plasma must have no heat bonus at zero stored heat")
	heat_player.heat_ratio = 1.0
	_expect(is_equal_approx(float(plasma.call("_get_heat_damage_multiplier")), 1.75), "plasma must reach its full continuous damage bonus at full stored heat")
	PlayerData.player = previous_player
	heat_player.free()

	var zero_behavior := (load("res://Player/Weapons/Branches/cannon_zero_branch.tscn") as PackedScene).instantiate() as WeaponBranchBehavior
	zero_behavior.setup(laser)
	_expect(is_equal_approx(zero_behavior.get_energy_gain_per_damage_event(), 10.0), "Zero Cannon must gain fixed energy per damage event")
	_expect(is_equal_approx(zero_behavior.get_energy_release_bonus_at_full(), 1.0), "Zero Cannon must use a 2x direct release before its secondary impact")
	zero_behavior.free()

	var resonance_target := Node.new()
	var resonance_beam := DummyBeam.new()
	resonance_beam.set_meta(&"_energy_resonance_base_damage", 155)
	resonance_beam.set_meta(&"_energy_resonance_step_damage", 14.0)
	resonance_beam.set_meta(&"_energy_resonance_hit_count", 0)
	resonance_beam.set_meta(&"_energy_resonance_target_id", 0)
	for _hit in range(5):
		charged.call("_update_energy_resonance_ramp", resonance_target, {"energy_resonance": true}, resonance_beam)
	_expect(resonance_beam.damage == 225, "Charged Blaster repeated-hit resonance must ramp from 1.55x to 2.25x")
	resonance_target.free()
	resonance_beam.free()

	target_a.free()
	energy_player.free()
	PlayerData.player = original_player
	laser.free()
	charged.free()
	plasma.free()


func _validate_secondary_weapon_branches() -> void:
	DataHandler.load_weapon_branch_data()
	var dash_options := DataHandler.read_weapon_branch_options("res://Player/Weapons/Instances/dash_blade.tscn", 2)
	var shotgun_options := DataHandler.read_weapon_branch_options("res://Player/Weapons/Instances/shotgun.tscn", 2)
	_expect(dash_options.size() == 2, "Dash Blade must expose Frost and Returning Execution branches")
	_expect(shotgun_options.size() == 2, "Shotgun must expose Shatter and Double Breach branches")

	var dash := (load("res://Player/Weapons/Instances/dash_blade.tscn") as PackedScene).instantiate() as Weapon
	add_child(dash)
	dash.fuse = 2
	_expect(dash.branch_runtime.add_branch("dash_return_execute"), "Dash Blade must attach Returning Execution")
	_expect(is_equal_approx(dash.branch_runtime.get_branch_damage_multiplier(), 0.90), "Returning Execution must pay its 10% outbound damage cost")
	var dash_behavior := dash.branch_runtime.get_branch_behaviors()[0]
	_expect(bool(dash_behavior.call("wants_dash_return_hitbox")), "Returning Execution must enable the return hitbox")
	var execute_target := DummyAuthoritativeDamageTarget.new()
	execute_target.hp = 100
	execute_target.max_hp = 100
	add_child(execute_target)
	dash_behavior.call("on_dash_cycle_started")
	dash_behavior.call("on_dash_target_hit", execute_target, false)
	dash_behavior.call("on_dash_return_started")
	dash_behavior.call("on_dash_target_hit", execute_target, true)
	_expect(execute_target.hp < 100, "Returning Execution must apply bonus damage when the return hits the outbound target")
	execute_target.free()
	dash.free()

	var shotgun := (load("res://Player/Weapons/Instances/shotgun.tscn") as PackedScene).instantiate() as Weapon
	add_child(shotgun)
	shotgun.fuse = 2
	_expect(shotgun.branch_runtime.add_branch("shotgun_double_breach"), "Shotgun must attach Double Breach")
	_expect(shotgun.get_primary_fire_ammo_cost() == 2, "Double Breach must declare a two-ammo attack cost")
	_expect(is_equal_approx(shotgun.branch_runtime.get_branch_projectile_damage_multiplier(), 0.65), "each Double Breach pellet wave must use reduced damage")
	var double_config: Dictionary = shotgun.call("_get_double_volley_config")
	_expect(is_equal_approx(float(double_config.get("second_wave_delay_sec", 0.0)), 0.12), "Double Breach must schedule its delayed second wave")
	_expect(float(double_config.get("second_spread_multiplier", 1.0)) < 1.0, "Double Breach second wave must be tighter than the first")
	var shotgun_behavior := shotgun.branch_runtime.get_branch_behaviors()[0]
	var vulnerability_target := DummyVulnerabilityTarget.new()
	shotgun_behavior.call("apply_double_breach_vulnerability", vulnerability_target, 7)
	shotgun_behavior.call("apply_double_breach_vulnerability", vulnerability_target, 7)
	_expect(vulnerability_target.applications == 1, "Double Breach must apply vulnerability at most once per target per volley")
	_expect(is_equal_approx(vulnerability_target.last_multiplier, 1.15), "Double Breach vulnerability must use the configured 1.15 multiplier")
	vulnerability_target.free()
	shotgun.free()


func _validate_global_energy_pool() -> void:
	var pool = GLOBAL_ENERGY_POOL_SCRIPT.new()
	pool.configure(100.0, 0.50, 0.75)
	var attack_a := Node.new()
	var attack_b := Node.new()
	_expect(is_equal_approx(pool.add_from_damage(80.0, attack_a), 50.0), "one attack must respect the 50% global-energy gain cap")
	_expect(is_equal_approx(pool.add_from_damage(20.0, attack_a), 0.0), "additional hits from the same attack must not bypass its gain cap")
	_expect(is_equal_approx(pool.add_from_damage(40.0, attack_b), 25.0), "all attacks together must respect the one-second gain cap")
	_expect(is_equal_approx(pool.energy_value, 75.0), "global energy must retain accepted gain without natural decay")
	_expect(is_equal_approx(pool.consume(25.0), 25.0), "focus-channel drain must support partial authoritative consumption")
	_expect(is_equal_approx(pool.energy_value, 50.0), "partial energy consumption must retain the unspent pool")
	_expect(is_equal_approx(pool.consume_all(), 50.0), "instant releases must atomically consume the remaining global pool")
	_expect(is_equal_approx(pool.energy_value, 0.0), "consuming the pool must clear it")
	pool.add_from_damage(10.0)
	pool.clear()
	_expect(is_equal_approx(pool.energy_value, 0.0), "battle lifecycle clear must empty the pool")
	var grouped_pool = GLOBAL_ENERGY_POOL_SCRIPT.new()
	grouped_pool.configure(100.0, 0.50, 0.75)
	var grouped_attack_a := Node.new()
	var grouped_attack_b := Node.new()
	grouped_attack_a.set_meta(&"_global_energy_attack_group", &"test_attack")
	grouped_attack_b.set_meta(&"_global_energy_attack_group", &"test_attack")
	_expect(is_equal_approx(grouped_pool.add_from_damage(30.0, grouped_attack_a), 30.0), "the first child source must gain energy for its attack group")
	_expect(is_equal_approx(grouped_pool.add_from_damage(30.0, grouped_attack_b), 20.0), "different child sources in one player attack must share the 50-energy cap")
	grouped_pool.set("_gain_window_started_msec", Time.get_ticks_msec() - 1001)
	_expect(is_equal_approx(grouped_pool.add_from_damage(10.0, grouped_attack_b), 0.0), "an attack cap must persist when a long attack crosses the one-second gain window")
	attack_a.free()
	attack_b.free()
	grouped_attack_a.free()
	grouped_attack_b.free()


func _validate_overkill_modules() -> void:
	var source_weapon := (load("res://Player/Weapons/Instances/laser.tscn") as PackedScene).instantiate() as Weapon
	add_child(source_weapon)
	var target := Node.new()
	target.add_to_group(&"enemies")
	add_child(target)
	var result := DamageResult.new()
	result.applied = true
	result.killed = true
	result.final_damage = 100
	result.health_damage = 10
	result.overkill_damage = 90
	var recovery = (load("res://Player/Weapons/Modules/wmod_overkill_recovery.tscn") as PackedScene).instantiate()
	source_weapon.get_node("Modules").add_child(recovery)
	source_weapon.on_damage_applied(target, DamageData.new(), result)
	_expect(
		is_equal_approx(source_weapon.get_total_external_damage_mul(), 1.30),
		"Overkill Recovery must consume explicit overkill damage and apply its level-one cap"
	)
	recovery.call("clear_damage_buff")
	recovery.free()
	var previous_bonus_shield := int(PlayerData.bonus_shield)
	var vampiric = (load("res://Player/Weapons/Modules/wmod_vampiric_surge.tscn") as PackedScene).instantiate()
	source_weapon.get_node("Modules").add_child(vampiric)
	source_weapon.on_damage_applied(target, DamageData.new(), result)
	_expect(
		int(PlayerData.bonus_shield) > previous_bonus_shield,
		"Vampiric Surge must consume explicit overkill damage without reading negative target HP"
	)
	vampiric.call("_clear_all_shield")
	vampiric.free()
	target.queue_free()
	source_weapon.queue_free()


func _validate_global_energy_hud() -> void:
	var original_player: Node = PlayerData.player
	var energy_player := DummyGlobalEnergyPlayer.new()
	energy_player.energy = 42.0
	PlayerData.player = energy_player
	var hud_root := Control.new()
	add_child(hud_root)
	var presenter = HUD_PRESENTER_SCRIPT.new()
	presenter.character_hud_root = hud_root
	presenter.call("_sync_global_weapon_energy_meter")
	var meter: Control = presenter.global_weapon_energy_meter as Control
	_expect(meter != null and meter.visible, "the Heat-HUD-style global energy meter must appear while an energy weapon is equipped")
	if meter != null:
		_expect(is_equal_approx(float(meter.call("get_ratio")), 0.42), "the global energy HUD must display the player-wide pool ratio")
		_expect(StringName(str(meter.get("_state"))) == &"normal", "the global energy HUD must remain static while charging")
		energy_player.energy = 100.0
		presenter.call("_sync_global_weapon_energy_meter")
		_expect(str(meter.get("_short_text")) == "READY", "the global energy HUD must clearly flag that the next energy attack will release")
		_expect(StringName(str(meter.get("_state"))) == &"normal", "the ready global energy HUD must not pulse")
	PlayerData.player = original_player
	hud_root.queue_free()
	energy_player.free()


func _make_energy_hit_data(source_weapon: Weapon, source_player: Node = null, damage_amount: int = 1) -> DamageData:
	var data := DamageData.new().setup(
		damage_amount,
		Attack.TYPE_ENERGY,
		{"amount": 0, "angle": Vector2.ZERO},
		source_weapon,
		source_player,
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.PROJECTILE
	)
	return data

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
