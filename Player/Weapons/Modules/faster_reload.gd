extends Accessory

@export var mult_by = 0.7
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if weapon and weapon.has_signal("calculate_cd_timer"):
		weapon.calculate_cd_timer.connect(mult)


func mult(arg):
	weapon.reload = float(arg * mult_by)
