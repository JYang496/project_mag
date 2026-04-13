extends Projectile
class_name SniperProjectile

@export var pierce_damage_gain_per_hit: int = 0
@export var max_pierce_damage_stacks: int = 0

var _pierce_damage_stacks: int = 0

func on_hit_target(target: Node) -> void:
	if source_weapon and is_instance_valid(source_weapon) and source_weapon.has_method("set_last_projectile_hit_damage"):
		source_weapon.call("set_last_projectile_hit_damage", int(damage))
	super.on_hit_target(target)

func enemy_hit(charge: int = 1):
	hp -= charge
	if hp > 0:
		_apply_pierce_damage_growth()
	if hp <= 0:
		call_deferred("despawn")

func _apply_pierce_damage_growth() -> void:
	if pierce_damage_gain_per_hit <= 0:
		return
	if max_pierce_damage_stacks > 0 and _pierce_damage_stacks >= max_pierce_damage_stacks:
		return
	_pierce_damage_stacks += 1
	damage += max(0, pierce_damage_gain_per_hit)

