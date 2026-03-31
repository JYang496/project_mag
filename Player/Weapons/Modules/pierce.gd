extends Module
# Use on projectile weapons to increase the number of targets pierced per shot.

var ITEM_NAME = "Pierce"
@export var pierce_add_by = 2

func configure_stat_modifiers() -> void:
	stat_additives["projectile_hits"] = float(pierce_add_by)
