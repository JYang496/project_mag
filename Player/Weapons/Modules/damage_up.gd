extends Module

var ITEM_NAME = "Damage Up"
@export var mult_by: float = 1.5

func configure_stat_modifiers() -> void:
	stat_multipliers["damage"] = mult_by
