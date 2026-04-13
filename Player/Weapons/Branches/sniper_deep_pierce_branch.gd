extends WeaponBranchBehavior
class_name SniperDeepPierceBranch

@export var cooldown_multiplier: float = 1.05
@export var projectile_damage_multiplier: float = 0.92
@export var pierce_damage_gain_per_hit: int = 14
@export var max_pierce_damage_stacks: int = 10

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

func get_pierce_damage_gain_per_hit() -> int:
	return max(0, pierce_damage_gain_per_hit)

func get_max_pierce_damage_stacks() -> int:
	return max(0, max_pierce_damage_stacks)

