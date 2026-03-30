extends Projectile
class_name PlasmaLanceProjectile

@export var damage_gain_per_pierce: int = 3

func enemy_hit(charge: int = 1):
	hp -= charge
	if hp > 0:
		damage += max(0, damage_gain_per_pierce)
	if hp <= 0:
		call_deferred("despawn")
