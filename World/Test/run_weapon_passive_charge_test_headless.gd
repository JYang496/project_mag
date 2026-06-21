extends Node

const PISTOL_SCENE := preload("res://Player/Weapons/Instances/pistol.tscn")
const SHOTGUN_SCENE := preload("res://Player/Weapons/Instances/shotgun.tscn")
const PROJECTILE_SCENE := preload("res://Player/Weapons/Projectiles/projectile.tscn")
const PASSIVE_MATRIX_PATH := "res://docs/weapon_passive_contract_matrix.md"
const REQUIRED_STATUS_FIELDS: Array[String] = [
	"id",
	"display_name",
	"state",
	"progress",
	"ready",
	"trigger_hint",
	"refresh_hint",
	"charge_current",
	"charge_max",
	"charge_based",
]
const PASSIVE_CHARGE_CONTRACTS := [
	{"scene": "res://Player/Weapons/Instances/cannon.tscn", "charges": 1, "matrix_key": "Cannon"},
	{"scene": "res://Player/Weapons/Instances/chainsaw_launcher.tscn", "charges": 1, "matrix_key": "Chainsaw"},
	{"scene": "res://Player/Weapons/Instances/charged_blaster.tscn", "charges": 3, "matrix_key": "Charged Blaster"},
	{"scene": "res://Player/Weapons/Instances/dash_blade.tscn", "charges": 1, "matrix_key": "Dash Blade"},
	{"scene": "res://Player/Weapons/Instances/flamethrower.tscn", "charges": 1, "matrix_key": "Flamethrower"},
	{"scene": "res://Player/Weapons/Instances/glacier_projector.tscn", "charges": 1, "matrix_key": "Glacier Projector"},
	{"scene": "res://Player/Weapons/Instances/laser.tscn", "charges": 1, "matrix_key": "Laser"},
	{"scene": "res://Player/Weapons/Instances/machine_gun.tscn", "charges": 1, "matrix_key": "Machine Gun"},
	{"scene": "res://Player/Weapons/Instances/orbit.tscn", "charges": 1, "matrix_key": "Orbit"},
	{"scene": "res://Player/Weapons/Instances/pistol.tscn", "charges": 3, "matrix_key": "Auto Pistol"},
	{"scene": "res://Player/Weapons/Instances/plasma_lance.tscn", "charges": 1, "matrix_key": "Plasma Lance"},
	{"scene": "res://Player/Weapons/Instances/rocket_launcher.tscn", "charges": 3, "matrix_key": "Rocket Launcher"},
	{"scene": "res://Player/Weapons/Instances/shotgun.tscn", "charges": 3, "matrix_key": "Shotgun"},
	{"scene": "res://Player/Weapons/Instances/sniper.tscn", "charges": 3, "matrix_key": "Sniper"},
	{"scene": "res://Player/Weapons/Instances/spear_launcher.tscn", "charges": 1, "matrix_key": "Spear Launcher"},
]

class FakePlayer:
	extends Node2D

	var heat_expansion_calls := 0
	var heat_prepared_calls := 0
	var plasma_feedback_calls := 0

	func apply_heat_expansion(_duration_sec: float, _max_heat_mul: float) -> bool:
		heat_expansion_calls += 1
		return true

	func apply_heat_prepared(_duration_sec: float, _damage_mul: float, _flat_damage_bonus: int) -> void:
		heat_prepared_calls += 1

	func apply_plasma_lance_heat_feedback(_duration_sec: float, _low_gain_mul: float, _high_gain_mul: float, _threshold: float) -> void:
		plasma_feedback_calls += 1

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.BATTLE
	if not await _assert_all_weapon_passives_are_charge_based():
		return
	var shotgun := SHOTGUN_SCENE.instantiate() as Weapon
	if shotgun == null:
		_fail("Failed to instantiate Shotgun.")
		return
	get_tree().root.add_child(shotgun)
	await get_tree().process_frame
	shotgun.set_weapon_role("main")
	_assert_equal(3, shotgun.get_passive_max_charges(), "Shotgun should expose 3 passive charges.")
	_assert_equal(3, shotgun.passive_controller.get_passive_charge_current(), "Shotgun should start full.")
	shotgun.notify_offhand_skill_triggered(0.0)
	_assert_equal(2, shotgun.passive_controller.get_passive_charge_current(), "First trigger should consume 1 charge.")
	_assert_true(shotgun.is_offhand_skill_ready(), "Shotgun should stay ready while charges remain.")
	shotgun.notify_offhand_skill_triggered(0.0)
	shotgun.notify_offhand_skill_triggered(0.0)
	_assert_equal(0, shotgun.passive_controller.get_passive_charge_current(), "Third trigger should leave 0 charges.")
	_assert_false(shotgun.is_offhand_skill_ready(), "Shotgun should stop triggering at 0 charges.")
	shotgun.refresh_passive_on_reload()
	_assert_equal(3, shotgun.passive_controller.get_passive_charge_current(), "Reload refresh should restore all charges.")
	_assert_true(shotgun.is_offhand_skill_ready(), "Reload refresh should make Shotgun ready again.")
	var player_node := FakePlayer.new()
	player_node.name = "PassiveChargeTestPlayer"
	player_node.global_position = Vector2.ZERO
	get_tree().root.add_child(player_node)
	PlayerData.player = player_node
	var close_target := Node2D.new()
	close_target.name = "CloseTarget"
	close_target.global_position = Vector2(64.0, 0.0)
	get_tree().root.add_child(close_target)
	shotgun.set_weapon_role("offhand")
	shotgun.call("_try_trigger_close_hit", close_target)
	_assert_equal(2, shotgun.passive_controller.get_passive_charge_current(), "Offhand Shotgun should consume a charge from its own close-hit trigger.")

	var pistol := PISTOL_SCENE.instantiate() as Weapon
	if pistol == null:
		_fail("Failed to instantiate Auto Pistol.")
		return
	get_tree().root.add_child(pistol)
	await get_tree().process_frame
	pistol.set_weapon_role("main")
	_assert_equal(3, pistol.get_passive_max_charges(), "Auto Pistol should expose 3 passive charges.")
	pistol.call("_update_pierce_mark_window", 8.0)
	_assert_equal(2, pistol.passive_controller.get_passive_charge_current(), "Auto Pistol periodic window should consume 1 charge.")
	pistol.call("_update_pierce_mark_window", 3.0)
	pistol.call("notify_offhand_skill_triggered", 0.0)
	pistol.call("notify_offhand_skill_triggered", 0.0)
	pistol.call("_update_pierce_mark_window", 8.0)
	_assert_equal(0, pistol.passive_controller.get_passive_charge_current(), "Auto Pistol should not open a new window at 0 charges.")
	pistol.call("_update_pierce_mark_window", 3.0)
	var pistol_status := pistol.call("get_passive_status") as Dictionary
	_assert_equal_string("waiting_refresh", str(pistol_status.get("state", "")), "Auto Pistol final charge window should expire before waiting for reload.")
	pistol.refresh_passive_on_reload()
	_assert_equal(3, pistol.passive_controller.get_passive_charge_current(), "Auto Pistol reload refresh should restore all charges.")

	if not await _assert_first_batch_weapon_behaviors(player_node):
		return
	if not await _assert_second_batch_weapon_behaviors(player_node):
		return
	if not await _assert_third_batch_weapon_behaviors(player_node):
		return

	print("WeaponPassiveChargeTest: PASS")
	shotgun.queue_free()
	pistol.queue_free()
	player_node.queue_free()
	close_target.queue_free()
	get_tree().quit(0)

func _assert_first_batch_weapon_behaviors(player_node: FakePlayer) -> bool:
	var sniper := _instantiate_weapon("res://Player/Weapons/Instances/sniper.tscn")
	if sniper == null:
		return false
	await get_tree().process_frame
	var far_target := _make_target("SniperFarTarget", Vector2(float(sniper.get("far_hit_trigger_distance")) + 24.0, 0.0))
	sniper.call("_try_trigger_far_hit", far_target)
	if int(sniper.passive_controller.get_passive_charge_current()) != 2:
		_fail("Sniper far-hit trigger should consume 1 of 3 charges.")
		return false
	sniper.refresh_passive_on_reload()
	if int(sniper.passive_controller.get_passive_charge_current()) != 3:
		_fail("Sniper reload refresh should restore all charges.")
		return false
	var far_damage_target := _make_damage_target("SniperFarDamageTarget", Vector2(float(sniper.get("attack_range")), 0.0), 1000)
	await get_tree().process_frame
	var hp_before := int(far_damage_target.get("hp"))
	var sniper_projectile := load("res://Player/Weapons/Projectiles/sniper_projectile.tscn").instantiate() as Projectile
	sniper_projectile.source_weapon = sniper
	sniper_projectile.damage = 12
	sniper_projectile.damage_type = Attack.TYPE_PHYSICAL
	var hitbox := load("res://Utility/hit_hurt_box/hit_box.tscn").instantiate() as HitBox
	hitbox.hitbox_owner = sniper_projectile
	hitbox.apply_attack(far_damage_target.get_node("HurtBox"))
	var dealt_damage := hp_before - int(far_damage_target.get("hp"))
	if dealt_damage != 22:
		_fail("Sniper far-distance hitbox damage should scale level-1 damage from 12 to 22, got %d." % dealt_damage)
		return false
	sniper_projectile.queue_free()
	hitbox.queue_free()
	sniper.queue_free()
	far_target.queue_free()
	far_damage_target.queue_free()

	var rocket := _instantiate_weapon("res://Player/Weapons/Instances/rocket_launcher.tscn")
	if rocket == null:
		return false
	await get_tree().process_frame
	var killed_enemy := _make_enemy("RocketKilledEnemy", Vector2.ZERO)
	var nearby_enemy := _make_enemy("RocketNearbyEnemy", Vector2(16.0, 0.0))
	_register_enemy(killed_enemy)
	_register_enemy(nearby_enemy)
	rocket.call("_on_passive_event", &"on_enemy_killed", {
		"source_weapon": rocket,
		"enemy": killed_enemy,
		"position": Vector2.ZERO,
	})
	if int(rocket.passive_controller.get_passive_charge_current()) != 2:
		_fail("Rocket nearby-kill trigger should consume 1 of 3 charges.")
		return false
	rocket.refresh_passive_on_reload()
	if int(rocket.passive_controller.get_passive_charge_current()) != 3:
		_fail("Rocket reload refresh should restore all charges.")
		return false
	rocket.queue_free()
	killed_enemy.queue_free()
	nearby_enemy.queue_free()

	var charged := _instantiate_weapon("res://Player/Weapons/Instances/charged_blaster.tscn")
	if charged == null:
		return false
	await get_tree().process_frame
	charged.set("simultaneous_hit_trigger_count", 2)
	var beam_node := Node2D.new()
	beam_node.name = "ChargedBlasterBeam"
	get_tree().root.add_child(beam_node)
	var target_a := _make_target("ChargedTargetA", Vector2(10.0, 0.0))
	var target_b := _make_target("ChargedTargetB", Vector2(20.0, 0.0))
	charged.call("_try_trigger_simultaneous_beam_hits", target_a, beam_node)
	if int(charged.passive_controller.get_passive_charge_current()) != 3:
		_fail("Charged Blaster should not consume before enough unique targets are hit.")
		return false
	charged.call("_try_trigger_simultaneous_beam_hits", target_b, beam_node)
	if int(charged.passive_controller.get_passive_charge_current()) != 2:
		_fail("Charged Blaster multi-hit trigger should consume 1 of 3 charges.")
		return false
	charged.refresh_passive_on_reload()
	if int(charged.passive_controller.get_passive_charge_current()) != 3:
		_fail("Charged Blaster reload refresh should restore all charges.")
		return false
	charged.queue_free()
	beam_node.queue_free()
	target_a.queue_free()
	target_b.queue_free()
	return true

func _assert_second_batch_weapon_behaviors(player_node: FakePlayer) -> bool:
	var machine_gun := _instantiate_weapon("res://Player/Weapons/Instances/machine_gun.tscn")
	if machine_gun == null:
		return false
	await get_tree().process_frame
	machine_gun.current_ammo = maxi(0, machine_gun.get_effective_magazine_capacity() - 5)
	machine_gun.call("_on_passive_event", &"on_reload_started", {
		"source_weapon": machine_gun,
		"spent_ratio": 0.5,
	})
	if int(machine_gun.passive_controller.get_passive_charge_current()) != 0:
		_fail("Machine Gun reload-start Heat Expansion should consume its single charge.")
		return false
	machine_gun.refresh_passive_on_reload()
	if int(machine_gun.passive_controller.get_passive_charge_current()) != 1:
		_fail("Machine Gun reload finish should restore its single charge.")
		return false
	machine_gun.queue_free()

	var flamethrower := _instantiate_weapon("res://Player/Weapons/Instances/flamethrower.tscn")
	if flamethrower == null:
		return false
	await get_tree().process_frame
	flamethrower.set("_heat_prepared_accumulated_heat", maxf(float(flamethrower.get("heat_max_value")), 1.0))
	flamethrower.call("_on_passive_event", &"on_reload_started", {
		"source_weapon": flamethrower,
	})
	if int(flamethrower.passive_controller.get_passive_charge_current()) != 0:
		_fail("Flamethrower Heat Prepared should consume its single charge on reload start.")
		return false
	if player_node.heat_prepared_calls <= 0:
		_fail("Flamethrower Heat Prepared should apply its player buff when triggered.")
		return false
	flamethrower.refresh_passive_on_reload()
	if int(flamethrower.passive_controller.get_passive_charge_current()) != 1:
		_fail("Flamethrower reload finish should restore its single charge.")
		return false
	flamethrower.queue_free()

	var plasma := _instantiate_weapon("res://Player/Weapons/Instances/plasma_lance.tscn")
	if plasma == null:
		return false
	await get_tree().process_frame
	var required_count := maxi(1, int(plasma.get("heat_spend_attacks_trigger_count")))
	for _index in range(required_count):
		plasma.call("_try_trigger_heat_spend_chain", 1.0)
	var plasma_status := plasma.call("get_passive_status") as Dictionary
	if str(plasma_status.get("state", "")) != "ready_pending_action":
		_fail("Plasma Lance should enter ready_pending_action after enough heat-spend attacks.")
		return false
	plasma.call("_on_passive_event", &"on_reload_finished", {
		"source_weapon": plasma,
	})
	if int(plasma.passive_controller.get_passive_charge_current()) != 0:
		_fail("Plasma Lance reload-finished feedback should consume its single charge.")
		return false
	if player_node.plasma_feedback_calls <= 0:
		_fail("Plasma Lance heat feedback should call the player feedback hook.")
		return false
	plasma.refresh_passive_on_reload()
	if int(plasma.passive_controller.get_passive_charge_current()) != 1:
		_fail("Plasma Lance reload cycle should restore its single charge.")
		return false
	plasma.queue_free()

	var glacier := _instantiate_weapon("res://Player/Weapons/Instances/glacier_projector.tscn")
	if glacier == null:
		return false
	await get_tree().process_frame
	var frozen_target := _make_target("GlacierFrozenTarget", Vector2(20.0, 0.0))
	glacier.call("_try_emit_cold_snap_trigger", frozen_target)
	if int(glacier.passive_controller.get_passive_charge_current()) != 0:
		_fail("Glacier Cold Snap should consume its single charge.")
		return false
	glacier.call("_update_cold_snap_recharge", float(glacier.get("cold_snap_recharge_sec")) + 0.5)
	if int(glacier.passive_controller.get_passive_charge_current()) != 1:
		_fail("Glacier time recharge should restore its single charge.")
		return false
	glacier.queue_free()
	frozen_target.queue_free()

	var spear := _instantiate_weapon("res://Player/Weapons/Instances/spear_launcher.tscn")
	if spear == null:
		return false
	await get_tree().process_frame
	spear.set("radial_projectile_count", 1)
	spear.set("radial_fire_interval_sec", 0.0)
	spear.set("_piercing_blade_dance_charge", int(spear.get("radial_charge_cost")))
	var spear_ready_status := spear.call("get_passive_status") as Dictionary
	if int(spear_ready_status.get("charge_current", 0)) != 1:
		_fail("Spear should expose a filled HUD charge when blade dance threshold is ready.")
		return false
	if not bool(spear.call("_try_start_piercing_blade_dance")):
		_fail("Spear should start Piercing Blade Dance when threshold charge is ready.")
		return false
	var spear_after_status := spear.call("get_passive_status") as Dictionary
	if int(spear_after_status.get("charge_current", 1)) != 0:
		_fail("Spear should empty its HUD charge after spending blade dance charge.")
		return false
	spear.queue_free()
	return true

func _assert_third_batch_weapon_behaviors(player_node: FakePlayer) -> bool:
	var cannon := _instantiate_weapon("res://Player/Weapons/Instances/cannon.tscn")
	if cannon == null:
		return false
	await get_tree().process_frame
	cannon.set("_idle_fire_reload_ready", true)
	cannon.set("_idle_fire_ready", true)
	if not bool(cannon.call("_try_emit_idle_fire_trigger")):
		_fail("Cannon should emit idle-fire trigger when idle passive is ready.")
		return false
	if int(cannon.passive_controller.get_passive_charge_current()) != 0:
		_fail("Cannon idle-fire trigger should consume its single charge.")
		return false
	cannon.refresh_passive_on_reload()
	cannon.call("_on_passive_event", &"on_reload_finished", {"source_weapon": cannon})
	if int(cannon.passive_controller.get_passive_charge_current()) != 1:
		_fail("Cannon reload finish should restore its single charge.")
		return false
	cannon.queue_free()

	var dash := _instantiate_weapon("res://Player/Weapons/Instances/dash_blade.tscn")
	if dash == null:
		return false
	await get_tree().process_frame
	var dash_target := _make_target("DashTarget", Vector2(200.0, 0.0))
	var dash_threshold := float(dash.get("attack_range")) * maxf(float(dash.get("long_dash_trigger_range_ratio")), 0.0)
	dash.set("_dash_start_distance", dash_threshold + 8.0)
	dash.set("_dash_start_target_id", dash_target.get_instance_id())
	dash.call("_try_trigger_long_dash_hit", dash_target)
	if int(dash.passive_controller.get_passive_charge_current()) != 0:
		_fail("Dash Blade long-dash hit should consume its single charge.")
		return false
	dash.refresh_passive_on_reload()
	if int(dash.passive_controller.get_passive_charge_current()) != 1:
		_fail("Dash Blade reload refresh should restore its single charge.")
		return false
	dash.queue_free()
	dash_target.queue_free()

	var chainsaw := _instantiate_weapon("res://Player/Weapons/Instances/chainsaw_launcher.tscn")
	if chainsaw == null:
		return false
	await get_tree().process_frame
	var projectile := PROJECTILE_SCENE.instantiate()
	chainsaw.call("on_projectile_hit_wall", projectile, {
		"position": Vector2.ZERO,
		"normal": Vector2.RIGHT,
	})
	if int(chainsaw.passive_controller.get_passive_charge_current()) != 0:
		_fail("Chainsaw wall-contact trigger should consume its single charge.")
		return false
	chainsaw.refresh_passive_on_reload()
	if int(chainsaw.passive_controller.get_passive_charge_current()) != 1:
		_fail("Chainsaw reload refresh should restore its single charge.")
		return false
	chainsaw.queue_free()
	projectile.queue_free()

	var orbit := _instantiate_weapon("res://Player/Weapons/Instances/orbit.tscn")
	if orbit == null:
		return false
	await get_tree().process_frame
	orbit.call("_on_passive_event", &"on_player_damaged", {
		"player": player_node,
	})
	if int(orbit.passive_controller.get_passive_charge_current()) != 0:
		_fail("Orbit player-damaged trigger should consume its single charge.")
		return false
	orbit.refresh_passive_on_reload()
	if int(orbit.passive_controller.get_passive_charge_current()) != 1:
		_fail("Orbit reload refresh should restore its single charge.")
		return false
	orbit.queue_free()

	var laser := _instantiate_weapon("res://Player/Weapons/Instances/laser.tscn")
	if laser == null:
		return false
	await get_tree().process_frame
	var laser_target := _make_target("LaserTarget", Vector2(64.0, 0.0))
	laser.call("on_hit_target", laser_target)
	if int(laser.passive_controller.get_passive_charge_current()) != 0:
		_fail("Laser beam-hit trigger should consume its single charge.")
		return false
	laser.refresh_passive_on_reload()
	if int(laser.passive_controller.get_passive_charge_current()) != 1:
		_fail("Laser reload refresh should restore its single charge.")
		return false
	laser.queue_free()
	laser_target.queue_free()
	return true

func _instantiate_weapon(scene_path: String) -> Weapon:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		_fail("Failed to load weapon scene %s." % scene_path)
		return null
	var weapon := packed_scene.instantiate() as Weapon
	if weapon == null:
		_fail("Failed to instantiate weapon scene %s." % scene_path)
		return null
	get_tree().root.add_child(weapon)
	return weapon

func _make_target(target_name: String, target_position: Vector2) -> Node2D:
	var target := Node2D.new()
	target.name = target_name
	target.global_position = target_position
	get_tree().root.add_child(target)
	return target

func _make_damage_target(target_name: String, target_position: Vector2, hp: int) -> Node2D:
	var packed_scene := load("res://Npc/base_npc.tscn") as PackedScene
	if packed_scene == null:
		_fail("Failed to load damage target scene.")
		return null
	var target := packed_scene.instantiate() as Node2D
	if target == null:
		_fail("Failed to instantiate damage target scene.")
		return null
	target.name = target_name
	target.global_position = target_position
	target.set("hp", hp)
	get_tree().root.add_child(target)
	return target

func _make_enemy(enemy_name: String, enemy_position: Vector2) -> Node2D:
	var enemy := _make_target(enemy_name, enemy_position)
	enemy.add_to_group("enemies")
	return enemy

func _register_enemy(enemy: Node2D) -> void:
	var registry := get_tree().root.get_node_or_null("EnemyRegistry")
	if registry != null and registry.has_method("register_enemy"):
		registry.call("register_enemy", enemy)

func _assert_all_weapon_passives_are_charge_based() -> bool:
	if not _assert_passive_matrix_covers_all_weapons():
		return false
	for contract in PASSIVE_CHARGE_CONTRACTS:
		var scene_path := str(contract.get("scene", ""))
		var packed_scene := load(str(scene_path)) as PackedScene
		if packed_scene == null:
			_fail("Failed to load weapon scene %s." % scene_path)
			return false
		var weapon := packed_scene.instantiate() as Weapon
		if weapon == null:
			_fail("Failed to instantiate weapon scene %s." % scene_path)
			return false
		get_tree().root.add_child(weapon)
		await get_tree().process_frame
		if not weapon.has_method("get_passive_status"):
			_fail("Weapon %s should expose passive status." % scene_path)
			return false
		var status := weapon.call("get_passive_status") as Dictionary
		if not _assert_passive_status_contract(scene_path, status):
			return false
		var expected_max := int(contract.get("charges", 0))
		var charge_max := int(status.get("charge_max", status.get("charges_max", 0)))
		var charge_current := int(status.get("charge_current", status.get("charges_current", -1)))
		if charge_max != expected_max:
			_fail("Weapon %s should expose %d passive charge(s), got %d." % [scene_path, expected_max, charge_max])
			return false
		if charge_current < 0 or charge_current > charge_max:
			_fail("Weapon %s should expose valid passive charge current, got %d/%d." % [scene_path, charge_current, charge_max])
			return false
		weapon.queue_free()
		await get_tree().process_frame
	return true

func _assert_passive_status_contract(scene_path: String, status: Dictionary) -> bool:
	for field in REQUIRED_STATUS_FIELDS:
		if not status.has(field):
			_fail("Weapon %s passive status is missing required field '%s'." % [scene_path, field])
			return false
	for text_field in ["id", "display_name", "state", "trigger_hint", "refresh_hint"]:
		if str(status.get(text_field, "")).strip_edges() == "":
			_fail("Weapon %s passive status field '%s' must not be empty." % [scene_path, text_field])
			return false
	if not bool(status.get("charge_based", false)):
		_fail("Weapon %s should mark passive status as charge-based." % scene_path)
		return false
	var progress := float(status.get("progress", -1.0))
	if progress < 0.0 or progress > 1.0:
		_fail("Weapon %s passive progress should stay within 0..1, got %.3f." % [scene_path, progress])
		return false
	var charge_max := int(status.get("charge_max", 0))
	var charge_current := int(status.get("charge_current", -1))
	if charge_max <= 0:
		_fail("Weapon %s passive charge_max must be positive, got %d." % [scene_path, charge_max])
		return false
	if charge_current < 0 or charge_current > charge_max:
		_fail("Weapon %s passive charge_current must be within 0..charge_max, got %d/%d." % [scene_path, charge_current, charge_max])
		return false
	return true

func _assert_passive_matrix_covers_all_weapons() -> bool:
	if not FileAccess.file_exists(PASSIVE_MATRIX_PATH):
		_fail("Missing passive contract matrix at %s." % PASSIVE_MATRIX_PATH)
		return false
	var file := FileAccess.open(PASSIVE_MATRIX_PATH, FileAccess.READ)
	if file == null:
		_fail("Failed to read passive contract matrix at %s." % PASSIVE_MATRIX_PATH)
		return false
	var content := file.get_as_text()
	for contract in PASSIVE_CHARGE_CONTRACTS:
		var matrix_key := str(contract.get("matrix_key", ""))
		if matrix_key.strip_edges() == "":
			_fail("Passive contract is missing matrix_key for %s." % str(contract.get("scene", "")))
			return false
		if not content.contains("| %s |" % matrix_key):
			_fail("Passive contract matrix should cover %s." % matrix_key)
			return false
	return true

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	_fail(message)

func _assert_false(value: bool, message: String) -> void:
	if not value:
		return
	_fail(message)

func _assert_equal(expected: int, actual: int, message: String) -> void:
	if expected == actual:
		return
	_fail("%s Expected %d, got %d." % [message, expected, actual])

func _assert_equal_string(expected: String, actual: String, message: String) -> void:
	if expected == actual:
		return
	_fail("%s Expected %s, got %s." % [message, expected, actual])

func _fail(message: String) -> void:
	push_error("WeaponPassiveChargeTest: %s" % message)
	get_tree().quit(1)
