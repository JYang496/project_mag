extends BulletBase


func _physics_process(delta: float) -> void:
	self.position = self.position + base_displacement * delta
	bullet.position = bullet.position + bullet_displacement * delta
