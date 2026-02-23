extends Module

var ITEM_NAME = "More HP"
@export var add_by = 2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	supports_melee = false
	if weapon and weapon.has_signal("calculate_weapon_bullet_hits"):
		weapon.calculate_weapon_bullet_hits.connect(add)


func add(arg):
	weapon.bullet_hits = int(arg + add_by)
