extends Weapon

var active_execution_count: int = 0
var last_active_damage_multiplier: float = 0.0
var active_should_succeed: bool = true

func uses_ammo_system() -> bool:
	return true

func _execute_weapon_active(damage_multiplier: float) -> bool:
	active_execution_count += 1
	last_active_damage_multiplier = damage_multiplier
	return active_should_succeed
