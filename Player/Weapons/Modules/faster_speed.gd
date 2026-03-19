extends Module

var ITEM_NAME = "Faster Speed"
@export var mult_by = 1.2

func configure_stat_modifiers() -> void:
	stat_multipliers["speed"] = mult_by
	stat_multipliers["dash_speed"] = mult_by
	stat_multipliers["return_speed"] = mult_by
