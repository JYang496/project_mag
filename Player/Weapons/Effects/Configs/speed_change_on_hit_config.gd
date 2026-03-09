@tool
extends EffectConfig
class_name SpeedChangeOnHitEffectConfig

@export var speed_rate: float = 0.3

func _init() -> void:
	effect_id = &"speed_change_on_hit"

# Builds runtime params consumed by Effect.configure().
func build_params() -> Dictionary:
	return {
		"speed_rate": speed_rate,
	}
