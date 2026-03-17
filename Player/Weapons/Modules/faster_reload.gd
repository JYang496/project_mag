extends Module

var ITEM_NAME = "Faster Reload"
@export var mult_by = 0.7
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_attack_cooldown"):
		weapon.calculate_attack_cooldown.connect(mult)


func mult(arg):
	var final_mult := get_effective_multiplier(mult_by)
	weapon.attack_cooldown = float(arg) * final_mult
