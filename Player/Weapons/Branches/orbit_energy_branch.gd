extends WeaponBranchBehavior
class_name OrbitEnergyBranch

func get_added_weapon_traits() -> Array[StringName]:
	return [WeaponTrait.ENERGY]

func get_damage_type_override() -> StringName:
	return Attack.TYPE_ENERGY

func get_empowered_attack_bonus() -> float:
	return 0.0

func get_energy_deployment_config() -> Dictionary:
	return {
		"extra_satellites": 2,
		"lifetime_multiplier": 1.5,
	}

func get_added_delivery_types() -> Array[StringName]:
	return [DamageDeliveryType.AREA]

func get_empowered_attack_passive_id() -> StringName:
	return &"orbit_energy_cycle"

func get_empowered_attack_display_name() -> String:
	return "Orbital Pulse"
