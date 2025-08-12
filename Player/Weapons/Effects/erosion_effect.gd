extends Effect
class_name ErosionEffect

@onready var erosion_obj ={"tick":5,"damage":1}

func bullet_effect_ready() -> void:
	await get_tree().physics_frame
	bullet.hitbox_ins.status_on_hit.set("erosion",erosion_obj)
