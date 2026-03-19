extends Module

var ITEM_NAME = "Faster Reload"
@export var mult_by = 0.7

func configure_stat_modifiers() -> void:
	stat_multipliers["attack_cooldown"] = mult_by
