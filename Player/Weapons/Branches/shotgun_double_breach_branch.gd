extends WeaponBranchBehavior
class_name ShotgunDoubleBreachBranch

@export var wave_damage_multiplier: float = 0.65
@export var cooldown_multiplier: float = 1.0
@export var second_wave_delay_sec: float = 0.12
@export var second_spread_multiplier: float = 0.65
@export var ammo_cost: int = 2

func get_projectile_damage_multiplier() -> float:
	return maxf(wave_damage_multiplier, 0.05)

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_shotgun_double_volley_config() -> Dictionary:
	return {
		"second_wave_delay_sec": maxf(second_wave_delay_sec, 0.01),
		"second_spread_multiplier": clampf(second_spread_multiplier, 0.05, 1.0),
		"ammo_cost": maxi(ammo_cost, 1),
	}
