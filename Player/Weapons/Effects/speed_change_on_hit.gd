extends Node2D
class_name SpeedChangeOnHit

@onready var module_parent : BulletBase = self.get_parent() # Bullet root is parent

var on_hit := false
@export var speed_rate = 0.3
var saved_speed_adjustment : Vector2
var parent_overlap : bool = false

func _ready() -> void:
	if not module_parent:
		print("Error: spin module does not have owner")
		return
	module_parent.connect("overlapping_signal",Callable(self,"_on_bullet_overlapping_change"))
	saved_speed_adjustment = module_parent.base_displacement

func _on_bullet_overlapping_change() -> void:
	if module_parent.overlapping:
		parent_overlap = true
		module_parent.base_displacement = saved_speed_adjustment * speed_rate
	if not module_parent.overlapping:
		module_parent.base_displacement = saved_speed_adjustment
		parent_overlap = false
