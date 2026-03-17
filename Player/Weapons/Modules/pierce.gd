extends Module

var ITEM_NAME = "Pierce"
@export var pierce_add_by = 2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_weapon_projectile_hits"):
		weapon.calculate_weapon_projectile_hits.connect(add_pierce)


func add_pierce(arg):
	var final_bonus: int = int(round(get_effective_additive(float(pierce_add_by))))
	weapon.projectile_hits = int(arg) + max(1, final_bonus)
