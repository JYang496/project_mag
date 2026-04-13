extends WeaponBranchBehavior
class_name ChainsawRicochetBranch

@export var cooldown_multiplier: float = 1.0
@export var projectile_damage_multiplier: float = 1.0

func get_cooldown_multiplier() -> float:
	return maxf(cooldown_multiplier, 0.05)

func get_projectile_damage_multiplier() -> float:
	return maxf(projectile_damage_multiplier, 0.05)

func on_chainsaw_target_hit(target: Node, projectile: Projectile) -> void:
	if target == null or not is_instance_valid(target):
		return
	_split_and_ricochet_projectile(projectile)

func _split_and_ricochet_projectile(projectile: Projectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if bool(projectile.get_meta("ricochet_split_done", false)):
		return
	if weapon == null or not is_instance_valid(weapon):
		return
	if not weapon.has_method("split_projectile_with_ricochet"):
		return
	weapon.call("split_projectile_with_ricochet", projectile)
