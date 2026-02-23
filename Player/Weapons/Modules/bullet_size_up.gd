extends Module

var ITEM_NAME = "Bullet Size Up"
@export var mult_by = 1.2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	supports_melee = false
	if weapon and weapon.has_signal("calculate_bullet_size"):
		weapon.calculate_bullet_size.connect(mult)


func mult(arg):
	weapon.size = float(arg * mult_by)
