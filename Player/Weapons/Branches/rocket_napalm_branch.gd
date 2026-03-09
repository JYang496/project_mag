extends WeaponBranchBehavior
class_name RocketNapalmBranch

@export var cooldown_multiplier: float = 1.2
@export var projectile_damage_multiplier: float = 0.8
@export var explosion_size_multiplier: float = 1.1
@export var napalm_duration: float = 2.2
@export var napalm_tick_damage_ratio: float = 0.2
@export var napalm_tick_interval: float = 0.35

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

# Mutates explosion config before projectile launch to add persistent burn damage.
func modify_explosion_config(config: ExplosionEffectConfig) -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if config == null:
		return
	var weapon_damage := 1
	if weapon.get("damage") != null:
		weapon_damage = max(1, int(weapon.damage))
	config.explosion_size = maxf(config.explosion_size * explosion_size_multiplier, 0.1)
	config.duration = maxf(napalm_duration, 0.1)
	config.area_tick_interval = maxf(napalm_tick_interval, 0.05)
	config.area_tick_damage = max(1, int(round(float(weapon_damage) * napalm_tick_damage_ratio)))
