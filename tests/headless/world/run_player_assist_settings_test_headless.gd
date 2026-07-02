extends Node

const MACHINE_GUN_SCENE := preload("res://Player/Weapons/Instances/machine_gun.tscn")
const CANNON_SCENE := preload("res://Player/Weapons/Instances/cannon.tscn")
const SHOTGUN_SCENE := preload("res://Player/Weapons/Instances/shotgun.tscn")
const CHARGED_BLASTER_SCENE := preload("res://Player/Weapons/Instances/charged_blaster.tscn")
const PLAYER_ASSIST_SYSTEM_SCRIPT := preload("res://Player/Mechas/scripts/player_assist_system.gd")

var _failed: bool = false

class FakePlayer:
	extends Node2D

	var assist_system: RefCounted = PLAYER_ASSIST_SYSTEM_SCRIPT.new()
	var broadcast_events: Array[StringName] = []

	func _init() -> void:
		assist_system.setup(self)

	func get_main_weapon() -> Weapon:
		if PlayerData.player_weapon_list.is_empty():
			return null
		PlayerData.sanitize_main_weapon_index()
		var idx := PlayerData.main_weapon_index
		if idx < 0 or idx >= PlayerData.player_weapon_list.size():
			return null
		return PlayerData.player_weapon_list[idx] as Weapon

	func mark_weapon_roles_dirty_for_assist() -> void:
		pass

	func refresh_weapon_structure_for_assist() -> void:
		for i in range(PlayerData.player_weapon_list.size()):
			var weapon := PlayerData.player_weapon_list[i] as Weapon
			if weapon != null and is_instance_valid(weapon):
				weapon.set_weapon_role("main" if i == PlayerData.main_weapon_index else "offhand")

	func broadcast_weapon_passive_event_for_assist(event_name: StringName, _detail: Dictionary = {}) -> void:
		broadcast_events.append(event_name)

	func apply_heat_expansion(_duration_sec: float, _max_heat_mul: float) -> bool:
		return true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.BATTLE
	PlayerAssistSettings.auto_aim_continuous_fire = true
	PlayerAssistSettings.auto_reload_switch = true

	var player := FakePlayer.new()
	player.name = "PlayerAssistTestPlayer"
	add_child(player)
	PlayerData.player = player

	var machine_gun := _add_weapon(MACHINE_GUN_SCENE, 0)
	var cannon := _add_weapon(CANNON_SCENE, 1)
	var shotgun := _add_weapon(SHOTGUN_SCENE, 2)
	var charged_blaster := _add_weapon(CHARGED_BLASTER_SCENE, 3)
	if machine_gun == null or cannon == null or shotgun == null or charged_blaster == null:
		_fail("Failed to instantiate assist test weapons.")
		return
	PlayerData.set_main_weapon_index(0)
	player.refresh_weapon_structure_for_assist()
	await get_tree().process_frame

	var ammo_before_no_target := machine_gun.current_ammo
	player.assist_system.process_combat_assist(machine_gun, false, 0.016)
	await get_tree().process_frame
	_assert_equal(ammo_before_no_target, machine_gun.current_ammo, "Auto fire should not spend ammo without enemies.")
	if _failed:
		return

	var enemy := Node2D.new()
	enemy.name = "AssistTarget"
	enemy.global_position = Vector2(96.0, 0.0)
	add_child(enemy)
	EnemyRegistry.register_enemy(enemy)
	var ammo_before_target := machine_gun.current_ammo
	player.assist_system.process_combat_assist(machine_gun, false, 0.016)
	await get_tree().process_frame
	_assert_equal(ammo_before_target - 1, machine_gun.current_ammo, "Auto fire should spend one ammo when a target exists.")
	if _failed:
		return
	machine_gun.call("_update_weapon_rotation")
	var expected_rotation := machine_gun.global_position.direction_to(enemy.global_position).angle() + deg_to_rad(90.0)
	_assert_almost_equal(expected_rotation, machine_gun.rotation, 0.001, "Auto fire should aim the muzzle at the selected target.")
	if _failed:
		return
	_assert_true(machine_gun.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Auto aim mode should keep the main weapon aimed at the selected target.")
	if _failed:
		return
	_assert_true(not player.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Auto aim mode should not put the target on the player because offhand weapons still follow the mouse.")
	if _failed:
		return
	player.set_meta("_benchmark_mouse_target", Vector2(0.0, 180.0))
	var offhand_target_variant: Variant = shotgun.call("get_mouse_target")
	if not (offhand_target_variant is Vector2):
		_fail("Offhand weapon should resolve a mouse target while main weapon auto aim is active.")
		return
	_assert_vector_almost_equal(Vector2(0.0, 180.0), offhand_target_variant as Vector2, 0.001, "Offhand weapon should keep following player mouse target while main weapon auto aims.")
	if _failed:
		return
	player.remove_meta("_benchmark_mouse_target")
	machine_gun.set_meta("_benchmark_mouse_target", Vector2(0.0, 160.0))
	player.assist_system.process_combat_assist(machine_gun, true, 0.016)
	_assert_true(not machine_gun.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Manual fire should temporarily clear weapon auto aim.")
	if _failed:
		return
	_assert_true(not player.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Manual fire should temporarily clear player auto aim.")
	if _failed:
		return
	machine_gun.call("_update_weapon_rotation")
	var expected_manual_rotation := machine_gun.global_position.direction_to(Vector2(0.0, 160.0)).angle() + deg_to_rad(90.0)
	_assert_almost_equal(expected_manual_rotation, machine_gun.rotation, 0.001, "Manual fire should restore mouse-directed aiming while held.")
	if _failed:
		return
	machine_gun.remove_meta("_benchmark_mouse_target")
	player.assist_system.process_combat_assist(machine_gun, false, 0.016)
	_assert_true(machine_gun.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Auto aim should resume after manual fire ends.")
	if _failed:
		return

	PlayerData.set_main_weapon_index(2)
	player.refresh_weapon_structure_for_assist()
	shotgun.current_ammo = maxi(shotgun.current_ammo, 2)
	shotgun.is_reloading = false
	shotgun.reload_time_left = 0.0
	shotgun.is_on_cooldown = false
	enemy.global_position = Vector2(420.0, 0.0)
	var shotgun_ammo_before_far_target := shotgun.current_ammo
	player.assist_system.process_combat_assist(shotgun, false, 0.016)
	await get_tree().process_frame
	_assert_equal(shotgun_ammo_before_far_target, shotgun.current_ammo, "Auto fire should not spend Shotgun ammo while the closest enemy is outside effective range.")
	if _failed:
		return
	_assert_true(not shotgun.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Auto aim should not hold a far target outside Shotgun effective range.")
	if _failed:
		return
	enemy.global_position = Vector2(140.0, 0.0)
	player.assist_system.process_combat_assist(shotgun, false, 0.016)
	await get_tree().process_frame
	_assert_equal(shotgun_ammo_before_far_target - 1, shotgun.current_ammo, "Auto fire should spend Shotgun ammo after the enemy enters effective range.")
	if _failed:
		return

	PlayerData.set_main_weapon_index(3)
	player.refresh_weapon_structure_for_assist()
	charged_blaster.current_ammo = maxi(charged_blaster.current_ammo, 1)
	charged_blaster.is_reloading = false
	charged_blaster.reload_time_left = 0.0
	charged_blaster.is_on_cooldown = false
	charged_blaster.set("beam_local_forward", Vector2.UP)
	charged_blaster.rotation = 0.0
	enemy.global_position = Vector2(260.0, 80.0)
	var charged_expected_direction: Vector2 = charged_blaster.global_position.direction_to(enemy.global_position).normalized()
	player.assist_system.process_combat_assist(charged_blaster, false, 0.016)
	await get_tree().process_frame
	var charged_actual_direction: Vector2 = charged_blaster.get("beam_local_forward")
	_assert_vector_almost_equal(charged_expected_direction, charged_actual_direction, 0.001, "Charged Blaster auto fire should commit beam direction toward the assist target.")
	if _failed:
		return
	var charged_expected_rotation := charged_expected_direction.angle() + deg_to_rad(90.0)
	_assert_almost_equal(charged_expected_rotation, charged_blaster.rotation, 0.001, "Charged Blaster auto fire should snap visual rotation toward the assist target before firing.")
	if _failed:
		return

	PlayerData.set_main_weapon_index(0)
	player.refresh_weapon_structure_for_assist()
	machine_gun.current_ammo = 2
	machine_gun.is_reloading = false
	machine_gun.reload_time_left = 0.0
	machine_gun.is_on_cooldown = false
	_assert_true(machine_gun.request_reload(), "Manual reload setup should start reload with ammo remaining.")
	if _failed:
		return
	player.assist_system.handle_post_fire(machine_gun, true)
	_assert_equal(1, PlayerData.main_weapon_index, "Auto reload switch should move when the current weapon starts reload, regardless of remaining ammo.")
	if _failed:
		return

	PlayerData.set_main_weapon_index(0)
	player.refresh_weapon_structure_for_assist()
	machine_gun.current_ammo = 1
	machine_gun.is_reloading = false
	machine_gun.reload_time_left = 0.0
	machine_gun.is_on_cooldown = false
	shotgun.current_ammo = maxi(shotgun.current_ammo, 1)
	player.assist_system.process_combat_assist(machine_gun, false, 0.016)
	await get_tree().process_frame
	_assert_true(machine_gun.is_reloading, "Empty weapon should enter reload after auto fire spends the last ammo.")
	if _failed:
		return
	_assert_equal(1, PlayerData.main_weapon_index, "Auto reload switch should move to the next ready weapon.")
	if _failed:
		return

	PlayerData.set_main_weapon_index(1)
	player.refresh_weapon_structure_for_assist()
	await get_tree().process_frame
	cannon.windup_sec = 0.05
	cannon.current_ammo = 1
	cannon.is_reloading = false
	cannon.reload_time_left = 0.0
	cannon.is_on_cooldown = false
	cannon.set("_windup_in_progress", false)
	shotgun.current_ammo = maxi(shotgun.current_ammo, 1)
	if shotgun.get("is_on_cooldown") != null:
		shotgun.set("is_on_cooldown", false)
	enemy.global_position = Vector2(180.0, 40.0)
	player.assist_system.process_combat_assist(cannon, false, 0.016)
	_assert_true(cannon.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Delayed auto fire should keep the aim target through windup. %s" % _describe_weapon_state(cannon))
	if _failed:
		return
	_assert_true(cannon.has_meta(PlayerAssistSystem.AUTO_FIRE_PENDING_META), "Delayed auto fire should mark the weapon pending through windup.")
	if _failed:
		return
	await get_tree().create_timer(0.08).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var expected_direction := cannon.global_position.direction_to(enemy.global_position).normalized()
	_assert_vector_almost_equal(expected_direction, cannon.projectile_direction, 0.001, "Delayed Cannon shot should use the auto-aim target, not the mouse fallback.")
	if _failed:
		return
	_assert_true(not cannon.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Delayed auto fire should clear the aim target after the real shot.")
	if _failed:
		return
	_assert_true(not cannon.has_meta(PlayerAssistSystem.AUTO_FIRE_PENDING_META), "Delayed auto fire should clear pending state after the real shot.")
	if _failed:
		return
	_assert_true(cannon.is_reloading, "Delayed Cannon shot should enter reload after spending the last ammo.")
	if _failed:
		return
	_assert_equal(2, PlayerData.main_weapon_index, "Delayed empty Cannon shot should auto-switch after reload state is applied.")
	if _failed:
		return

	EnemyRegistry.unregister_enemy(enemy)
	PlayerData.set_main_weapon_index(1)
	player.refresh_weapon_structure_for_assist()
	cannon.is_reloading = true
	cannon.reload_time_left = 1.0
	cannon.set_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META, Vector2(12.0, 0.0))
	cannon.set_meta(PlayerAssistSystem.AUTO_FIRE_PENDING_META, true)
	shotgun.current_ammo = maxi(shotgun.current_ammo, 1)
	if shotgun.get("is_on_cooldown") != null:
		shotgun.set("is_on_cooldown", false)
	player.assist_system.process_combat_assist(cannon, false, 0.016)
	_assert_equal(2, PlayerData.main_weapon_index, "Auto reload switch should recover when the main weapon is already reloading without a current target.")
	if _failed:
		return
	_assert_true(not cannon.has_meta(PlayerAssistSystem.AUTO_AIM_TARGET_META), "Reload recovery switch should clear stale Cannon auto aim target.")
	if _failed:
		return
	_assert_true(not cannon.has_meta(PlayerAssistSystem.AUTO_FIRE_PENDING_META), "Reload recovery switch should clear stale Cannon pending state.")
	if _failed:
		return

	_pass()

func _add_weapon(scene: PackedScene, index: int) -> Weapon:
	var weapon := scene.instantiate() as Weapon
	if weapon == null:
		return null
	add_child(weapon)
	weapon.position = Vector2.ZERO
	weapon.set_weapon_role("main" if index == 0 else "offhand")
	PlayerData.player_weapon_list.append(weapon)
	return weapon

func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	if expected == actual:
		return
	_fail("%s Expected=%s actual=%s" % [message, str(expected), str(actual)])

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	_fail(message)

func _assert_almost_equal(expected: float, actual: float, tolerance: float, message: String) -> void:
	if absf(angle_difference(expected, actual)) <= tolerance:
		return
	_fail("%s Expected=%s actual=%s" % [message, str(expected), str(actual)])

func _assert_vector_almost_equal(expected: Vector2, actual: Vector2, tolerance: float, message: String) -> void:
	if expected.distance_to(actual) <= tolerance:
		return
	_fail("%s Expected=%s actual=%s" % [message, str(expected), str(actual)])

func _describe_weapon_state(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return "weapon=null"
	return "ammo=%s reloading=%s cooldown=%s windup=%s has_signal=%s can_ammo=%s can_heat=%s role=%s phase=%s" % [
		str(weapon.get("current_ammo")),
		str(weapon.get("is_reloading")),
		str(weapon.get("is_on_cooldown")),
		str(weapon.get("_windup_in_progress")),
		str(weapon.has_signal("shoot")),
		str(weapon.call("can_fire_with_ammo") if weapon.has_method("can_fire_with_ammo") else null),
		str(weapon.call("can_fire_with_heat") if weapon.has_method("can_fire_with_heat") else null),
		str(weapon.get("weapon_role")),
		str(PhaseManager.current_state() if PhaseManager != null and PhaseManager.has_method("current_state") else "unknown"),
	]

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("FAIL: player assist settings")
	get_tree().quit(1)

func _pass() -> void:
	print("PASS: player assist settings")
	get_tree().quit(0)
