extends Effect
class_name ErosionEffect

func bullet_effect_ready() -> void:
	await get_tree().physics_frame
	prints(bullet.hitbox_ins)
