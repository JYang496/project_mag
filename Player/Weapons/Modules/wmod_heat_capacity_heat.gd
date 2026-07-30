extends Module
# Stabilizes the current polarity without changing the fixed -100..100 bounds.

var ITEM_NAME := "Thermal Inertia"

@export var opposition_resistance: float = 0.25

func configure_stat_modifiers() -> void:
	stat_additives["heat_opposition_resistance"] = opposition_resistance
