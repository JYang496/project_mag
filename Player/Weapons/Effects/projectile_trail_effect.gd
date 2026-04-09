extends Effect
class_name ProjectileTrailEffect

@export var trail_color: Color = Color(0.7, 0.9, 1.0, 0.9)
@export var trail_width: float = 2.0
@export var max_points: int = 14
@export var sample_interval_sec: float = 0.012
@export var trail_fade_sec: float = 0.18

@onready var line_2d: Line2D = $Line2D

var _sample_accum_sec: float = 0.0

func projectile_effect_ready() -> void:
	if line_2d == null:
		return
	line_2d.width = maxf(trail_width, 0.2)
	line_2d.default_color = trail_color
	line_2d.clear_points()
	_record_point()

func _process(delta: float) -> void:
	if projectile == null or not is_instance_valid(projectile):
		queue_free()
		return
	if line_2d == null:
		return
	_sample_accum_sec += maxf(delta, 0.0)
	var step := maxf(sample_interval_sec, 0.004)
	while _sample_accum_sec >= step:
		_sample_accum_sec -= step
		_record_point()
	_apply_dynamic_limits(step)

func _record_point() -> void:
	if line_2d == null:
		return
	var local_pos := to_local(projectile.global_position)
	line_2d.add_point(local_pos)

func _apply_dynamic_limits(step: float) -> void:
	if line_2d == null:
		return
	var fade_points := int(ceil(maxf(trail_fade_sec, 0.05) / step))
	var limit := maxi(3, maxi(max_points, fade_points))
	while line_2d.get_point_count() > limit:
		line_2d.remove_point(0)
