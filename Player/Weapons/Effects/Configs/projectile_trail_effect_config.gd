@tool
extends EffectConfig
class_name ProjectileTrailEffectConfig

@export var trail_color: Color = Color(0.7, 0.9, 1.0, 0.9)
@export var trail_width: float = 2.0
@export var max_points: int = 14
@export var sample_interval_sec: float = 0.012
@export var trail_fade_sec: float = 0.18

func _init() -> void:
	effect_id = &"projectile_trail"

func build_params() -> Dictionary:
	return {
		"trail_color": trail_color,
		"trail_width": trail_width,
		"max_points": max_points,
		"sample_interval_sec": sample_interval_sec,
		"trail_fade_sec": trail_fade_sec,
	}
