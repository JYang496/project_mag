extends RefCounted
class_name PlayerWeaponAutoFireRuntime

var player: Player

func setup(source_player: Player) -> void:
	player = source_player

func process(delta: float) -> void:
	if PhaseManager.current_state() != PhaseManager.BATTLE:
		clear()
		return
	for weapon_ref in player.get_all_weapons():
		var weapon := weapon_ref as Weapon
		var target := weapon.find_auto_fire_target()
		if target == null:
			weapon.clear_automatic_aim_target()
			weapon.stop_automatic_fire()
			continue
		weapon.set_automatic_aim_target(target.global_position)
		weapon.prepare_automatic_aim(delta)
		weapon.request_automatic_fire()

func clear() -> void:
	for weapon_ref in player.get_all_weapons():
		var weapon := weapon_ref as Weapon
		weapon.clear_automatic_aim_target()
		weapon.stop_automatic_fire()
