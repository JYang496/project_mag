extends Effect
class_name SpinEffect


func _physics_process(delta: float) -> void:
	if not bullet:
		print("Error: spin module does not have owner")
		return
	bullet.bullet.rotation += 40 * delta
	if bullet.bullet.rotation > 1000:
		bullet.bullet.rotation -= 1000
