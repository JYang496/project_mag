extends Module
# Use on timed-attack weapons to reduce attack cooldown between shots.

var ITEM_NAME = "Faster Reload"
@export var mult_by = 0.8

func configure_stat_modifiers() -> void:
	stat_multipliers["attack_cooldown"] = mult_by
