@tool
extends EffectConfig
class_name LinearMovementEffectConfig

@export var direction: Vector2 = Vector2.ZERO
@export var speed: float = 0.0

func _init() -> void:
	effect_id = &"linear_movement"

# Builds runtime params consumed by Effect.configure().
func build_params() -> Dictionary:
	return {
		"direction": direction,
		"speed": speed,
	}
