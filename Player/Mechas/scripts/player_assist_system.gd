extends RefCounted
class_name PlayerAssistSystem

const AUTO_AIM_TARGET_META: StringName = &"_player_assist_auto_aim_target"
const AUTO_FIRE_PENDING_META: StringName = &"_player_assist_auto_fire_pending"

var _player: Node

func setup(player: Node) -> void:
	_player = player

func process_combat_assist(main_weapon: Weapon, manual_fire_pressed: bool, delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if main_weapon == null or not is_instance_valid(main_weapon):
		return
	if manual_fire_pressed:
		_clear_auto_assist_state(main_weapon)
		return
	if not _is_auto_aim_continuous_fire_enabled():
		_clear_auto_assist_state(main_weapon)
		return
	var target := _find_auto_aim_target(main_weapon)
	if target == null:
		_clear_auto_assist_state(main_weapon)
		return
	_set_auto_aim_target(main_weapon, target.global_position)
	if bool(main_weapon.get_meta(AUTO_FIRE_PENDING_META, false)):
		return
	_request_auto_fire_at_target(main_weapon, target, delta)

func handle_post_fire(main_weapon: Weapon, fired: bool) -> void:
	if not fired:
		return
	if not _is_auto_reload_switch_enabled():
		return
	if main_weapon == null or not is_instance_valid(main_weapon):
		return
	if not _is_weapon_reloading(main_weapon):
		return
	shift_to_next_ready_weapon(main_weapon, 1)

func shift_to_next_ready_weapon(current_weapon: Weapon, step: int = 1) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if PlayerData == null:
		return false
	PlayerData.sanitize_main_weapon_index()
	var weapons: Array = PlayerData.player_weapon_list
	var size: int = weapons.size()
	if size <= 1:
		return false
	var current_index := PlayerData.main_weapon_index
	if current_index < 0:
		current_index = weapons.find(current_weapon)
	if current_index < 0:
		return false
	var direction := 1 if step >= 0 else -1
	for offset in range(1, size):
		var index := (current_index + direction * offset) % size
		if index < 0:
			index += size
		var candidate := weapons[index] as Weapon
		if not _can_auto_switch_to_weapon(candidate):
			continue
		var old_main := _get_player_main_weapon()
		PlayerData.set_main_weapon_index(index)
		if _player.has_method("mark_weapon_roles_dirty_for_assist"):
			_player.call("mark_weapon_roles_dirty_for_assist")
		if _player.has_method("refresh_weapon_structure_for_assist"):
			_player.call("refresh_weapon_structure_for_assist")
		var new_main := _get_player_main_weapon()
		_clear_weapon_auto_aim_target(current_weapon)
		if _player.has_method("broadcast_weapon_passive_event_for_assist"):
			_player.call("broadcast_weapon_passive_event_for_assist", &"on_main_swapped", {
			"old_main": old_main,
			"new_main": new_main,
			"source": "auto_reload_switch",
			})
		return true
	return false

func _request_auto_fire_at_target(main_weapon: Weapon, target: Node2D, delta: float) -> void:
	var target_position := target.global_position
	var ammo_before_input := int(main_weapon.get("current_ammo")) if main_weapon.get("current_ammo") != null else 0
	var was_reloading_before_input := bool(main_weapon.get("is_reloading")) if main_weapon.get("is_reloading") != null else false
	var shot_state := {"observed": false}
	var shot_connection := _connect_auto_fire_shot_callback(
		main_weapon,
		func() -> void:
			shot_state["observed"] = true
	)
	main_weapon.set_meta(AUTO_FIRE_PENDING_META, true)
	_set_auto_aim_target(main_weapon, target_position)
	if main_weapon.has_method("_update_weapon_rotation"):
		main_weapon.call("_update_weapon_rotation")
	var fired := false
	if main_weapon.has_method("handle_primary_input"):
		main_weapon.call("handle_primary_input", true, false, false, delta)
		fired = (
			bool(shot_state.get("observed", false))
			or _did_auto_fire_spend_ammo(main_weapon, ammo_before_input, was_reloading_before_input)
			or _did_auto_fire_start_reload(main_weapon, was_reloading_before_input)
		)
	elif main_weapon.has_method("request_primary_fire"):
		fired = bool(main_weapon.call("request_primary_fire"))
		if not fired:
			fired = _did_auto_fire_start_reload(main_weapon, was_reloading_before_input)
	if not bool(shot_connection.get("connected", false)) or not fired:
		_disconnect_auto_fire_shot_callback(main_weapon, shot_connection)
		_clear_auto_fire_pending(main_weapon)
		handle_post_fire(main_weapon, fired)
	elif not bool(shot_state.get("observed", false)):
		# Delayed-fire weapons such as Cannon keep the target meta until their windup emits shoot.
		return
	else:
		_clear_auto_fire_pending(main_weapon)

func _connect_auto_fire_shot_callback(
	main_weapon: Weapon,
	on_shot_observed: Callable
) -> Dictionary:
	if main_weapon == null or not is_instance_valid(main_weapon):
		return {}
	if not main_weapon.has_signal("shoot"):
		return {}
	var callback := func() -> void:
		on_shot_observed.call()
		call_deferred("_on_auto_fire_shot_committed", main_weapon)
	main_weapon.connect("shoot", callback, CONNECT_ONE_SHOT)
	return {
		"connected": true,
		"callback": callback,
	}

func _disconnect_auto_fire_shot_callback(main_weapon: Weapon, connection: Dictionary) -> void:
	if main_weapon == null or not is_instance_valid(main_weapon):
		return
	if not bool(connection.get("connected", false)):
		return
	var callback := connection.get("callback", Callable()) as Callable
	if main_weapon.has_signal("shoot") and main_weapon.is_connected("shoot", callback):
		main_weapon.disconnect("shoot", callback)

func _on_auto_fire_shot_committed(main_weapon: Weapon) -> void:
	if main_weapon == null or not is_instance_valid(main_weapon):
		return
	var fired := true
	_clear_auto_fire_pending(main_weapon)
	handle_post_fire(main_weapon, fired)

func _set_auto_aim_target(main_weapon: Weapon, target_position: Vector2) -> void:
	if main_weapon != null and is_instance_valid(main_weapon):
		main_weapon.set_meta(AUTO_AIM_TARGET_META, target_position)
	_clear_player_auto_aim_target()

func _clear_auto_assist_state(main_weapon: Weapon) -> void:
	_clear_auto_fire_pending(main_weapon)
	_clear_player_auto_aim_target()
	_clear_weapon_auto_aim_target(main_weapon)

func _clear_player_auto_aim_target() -> void:
	if _player != null and is_instance_valid(_player) and _player.has_meta(AUTO_AIM_TARGET_META):
		_player.remove_meta(AUTO_AIM_TARGET_META)

func _clear_weapon_auto_aim_target(main_weapon: Weapon) -> void:
	if main_weapon != null and is_instance_valid(main_weapon) and main_weapon.has_meta(AUTO_AIM_TARGET_META):
		main_weapon.remove_meta(AUTO_AIM_TARGET_META)

func _clear_auto_fire_pending(main_weapon: Weapon) -> void:
	if main_weapon != null and is_instance_valid(main_weapon) and main_weapon.has_meta(AUTO_FIRE_PENDING_META):
		main_weapon.remove_meta(AUTO_FIRE_PENDING_META)

func _find_auto_aim_target(main_weapon: Weapon) -> Node2D:
	if main_weapon.has_method("find_auto_fire_target"):
		var auto_fire_target_variant: Variant = main_weapon.call("find_auto_fire_target")
		var auto_fire_target := auto_fire_target_variant as Node2D
		if auto_fire_target != null and is_instance_valid(auto_fire_target):
			return auto_fire_target
		return null
	if main_weapon.has_method("find_closest_enemy"):
		var target_variant: Variant = main_weapon.call("find_closest_enemy", main_weapon.global_position)
		var target := target_variant as Node2D
		if target != null and is_instance_valid(target):
			return target
	return null

func _can_auto_switch_to_weapon(weapon: Weapon) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if _is_auto_fire_weapon(weapon):
		return false
	if not weapon.has_method("can_fire_with_ammo") or not bool(weapon.call("can_fire_with_ammo")):
		return false
	if weapon.has_method("can_fire_with_heat") and not bool(weapon.call("can_fire_with_heat")):
		return false
	if weapon.get("is_on_cooldown") != null and bool(weapon.get("is_on_cooldown")):
		return false
	return true

func _get_player_main_weapon() -> Weapon:
	if _player == null or not is_instance_valid(_player):
		return null
	if not _player.has_method("get_main_weapon"):
		return null
	var weapon_variant: Variant = _player.call("get_main_weapon")
	return weapon_variant as Weapon

func _is_weapon_reloading(weapon: Weapon) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if not weapon.has_method("uses_ammo_system") or not bool(weapon.call("uses_ammo_system")):
		return false
	return bool(weapon.get("is_reloading"))

func _did_auto_fire_start_reload(weapon: Weapon, was_reloading_before_input: bool) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if was_reloading_before_input:
		return false
	return _is_weapon_reloading(weapon)

func _did_auto_fire_spend_ammo(weapon: Weapon, ammo_before_input: int, was_reloading_before_input: bool) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if was_reloading_before_input:
		return false
	if ammo_before_input <= 0:
		return false
	if not weapon.has_method("uses_ammo_system") or not bool(weapon.call("uses_ammo_system")):
		return false
	return int(weapon.get("current_ammo")) < ammo_before_input

func _is_auto_fire_weapon(weapon: Weapon) -> bool:
	if weapon == null or not is_instance_valid(weapon):
		return false
	if not weapon.has_method("has_weapon_trait"):
		return false
	return bool(weapon.call("has_weapon_trait", WeaponTrait.AUTO_FIRE))

func _is_auto_aim_continuous_fire_enabled() -> bool:
	return PlayerAssistSettings != null and bool(PlayerAssistSettings.auto_aim_continuous_fire)

func _is_auto_reload_switch_enabled() -> bool:
	return PlayerAssistSettings != null and bool(PlayerAssistSettings.auto_reload_switch)
