extends Module

var ITEM_NAME = "More HP"
@export var add_by = 2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_weapon_hp"):
		weapon.calculate_weapon_hp.connect(add)


func add(arg):
	weapon.hp = int(arg + add_by)
