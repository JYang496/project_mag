@tool
extends EffectConfig
class_name EnemySeekSteerEffectConfig

@export var turn_rate_deg_per_sec: float = 82.5
@export var search_radius: float = 260.0
@export var max_lock_angle_deg: float = 85.0
@export var retarget_interval_sec: float = 0.05
@export var min_speed_ratio: float = 1.0

func _init() -> void:
	effect_id = &"enemy_seek_steer"
	priority = 10

func build_params() -> Dictionary:
	return {
		"turn_rate_deg_per_sec": turn_rate_deg_per_sec,
		"search_radius": search_radius,
		"max_lock_angle_deg": max_lock_angle_deg,
		"retarget_interval_sec": retarget_interval_sec,
		"min_speed_ratio": min_speed_ratio,
	}
