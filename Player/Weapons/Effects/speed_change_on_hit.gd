extends Effect
class_name SpeedChangeOnHit

var on_hit := false
@export var speed_rate = 0.3
var saved_speed_adjustment : Vector2
var parent_overlap : bool = false


func bullet_effect_ready() -> void:
	bullet.connect("overlapping_signal",Callable(self,"_on_bullet_overlapping_change"))
	saved_speed_adjustment = bullet.base_displacement

func _on_bullet_overlapping_change() -> void:
	if bullet.overlapping:
		parent_overlap = true
		bullet.base_displacement = saved_speed_adjustment * speed_rate
	if not bullet.overlapping:
		bullet.base_displacement = saved_speed_adjustment
		parent_overlap = false
