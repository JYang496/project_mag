extends WeaponBranchBehavior
class_name GlacierSubzeroBatteryBranch

@export var cold_snap_ammo_refund: int = 6

func get_glacier_cold_snap_ammo_refund() -> int:
	return maxi(cold_snap_ammo_refund, 0)
