extends Module

var ITEM_NAME = "Faster Speed"
@export var mult_by = 1.2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_weapon_speed"):
		weapon.calculate_weapon_speed.connect(add)


func add(arg):
	weapon.speed = int(arg * mult_by)
