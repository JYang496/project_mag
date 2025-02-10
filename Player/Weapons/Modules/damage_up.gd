extends Module

var mult_by = 1.5
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_weapon_damage"):
		weapon.calculate_weapon_damage.connect(mult)
		

func mult(pre_damage):
	weapon.damage = int(pre_damage * mult_by)
