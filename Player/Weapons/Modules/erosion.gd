extends Module
class_name Erosion

var EFFECT_KEY = "erosion_effect"
var erosion_object = {"tick":5,"damage":1}

func _ready() -> void:
	weapon.bullet_effects.set(EFFECT_KEY,erosion_object)
