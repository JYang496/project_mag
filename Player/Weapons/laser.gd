extends Ranger

# Bullet
@onready var beam = preload("res://Player/Weapons/Bullets/beam.tscn")

@onready var cooldown_timer = $LaserCooldownTimer
func _ready():
	pass

func _on_shoot():
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	print(get_global_mouse_position())
	beam_ins.target_position = get_global_mouse_position() - self.global_position
	self.get_tree().root.call_deferred("add_child",beam_ins)
	justAttacked = true
	cooldown_timer.start()

func _on_laser_cooldown_timer_timeout() -> void:
	justAttacked = false
