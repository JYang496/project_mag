extends Node2D
class_name SpeedChangeOnHit

@onready var module_parent = self.get_parent() # Bullet root is parent

var on_hit := false
@export var speed_rate = 0.3

func _ready() -> void:
	if not module_parent:
		print("Error: spin module does not have owner")
		return
	module_parent.connect("enemy_hit_signal",Callable(self,"_on_bullet_hit"))


func _on_bullet_hit() -> void:
	if not on_hit:
		on_hit = true
		module_parent.base_displacement *= speed_rate
