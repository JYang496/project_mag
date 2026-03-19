extends Module

var ITEM_NAME = "More HP"
@export var hp_add_by: int = 2

func configure_stat_modifiers() -> void:
	stat_additives["hp"] = float(hp_add_by)
