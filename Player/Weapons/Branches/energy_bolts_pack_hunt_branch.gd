extends WeaponBranchBehavior
class_name EnergyBoltsPackHuntBranch

func uses_energy_bolt_pack_hunt() -> bool:
	return true

func get_energy_bolt_homing_turn_multiplier() -> float:
	return get_fusion_enhancement_factor()
