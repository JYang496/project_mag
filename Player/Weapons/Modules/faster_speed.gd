extends Module

var ITEM_NAME = "Faster Speed"
@export var mult_by = 1.2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_weapon_speed"):
		weapon.calculate_weapon_speed.connect(add)


func add(arg):
	var final_mult := get_effective_multiplier(mult_by)
	var final_speed: float = float(arg) * final_mult
	if weapon and weapon.has_method("supports_melee_contact") and weapon.supports_melee_contact():
		if weapon.get("dash_speed") != null:
			weapon.dash_speed = final_speed
		if weapon.get("base_return_speed") != null:
			weapon.return_speed = float(weapon.base_return_speed) * final_mult
		elif weapon.get("return_speed") != null:
			weapon.return_speed = float(weapon.return_speed) * final_mult
		return
	if weapon.get("speed") != null:
		weapon.speed = final_speed
