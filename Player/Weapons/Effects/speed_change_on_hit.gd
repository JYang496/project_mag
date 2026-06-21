extends Effect
class_name SpeedChangeOnHit

var on_hit := false
@export var speed_rate = 0.3
@export var saved_speed_adjustment : Vector2 = Vector2.ZERO
var parent_overlap : bool = false


func projectile_effect_ready() -> void:
	var overlap_callback := Callable(self, "_on_projectile_overlapping_change")
	if not projectile.overlapping_signal.is_connected(overlap_callback):
		projectile.overlapping_signal.connect(overlap_callback)
	saved_speed_adjustment = projectile.base_displacement

func _on_projectile_overlapping_change() -> void:
	if projectile.overlapping:
		parent_overlap = true
		projectile.base_displacement = saved_speed_adjustment * speed_rate
	if not projectile.overlapping:
		parent_overlap = false
