extends Module

var ITEM_NAME = "Pierce"
@export var pierce_add_by = 2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	supports_melee = false
	if weapon and weapon.has_signal("calculate_weapon_projectile_hits"):
		weapon.calculate_weapon_projectile_hits.connect(add_pierce)


func add_pierce(arg):
	weapon.projectile_hits = int(arg + pierce_add_by)
