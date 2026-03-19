extends Module

var ITEM_NAME = "Size Up"
@export var mult_by = 1.2

func configure_stat_modifiers() -> void:
	stat_multipliers["size"] = mult_by
