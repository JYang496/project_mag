extends RefCounted
class_name PlayerWeaponAutoFireRuntime

var player: Node
var _continuous_fire_lost_time_by_weapon: Dictionary = {}

func setup(source_player: Node) -> void:
	player = source_player

func process(delta: float) -> void:
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		clear()
		return
	var active_weapon_ids: Dictionary = {}
	for weapon_ref in player.get_all_weapons():
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		var weapon_id := weapon.get_instance_id()
		active_weapon_ids[weapon_id] = true
		if weapon.is_main_weapon():
			_stop_weapon(weapon, weapon_id)
			continue
		var target := weapon.find_auto_fire_target()
		if target == null:
			_process_missing_target(weapon, weapon_id, delta)
			continue
		_continuous_fire_lost_time_by_weapon[weapon_id] = 0.0
		weapon.set_automatic_aim_target(target.global_position)
		weapon.prepare_automatic_aim(delta)
		weapon.request_automatic_fire()
	_clear_removed_weapon_states(active_weapon_ids)

func _process_missing_target(weapon: Weapon, weapon_id: int, delta: float) -> void:
	if not weapon.uses_continuous_automatic_fire() \
			or not _continuous_fire_lost_time_by_weapon.has(weapon_id):
		_stop_weapon(weapon, weapon_id)
		return
	var lost_time := float(_continuous_fire_lost_time_by_weapon[weapon_id]) + maxf(delta, 0.0)
	var grace_sec := maxf(weapon.get_automatic_fire_target_grace_sec(), 0.0)
	if lost_time > grace_sec:
		_stop_weapon(weapon, weapon_id)
		return
	_continuous_fire_lost_time_by_weapon[weapon_id] = lost_time
	weapon.prepare_automatic_aim(delta)
	weapon.request_automatic_fire()

func _stop_weapon(weapon: Weapon, weapon_id: int) -> void:
	_continuous_fire_lost_time_by_weapon.erase(weapon_id)
	weapon.clear_automatic_aim_target()
	weapon.stop_automatic_fire()

func _clear_removed_weapon_states(active_weapon_ids: Dictionary) -> void:
	for weapon_id in _continuous_fire_lost_time_by_weapon.keys():
		if not active_weapon_ids.has(weapon_id):
			_continuous_fire_lost_time_by_weapon.erase(weapon_id)

func clear() -> void:
	for weapon_ref in player.get_all_weapons():
		var weapon := weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		weapon.clear_automatic_aim_target()
		weapon.stop_automatic_fire()
	_continuous_fire_lost_time_by_weapon.clear()
