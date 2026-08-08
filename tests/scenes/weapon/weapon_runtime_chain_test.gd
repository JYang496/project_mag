extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const GLOBAL_ENERGY_POOL_SCRIPT := preload("res://Player/Mechas/scripts/player_global_weapon_energy_pool.gd")
const HUD_PRESENTER_SCRIPT := preload("res://UI/scripts/components/hud_presenter.gd")
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

	func add_global_weapon_energy(raw_gain: float, _source_attack: Node = null) -> float:
		var accepted := minf(maxf(raw_gain, 0.0), maximum - energy)
		energy += accepted
		return accepted

	func consume_all_global_weapon_energy() -> float:
		var consumed := energy
		energy = 0.0
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
	_validate_machine_gun_fuse_branch_visual()
	_validate_zero_cannon_fuse_branch_visual()
	_validate_overkill_modules()

	print("FAIL weapon runtime chain" if _failed else "PASS weapon runtime chain")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


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
	_expect(is_equal_approx(laser.get_energy_release_bonus_at_full(), 0.75), "balanced Laser must gain +75% damage at full energy")
	_expect(is_equal_approx(charged.get_energy_release_bonus_at_full(), 1.25), "release-focused Charged Blaster must gain +125% damage at full energy")
	_expect(is_equal_approx(plasma.get_energy_release_bonus_at_full(), 1.25), "release-focused Plasma Lance must gain +125% damage at full energy")

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
	_expect(is_equal_approx(float(release_state.get("spent", 0.0)), 100.0), "a full-energy attack must consume the complete pool before firing")
	_expect(energy_player.energy == 0.0, "full-energy preparation must empty the shared pool")
	_expect(is_equal_approx(float(release_state.get("multiplier", 1.0)), 1.75), "balanced Laser must gain +75% damage at full energy")
	_expect(laser.get_runtime_damage_value(100.0) == 175, "the full-energy multiplier must affect the actual runtime attack damage")
	var release_source := Node.new()
	laser.add_child(release_source)
	laser.apply_energy_release_marker(release_source)
	var release_data := _make_energy_hit_data(laser, energy_player)
	release_data.source_node = release_source
	DamageManager.apply_to_target_result(target_a, release_data)
	_expect(energy_player.energy == 0.0, "a release attack hit must not refill the global pool")
	laser.finish_energy_release_attack()
	release_source.free()

	energy_player.energy = 100.0
	var cross_weapon_release := charged.prepare_energy_release_attack()
	_expect(bool(cross_weapon_release.get("triggered", false)), "any energy weapon must be able to release a full pool accumulated by another weapon")
	_expect(is_equal_approx(float(cross_weapon_release.get("multiplier", 1.0)), 2.25), "release-focused Charged Blaster must gain +125% damage at full energy")
	charged.finish_energy_release_attack()

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
			_expect(is_equal_approx(behavior.get_energy_release_bonus_at_full(), 0.35), "Arc Pistol must use the accumulator +35% release bonus")
		elif scene_path.ends_with("orbit_energy_branch.tscn"):
			_expect(is_equal_approx(behavior.get_energy_gain_per_damage_event(), 8.0), "Energy Orbit must gain 8 energy per damage event")
			_expect(is_equal_approx(behavior.get_energy_release_bonus_at_full(), 0.35), "Energy Orbit must use the accumulator +35% release bonus")
		else:
			_expect(is_equal_approx(behavior.get_energy_gain_per_damage_event(), 10.0), "Zero Cannon must gain 10 energy per damage event")
			_expect(is_equal_approx(behavior.get_energy_release_bonus_at_full(), 1.50), "Zero Cannon must use the specialist +150% release bonus")
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
	_expect(is_equal_approx(zero_behavior.get_energy_release_bonus_at_full(), 1.5), "Zero Cannon must be a specialist release weapon")
	zero_behavior.free()

	target_a.free()
	energy_player.free()
	PlayerData.player = original_player
	laser.free()
	charged.free()
	plasma.free()


func _validate_global_energy_pool() -> void:
	var pool = GLOBAL_ENERGY_POOL_SCRIPT.new()
	pool.configure(100.0, 0.50, 0.75)
	var attack_a := Node.new()
	var attack_b := Node.new()
	_expect(is_equal_approx(pool.add_from_damage(80.0, attack_a), 50.0), "one attack must respect the 50% global-energy gain cap")
	_expect(is_equal_approx(pool.add_from_damage(20.0, attack_a), 0.0), "additional hits from the same attack must not bypass its gain cap")
	_expect(is_equal_approx(pool.add_from_damage(40.0, attack_b), 25.0), "all attacks together must respect the one-second gain cap")
	_expect(is_equal_approx(pool.energy_value, 75.0), "global energy must retain accepted gain without natural decay")
	_expect(is_equal_approx(pool.consume_all(), 75.0), "release must atomically consume the complete global pool")
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
		energy_player.energy = 100.0
		presenter.call("_sync_global_weapon_energy_meter")
		_expect(str(meter.get("_short_text")) == "READY", "the global energy HUD must clearly flag that the next energy attack will release")
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
