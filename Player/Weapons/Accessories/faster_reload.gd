extends Node2D

@onready var weapon = self.get_parent()

var mult_by = 0.8
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_cd_timer"):
		weapon.calculate_cd_timer.connect(mult)


func mult(arg):
	print(arg)
