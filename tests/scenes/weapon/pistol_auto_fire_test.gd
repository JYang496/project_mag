extends Node

const PistolScene := preload("res://Player/Weapons/Instances/pistol.tscn")
const DashBladeScene := preload("res://Player/Weapons/Instances/dash_blade.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _shot_count := 0

func _ready() -> void:
	PhaseManager.phase = PhaseManager.BATTLE_STARTING
	PhaseManager.enter_battle()
	var pistol := PistolScene.instantiate() as Weapon
	# This test validates targeting and projectile emission, not audio playback.
	# Avoid starting an AudioServer stream that can outlive short headless runs.
	pistol.fire_feedback_profile = null
	add_child(pistol)
	pistol.global_position = Vector2.ZERO
	pistol.shoot.connect(func() -> void: _shot_count += 1)
	var failed := false
	pistol.set("_pierce_mark_cycle_elapsed_sec", 0.0)
	pistol.set("_pierce_mark_window_remaining_sec", 0.0)
	pistol.call("_update_pierce_mark_window", 7.9)
	failed = _check(
		str(pistol.get_passive_status().get("state", "")) == "charging",
		"Auto Pistol must not enter its mark window before 8 seconds"
	) or failed
	pistol.call("_update_pierce_mark_window", 0.11)
	failed = _check(
		str(pistol.get_passive_status().get("state", "")) == "active",
		"Auto Pistol must enter its mark window every 8 seconds without a movement requirement"
	) or failed

	# Runtime targeting uses EnemyRegistry as its authoritative spatial source.
	var enemy := Node2D.new()
	enemy.add_to_group(&"enemies")
	add_child(enemy)
	EnemyRegistry.register_enemy(enemy)
	# Reproduce the live failure mode where aim and muzzle positions briefly
	# coincide. A valid shot must still be emitted instead of only spending ammo.
	enemy.global_position = Vector2.ZERO

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var found_target := pistol.call("_find_closest_enemy") as Node2D
	var spawned_projectile: Projectile
	for child in get_children():
		if child is Projectile:
			spawned_projectile = child as Projectile
			break
	failed = _check(found_target == enemy, "Auto Pistol must find a nearby registered enemy") or failed
	failed = _check(_shot_count > 0, "Auto Pistol must automatically fire at a nearby enemy") or failed
	failed = _check(spawned_projectile != null, "Auto Pistol must add a projectile after spending ammo") or failed
	if spawned_projectile != null:
		failed = _check(spawned_projectile.base_displacement.length_squared() > 0.0, "Auto Pistol projectile must receive non-zero movement") or failed
		failed = _check(spawned_projectile.global_position != pistol.global_position, "Auto Pistol projectile must move away from the muzzle") or failed

	var previous_auto_aim := PlayerAssistSettings.auto_aim_continuous_fire
	PlayerAssistSettings.auto_aim_continuous_fire = true
	var blade := DashBladeScene.instantiate() as DashBlade
	add_child(blade)
	blade.global_position = Vector2.ZERO
	blade.call("_process_idle")
	failed = _check(
		not blade.has_meta(&"_player_assist_auto_aim_target"),
		"Dash Blade idle aiming must tolerate a missing auto-aim target"
	) or failed
	enemy.global_position = Vector2(600.0, 0.0)
	var assist := PlayerAssistSystem.new()
	assist.setup(self)
	assist.process_combat_assist(blade, false, 0.016)
	blade.call("_process_idle")
	failed = _check(
		blade.has_meta(&"_player_assist_auto_aim_target"),
		"Auto aim must retain a melee target outside attack range"
	) or failed
	failed = _check(
		is_equal_approx(blade.blade_anchor.rotation, deg_to_rad(90.0)),
		"Dash Blade must point toward an auto-aim target outside attack range"
	) or failed
	failed = _check(
		int(blade.get("_state")) == DashBlade.AttackState.IDLE,
		"Dash Blade must not attack an auto-aim target outside attack range"
	) or failed
	PlayerAssistSettings.auto_aim_continuous_fire = false
	assist.process_combat_assist(blade, false, 0.016)
	blade.call("_process_idle")
	failed = _check(
		not blade.has_meta(&"_player_assist_auto_aim_target"),
		"Dash Blade idle aiming must tolerate a cleared auto-aim target"
	) or failed
	PlayerAssistSettings.auto_aim_continuous_fire = previous_auto_aim
	if failed:
		print("FAIL pistol auto fire")
	else:
		print("PASS pistol auto fire")
	await TEST_TEARDOWN.finish(self, 1 if failed else 0, PhaseManager.reset_runtime_state)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
