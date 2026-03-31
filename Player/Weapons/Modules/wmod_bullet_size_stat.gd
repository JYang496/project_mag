extends Module
# Use on projectile weapons to multiply projectile visual and hitbox size.

var ITEM_NAME = "Size Up"
@export var mult_by = 1.5

func configure_stat_modifiers() -> void:
	stat_multipliers["size"] = mult_by
