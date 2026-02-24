extends Projectile
class_name Tornado

func _physics_process(delta: float) -> void:
	self.position = self.position + base_displacement * delta
	projectile_root.position = projectile_root.position + projectile_displacement * delta


func _on_direction_timer_timeout() -> void:
	pass # Replace with function body.
