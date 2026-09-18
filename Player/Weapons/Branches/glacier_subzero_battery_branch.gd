extends WeaponBranchBehavior
class_name GlacierSubzeroBatteryBranch

func get_glacier_cold_snap_ammo_refund() -> int:
	if weapon == null or not is_instance_valid(weapon):
		return 0
	return maxi(weapon.get_effective_magazine_capacity(), 0)
