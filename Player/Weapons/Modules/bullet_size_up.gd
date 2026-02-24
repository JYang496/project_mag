extends Module

var ITEM_NAME = "Size Up"
@export var mult_by = 1.2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_projectile_size"):
		weapon.calculate_projectile_size.connect(mult_projectile)
	if weapon and weapon.has_signal("calculate_weapon_size"):
		weapon.calculate_weapon_size.connect(mult_weapon)


func mult_projectile(arg):
	weapon.size = float(arg * mult_by)

func mult_weapon(arg):
	var final_size: float = float(arg) * mult_by
	weapon.size = final_size
	if weapon and weapon.has_method("apply_size_multiplier"):
		weapon.apply_size_multiplier(final_size)
