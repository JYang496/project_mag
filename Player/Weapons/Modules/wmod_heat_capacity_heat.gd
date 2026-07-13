extends Module
# Use on HEAT weapons to raise the capped heat resource capacity.

var ITEM_NAME := "Heat Capacity"

@export var capacity_mult: float = 1.5

func configure_stat_modifiers() -> void:
	stat_multipliers["heat_max_value"] = capacity_mult
