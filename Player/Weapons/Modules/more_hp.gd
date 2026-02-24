extends Module

var ITEM_NAME = "More HP"
@export var hp_add_by: int = 2

func _ready() -> void:
	if weapon and weapon.has_signal("calculate_weapon_hp"):
		weapon.calculate_weapon_hp.connect(add_hp)

func add_hp(arg) -> void:
	if weapon.get("hp") == null:
		return
	weapon.hp = int(arg + hp_add_by)
