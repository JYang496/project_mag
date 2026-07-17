extends ProgressBar
class_name SmoothProgressBar

@export_range(1.0, 40.0, 0.5) var smoothing_speed := 12.0
@export var snap_epsilon := 0.0005

var _target_value := 0.0

func _ready() -> void:
	_target_value = value
	set_process(false)

func set_target_value(next_value: float, immediate: bool = false) -> void:
	_target_value = clampf(next_value, min_value, max_value)
	if immediate or not is_inside_tree():
		value = _target_value
		set_process(false)
		return
	set_process(not is_equal_approx(value, _target_value))

func snap_to_target() -> void:
	value = _target_value
	set_process(false)

func _process(delta: float) -> void:
	var weight := 1.0 - exp(-smoothing_speed * maxf(delta, 0.0))
	value = lerpf(value, _target_value, weight)
	var threshold := maxf(snap_epsilon, absf(max_value - min_value) * snap_epsilon)
	if absf(value - _target_value) <= threshold:
		snap_to_target()
