extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/beam.tscn")
@onready var beam_cooldownTimer = $BeamCooldownTimer
@onready var beam = %Beam

func _ready():
	beam.hide()
	beam.set_process(false)

func _on_shoot():
	justAttacked = true
	beam.target = get_random_target()
	beam.show()
	beam.set_process(true)
	beam_cooldownTimer.start()

func _on_beam_cooldown_timer_timeout():
	beam.hide()
	beam.set_process(false)
	justAttacked = false
