extends WeaponBranchBehavior
class_name OrbitEnergyBranch

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func get_energy_gain_per_damage_event() -> float:
	return 8.0

func get_energy_release_bonus_at_full() -> float:
	return 0.35

func get_added_delivery_types() -> Array[StringName]:
	return [DamageDeliveryType.AREA]

func get_energy_full_fire_passive_id() -> StringName:
	return &"orbit_energy_cycle"

func get_energy_full_fire_display_name() -> String:
	return "Orbital Pulse"
