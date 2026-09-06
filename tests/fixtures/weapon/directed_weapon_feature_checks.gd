extends RefCounted

const COMMAND_CONTROLLER := preload("res://Player/Mechas/scripts/player_weapon_command_controller.gd")
const WEAPON_SELECTOR := preload("res://UI/scripts/weapon_selector.gd")

class SkillPlayer:
	extends Node2D
	var energy := 100.0
	func consume_energy(amount: float) -> bool:
		if energy < amount: return false
		energy -= amount
		return true
	func get_current_energy() -> float: return energy

class CommandData:
	extends RefCounted
	var main_weapon_index := 0

class CommandPlayer:
	extends Node
	var PlayerData := CommandData.new()
	var selected_slot := -1
	var requested_skill_slot := -1
	var skill_request_count := 0
	var accept_skill_request := true
	func try_shift_main_weapon(_step: int) -> bool: return true
	func try_select_main_weapon(slot: int) -> bool:
		selected_slot = slot
		PlayerData.main_weapon_index = slot
		return true
	func request_weapon_skill_at_slot(slot: int) -> bool:
		requested_skill_slot = slot
		skill_request_count += 1
		return accept_skill_request

class UnlockTarget:
	extends Node2D

var _host: Node
var _expect: Callable

func run(host: Node, expect: Callable) -> void:
	_host = host
	_expect = expect
	await _validate_skill()
	_validate_switching()
	_validate_commands()
	await _validate_role_fire()

func _validate_skill() -> void:
	var old_phase: String = PhaseManager.phase
	var old_player: Node = PlayerData.player
	PhaseManager.phase = PhaseManager.BATTLE
	var player := SkillPlayer.new()
	_host.add_child(player)
	PlayerData.player = player
	var weapon := (load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene).instantiate() as Weapon
	weapon.skill_unlock_condition = &"test_condition"
	weapon.skill_unlock_hint = "Complete the test condition"
	weapon.skill_unlock_required = 2.0
	_host.add_child(weapon)
	var commits := [0]
	weapon.weapon_event_emitted.connect(func(event: WeaponEvent):
		if event.type == WeaponEvent.SKILL_CAST_COMMITTED: commits[0] += 1)
	_check(not weapon.request_weapon_skill(), "locked weapon skill rejects activation")
	weapon.add_weapon_skill_unlock_progress(1.0)
	var locked_status: Dictionary = weapon.get_weapon_skill_status()
	_check(not bool(locked_status.get("unlock_ready", true)), "partial unlock progress remains locked")
	_check(is_equal_approx(float(locked_status.get("unlock_progress", 0.0)), 0.5), "unlock status exposes normalized progress")
	weapon.add_weapon_skill_unlock_progress(1.0)
	_check(bool(weapon.get_weapon_skill_status().get("unlock_ready", false)), "completed condition latches readiness")
	weapon.skill_runtime.update(120.0)
	_check(bool(weapon.get_weapon_skill_status().get("unlock_ready", false)), "unlock readiness persists without a release window")
	player.energy = 0.0
	_check(not weapon.request_weapon_skill(), "energy failure rejects activation")
	_check(bool(weapon.get_weapon_skill_status().get("unlock_ready", false)), "failed activation does not consume unlock readiness")
	player.energy = 100.0
	_check(weapon.request_weapon_skill(), "equipped weapon accepts its directed skill")
	_check(is_equal_approx(player.energy, 50.0), "weapon skill spends energy")
	_check(bool(weapon.get("_active_skill_running")), "Machine Gun skill enables its ammo-chain window")
	_check(is_equal_approx(weapon.get_external_attack_speed_multiplier(), 5.0), "Machine Gun skill multiplies attack speed by five")
	_check(str(weapon.get_weapon_skill_status().get("display_name", "")) != "Weapon Overdrive", "weapon skill exposes its specific name")
	_check(str(weapon.get_weapon_skill_status().get("description", "")).contains("5"), "weapon skill exposes its concrete effect description")
	_check(commits[0] == 1, "skill emits one committed event")
	var status: Dictionary = weapon.get_weapon_skill_status()
	_check(bool(status.get("active", false)) and not bool(status.get("ready", true)), "active skill exposes its cooldown state")
	_check(not bool(status.get("unlock_ready", true)), "casting consumes the latched unlock")
	weapon.skill_runtime.update(3.1)
	_check(not bool(weapon.get("_active_skill_running")), "Machine Gun ammo-chain window expires after 3 seconds")
	_check(is_equal_approx(weapon.get_external_attack_speed_multiplier(), 1.0), "Machine Gun skill removes its attack-speed multiplier on expiry")
	weapon.add_weapon_skill_unlock_progress(2.0)
	_check(bool(weapon.get_weapon_skill_status().get("unlock_ready", false)), "unlock condition can accumulate again during cooldown")
	_check(not bool(weapon.get_weapon_skill_status().get("ready", true)), "cooldown still blocks a newly unlocked skill")
	weapon.skill_runtime.update(10.0)
	_check(bool(weapon.get_weapon_skill_status().get("ready", false)), "latched unlock becomes castable when cooldown ends")
	_validate_skill_hud_text(weapon.get_weapon_skill_status())
	weapon.queue_free()
	await _validate_weapon_specific_unlock_boundaries()
	player.queue_free()
	PlayerData.player = old_player
	PhaseManager.phase = old_phase

func _validate_weapon_specific_unlock_boundaries() -> void:
	_validate_all_weapon_trigger_groups()
	var targets: Array[UnlockTarget] = []
	for index in range(3):
		var target := UnlockTarget.new()
		target.position = Vector2(index * 8.0, 0.0)
		_host.add_child(target)
		targets.append(target)

	var shotgun := (load("res://Player/Weapons/Instances/shotgun.tscn") as PackedScene).instantiate() as Weapon
	_host.add_child(shotgun)
	shotgun.set_weapon_role("main")
	var staged_status: Dictionary = shotgun.get_weapon_skill_status()
	_check(is_equal_approx(float(staged_status.get("unlock_progress", 0.0)), 0.5), "Shotgun exposes its completed support-to-main stage as half progress")
	var staged_text := WEAPON_SELECTOR.new().build_skill_detail_text(staged_status, 2)
	_check(staged_text.contains("·"), "Shotgun HUD exposes a distinct armed-stage instruction")
	targets[0].global_position = shotgun.global_position + Vector2.RIGHT * 40.0
	shotgun.call("_try_unlock_from_close_entry_hit", targets[0])
	_check(bool(shotgun.get_weapon_skill_status().get("unlock_ready", false)), "Shotgun close hit completes the armed second stage")
	shotgun.call("activate_weapon_skill_effect", null)
	_check(int(shotgun.get("_double_discipline_shots_remaining")) == 2, "Shotgun skill grants exactly two empowered attacks")
	_check(is_equal_approx(shotgun.get_external_attack_speed_multiplier(), 2.0), "Shotgun skill doubles attack speed")
	shotgun.call("_consume_double_discipline_shot")
	shotgun.call("_consume_double_discipline_shot")
	_check(is_equal_approx(shotgun.get_external_attack_speed_multiplier(), 1.0), "Shotgun skill clears its speed bonus after two attacks")

	var spear := (load("res://Player/Weapons/Instances/spear_launcher.tscn") as PackedScene).instantiate() as Weapon
	_host.add_child(spear)
	var spear_directions: Array = spear.call("_build_radial_directions", 8)
	_check(spear_directions.size() == 8, "Spear skill builds eight launch directions")
	var spear_arc_deg := rad_to_deg((spear_directions[0] as Vector2).angle_to(spear_directions[7] as Vector2))
	_check(is_equal_approx(absf(spear_arc_deg), 40.0), "Spear skill distributes its volley across 40 degrees")

	var rocket := (load("res://Player/Weapons/Instances/rocket_launcher.tscn") as PackedScene).instantiate() as Weapon
	_host.add_child(rocket)
	var area := Node2D.new()
	_host.add_child(area)
	rocket.call("on_area_effect_target_affected", area, targets[0])
	_check(int((rocket.get("_skill_explosion_target_ids") as Dictionary).size()) == 1, "Rocket tracks an active explosion batch")
	area.queue_free()
	await _host.get_tree().process_frame
	_check((rocket.get("_skill_explosion_target_ids") as Dictionary).is_empty(), "Rocket removes incomplete explosion batches when their area exits")

	var laser := (load("res://Player/Weapons/Instances/laser.tscn") as PackedScene).instantiate() as Weapon
	_host.add_child(laser)
	var laser_status: Dictionary = laser.get_weapon_skill_status()
	_check(not bool(laser_status.get("unlock_ready", true)), "Laser starts with its kill unlock incomplete")
	_check(str(laser_status.get("condition_group", "")) == "combat_cycle", "Laser kill unlock remains within the five trigger groups")
	laser.emit_weapon_event(WeaponEvent.create(WeaponEvent.TARGET_KILLED, laser))
	_check(bool(laser.get_weapon_skill_status().get("unlock_ready", false)), "Laser unlocks after it kills one enemy")
	_check(laser.skill_unlock_runtime.consume_ready(), "Laser test consumes the completed unlock")
	_check(not bool(laser.get_weapon_skill_status().get("unlock_ready", true)), "Laser kill unlock resets only after consumption")

	var cannon := (load("res://Player/Weapons/Instances/cannon.tscn") as PackedScene).instantiate() as Weapon
	_host.add_child(cannon)
	cannon.skill_unlock_runtime.update(14.9)
	_check(not bool(cannon.get_weapon_skill_status().get("unlock_ready", true)), "Cannon remains locked before 15 support seconds")
	cannon.skill_unlock_runtime.update(0.1)
	_check(bool(cannon.get_weapon_skill_status().get("unlock_ready", false)), "Cannon unlocks at 15 support seconds")

	var glacier := (load("res://Player/Weapons/Instances/glacier_projector.tscn") as PackedScene).instantiate() as Weapon
	_host.add_child(glacier)
	for _burst in range(74):
		glacier.call("_record_skill_burst_damage", true)
	_check(not bool(glacier.get_weapon_skill_status().get("unlock_ready", true)), "Glacier remains locked before 75 successful bursts")
	glacier.call("_record_skill_burst_damage", false)
	_check(not bool(glacier.get_weapon_skill_status().get("unlock_ready", true)), "Glacier ignores bursts that deal no damage")
	glacier.call("_record_skill_burst_damage", true)
	_check(bool(glacier.get_weapon_skill_status().get("unlock_ready", false)), "Glacier unlocks on the 75th successful burst")

	shotgun.queue_free()
	spear.queue_free()
	rocket.queue_free()
	laser.queue_free()
	cannon.free()
	glacier.free()
	for target in targets:
		target.queue_free()
	await _host.get_tree().process_frame

func _validate_all_weapon_trigger_groups() -> void:
	var scene_effects := {
		"res://Player/Weapons/Instances/machine_gun.tscn": &"machine_gun_infinite_chain",
		"res://Player/Weapons/Instances/cannon.tscn": &"cannon_siege_trajectory",
		"res://Player/Weapons/Instances/laser.tscn": &"laser_refraction_matrix",
		"res://Player/Weapons/Instances/chainsaw_launcher.tscn": &"chainsaw_cage",
		"res://Player/Weapons/Instances/dash_blade.tscn": &"dash_rift",
		"res://Player/Weapons/Instances/shotgun.tscn": &"shotgun_double_discipline",
		"res://Player/Weapons/Instances/sniper.tscn": &"sniper_lethal_aim",
		"res://Player/Weapons/Instances/spear_launcher.tscn": &"spear_phalanx",
		"res://Player/Weapons/Instances/rocket_launcher.tscn": &"rocket_cluster_warhead",
		"res://Player/Weapons/Instances/glacier_projector.tscn": &"glacier_white_frost_domain",
		"res://Player/Weapons/Instances/flamethrower.tscn": &"flame_moving_inferno",
		"res://Player/Weapons/Instances/charged_blaster.tscn": &"charged_blaster_prism_overload",
		"res://Player/Weapons/Instances/plasma_lance.tscn": &"plasma_storm",
		"res://Player/Weapons/Instances/orbit.tscn": &"orbit_proliferation",
	}
	var allowed_groups := {
		"combat_cycle": true,
		"positioning_action": true,
		"multi_target_accumulation": true,
		"shared_resource": true,
		"reactive": true,
	}
	var observed_groups: Dictionary = {}
	var observed_effects: Dictionary = {}
	for scene_path in scene_effects.keys():
		var weapon := (load(scene_path) as PackedScene).instantiate() as Weapon
		_host.add_child(weapon)
		var status: Dictionary = weapon.get_weapon_skill_status()
		var group := str(status.get("condition_group", "unconfigured"))
		_check(allowed_groups.has(group), "%s uses one of the five trigger groups" % scene_path.get_file())
		observed_groups[group] = true
		_check(weapon.active_skill_effect_id == scene_effects[scene_path], "%s binds the selected active skill effect" % scene_path.get_file())
		_check(not observed_effects.has(weapon.active_skill_effect_id), "%s uses a unique active skill effect id" % scene_path.get_file())
		observed_effects[weapon.active_skill_effect_id] = true
		_check(not str(status.get("display_name", "")).is_empty(), "%s exposes an active skill name" % scene_path.get_file())
		_check(not str(status.get("description", "")).is_empty(), "%s exposes an active skill description" % scene_path.get_file())
		weapon.queue_free()
	_check(observed_groups.size() == allowed_groups.size(), "the current 14 weapons exercise all five trigger groups")
	_check(observed_effects.size() == 14, "all 14 weapons bind distinct selected active skill effects")

func _validate_skill_hud_text(ready_status: Dictionary) -> void:
	var selector := WEAPON_SELECTOR.new()
	var ready_text := selector.build_skill_detail_text(ready_status, 2)
	_check(ready_text.contains("2"), "ready HUD prompt includes the weapon number used to switch and cast")
	var building_status := ready_status.duplicate(true)
	building_status["unlock_ready"] = false
	building_status["unlock_current"] = 1.0
	building_status["unlock_required"] = 2.0
	building_status["cooldown_remaining"] = 0.0
	var building_text := selector.build_skill_detail_text(building_status, 2)
	_check(building_text.contains("1/2"), "building HUD prompt exposes exact unlock progress")
	var blocked_status := ready_status.duplicate(true)
	blocked_status["has_energy"] = false
	blocked_status["cooldown_remaining"] = 0.0
	_check(selector.build_skill_detail_text(blocked_status, 2) != ready_text, "energy-blocked HUD state is distinct from ready")
	var cooldown_status := ready_status.duplicate(true)
	cooldown_status["cooldown_remaining"] = 3.25
	_check(selector.build_skill_detail_text(cooldown_status, 2).contains("3.3"), "cooldown HUD prompt exposes remaining time")
	selector.free()

func _validate_switching() -> void:
	var old_list: Array = PlayerData.player_weapon_list
	var old_index: int = PlayerData.main_weapon_index
	var first := Weapon.new()
	var second := Weapon.new()
	first.base_trait_flags = WeaponTrait.traits_to_flags([WeaponTrait.AUTO_FIRE])
	second.base_trait_flags = WeaponTrait.traits_to_flags([WeaponTrait.AUTO_FIRE])
	PlayerData.player_weapon_list = [first, second]
	PlayerData.main_weapon_index = 0
	_check(PlayerData.shift_main_weapon(1) and PlayerData.main_weapon_index == 1, "weapon switching selects the next slot")
	PlayerData.player_weapon_list = old_list
	PlayerData.main_weapon_index = old_index
	first.skill_runtime.clear_for_weapon_exit()
	second.skill_runtime.clear_for_weapon_exit()
	first.free()
	second.free()

func _validate_commands() -> void:
	var old_phase: String = PhaseManager.phase
	PhaseManager.phase = PhaseManager.BATTLE
	var player := CommandPlayer.new()
	_host.add_child(player)
	var controller = COMMAND_CONTROLLER.new()
	controller.setup(player)
	_send(controller, &"WEAPON_SLOT_2", true)
	_send(controller, &"WEAPON_SLOT_2", false)
	_check(player.selected_slot == 1 and player.requested_skill_slot == 1, "slot press switches weapon and casts its skill")
	_check(player.skill_request_count == 1, "slot release does not repeat the skill")
	_send(controller, &"WEAPON_SLOT_3", true)
	_check(player.selected_slot == 2 and player.requested_skill_slot == 2, "another slot press switches and casts immediately")
	var count := player.skill_request_count
	controller.process(0.1)
	_check(player.skill_request_count == count, "holding a slot key does not repeat the skill")
	_send(controller, &"WEAPON_SLOT_3", false)
	player.accept_skill_request = false
	_send(controller, &"WEAPON_SLOT_4", true)
	_check(player.selected_slot == 3 and player.requested_skill_slot == 3, "switch still succeeds when the skill is unavailable")
	count = player.skill_request_count
	player.accept_skill_request = true
	controller.process(0.1)
	_check(player.skill_request_count == count, "an unavailable skill is not retried without another press")
	_send(controller, &"WEAPON_SLOT_4", true)
	_check(player.skill_request_count == count + 1, "pressing the current weapon number retries its skill immediately")
	count = player.skill_request_count
	_send(controller, &"WEAPON_SKILL", true)
	_check(player.requested_skill_slot == 3 and player.skill_request_count == count + 1, "skill key casts the current weapon immediately")
	controller.clear()
	controller.setup(null)
	player.free()
	PhaseManager.phase = old_phase

func _validate_role_fire() -> void:
	var old_phase: String = PhaseManager.phase
	PhaseManager.phase = PhaseManager.BATTLE
	var weapon := (load("res://Player/Weapons/Instances/machine_gun.tscn") as PackedScene).instantiate() as Ranger
	_host.add_child(weapon)
	await _host.get_tree().process_frame
	weapon.set_automatic_aim_target(weapon.global_position + Vector2.RIGHT * 400.0)
	weapon.set_weapon_role("main")
	var before := _projectile_count()
	_check(weapon.request_primary_fire(), "main weapon fire request succeeds")
	await _host.get_tree().process_frame
	_check(_projectile_count() == before + 1, "main weapon spawns one projectile")
	weapon.is_on_cooldown = false
	weapon.current_ammo = weapon.magazine_capacity
	weapon.set_weapon_role("support")
	before = _projectile_count()
	_check(weapon.request_automatic_fire(), "support weapon fire request succeeds")
	await _host.get_tree().process_frame
	_check(_projectile_count() == before + 1, "support weapon spawns one projectile")
	weapon.queue_free()
	await _host.get_tree().process_frame
	PhaseManager.phase = old_phase

func _send(controller: RefCounted, action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	controller.process_input_event(event)

func _projectile_count() -> int:
	return _host.get_tree().get_nodes_in_group(&"runtime_projectiles").size()

func _check(condition: bool, message: String) -> void:
	_expect.call(condition, message)
