extends Node

# Tunable elite-kill slowdown profile.
@export_range(0.05, 1.0, 0.01) var elite_kill_slow_scale: float = 0.28
@export_range(0.01, 1.0, 0.01) var elite_kill_slow_duration: float = 0.1
@export_range(0.01, 2.0, 0.01) var elite_kill_recovery_duration: float = 0.28
@export var reset_to_normal_on_exit: bool = true

var _impact_tween: Tween
var _impact_token: int = 0
var _impact_active: bool = false
var _recovery_target_scale: float = 1.0


func trigger_elite_kill_impact() -> void:
	var clamped_slow_scale := clampf(elite_kill_slow_scale, 0.05, 1.0)
	var hold_duration := maxf(elite_kill_slow_duration, 0.0)
	var recovery_duration := maxf(elite_kill_recovery_duration, 0.01)

	# Keep the original baseline while an impact is already active so close kills
	# refresh the effect instead of drifting to a lower recovery target.
	if not _impact_active:
		_recovery_target_scale = maxf(Engine.time_scale, 0.05)

	_impact_active = true
	_impact_token += 1
	var token := _impact_token

	_kill_active_tween()
	Engine.time_scale = minf(maxf(Engine.time_scale, 0.05), clamped_slow_scale)

	_impact_tween = create_tween()
	_impact_tween.set_ignore_time_scale(true)
	if hold_duration > 0.0:
		_impact_tween.tween_interval(hold_duration)
	_impact_tween.tween_method(
		Callable(self, "_set_time_scale"),
		Engine.time_scale,
		_recovery_target_scale,
		recovery_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_impact_tween.finished.connect(func() -> void:
		if token != _impact_token:
			return
		_set_time_scale(_recovery_target_scale)
		_impact_active = false
		_impact_tween = null
	)


func _set_time_scale(value: float) -> void:
	var clamped_value := clampf(value, 0.05, 4.0)
	# Do not override a faster external time scale (e.g. another system ending slow-mo).
	Engine.time_scale = maxf(Engine.time_scale, clamped_value)


func _kill_active_tween() -> void:
	if _impact_tween and is_instance_valid(_impact_tween):
		_impact_tween.kill()
	_impact_tween = null


func _exit_tree() -> void:
	_kill_active_tween()
	_impact_active = false
	if reset_to_normal_on_exit:
		# Safety fallback to avoid carrying slowdown across teardown.
		Engine.time_scale = 1.0
