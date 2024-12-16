extends BulletBase
class_name Tornado

func _physics_process(delta: float) -> void:
	self.position = self.position + base_displacement * delta
	bullet.position = bullet.position + bullet_displacement * delta



func _on_direction_timer_timeout() -> void:
	pass # Replace with function body.
