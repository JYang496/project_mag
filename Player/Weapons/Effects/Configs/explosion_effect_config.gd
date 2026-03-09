@tool
extends EffectConfig
class_name ExplosionEffectConfig

@export var damage: int = 10
@export var explosion_size: float = 2.0
@export var base_radius: float = 24.0
@export var duration: float = 0.1
@export var area_tick_damage: int = 0
@export var area_tick_interval: float = 0.4
@export var damage_type: StringName = Attack.TYPE_PHYSICAL

func _init() -> void:
	effect_id = &"explosion_effect"

# Builds runtime params consumed by Effect.configure().
func build_params() -> Dictionary:
	return {
		"damage": damage,
		"explosion_size": explosion_size,
		"base_radius": base_radius,
		"duration": duration,
		"area_tick_damage": area_tick_damage,
		"area_tick_interval": area_tick_interval,
		"damage_type": damage_type,
	}

