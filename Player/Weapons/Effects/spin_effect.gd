extends Effect
class_name SpinEffect


func _physics_process(delta: float) -> void:
	if not projectile:
		print("Error: spin module does not have owner")
		return
	projectile.projectile_root.rotation += 40 * delta
	if projectile.projectile_root.rotation > 1000:
		projectile.projectile_root.rotation -= 1000
