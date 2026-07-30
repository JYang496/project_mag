extends WeaponBranchBehavior
class_name CannonZeroBranch

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_suppressed_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.PHYSICAL]

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func get_energy_gain_per_damage_event() -> float:
	return 10.0

func get_energy_release_bonus_at_full() -> float:
	return 1.50

func get_energy_full_fire_passive_id() -> StringName:
	return &"cannon_zero_energy_cycle"

func get_energy_full_fire_display_name() -> String:
	return "Zero Burst"
