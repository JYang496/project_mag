extends Module
class_name Erosion

func _ready() -> void:
	weapon.bullet_effects.set("erosion_effect",{"tick":5,"damage":1})
