extends Ranger

# Bullet
@onready var beam = preload("res://Player/Weapons/Bullets/beam.tscn")

@onready var cooldown_timer = $LaserCooldownTimer

# Weapon
var ITEM_NAME = "Mini Gun"
var level : int
var damage : int
var speed : int
var hp : int
var reload : float


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "1",
		"reload": "2",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "2",
		"reload": "2",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "3",
		"reload": "2",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "4",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "5",
		"reload": "2",
		"cost": "1",
		"features": [],
	}
}
func _ready():
	pass

func _on_shoot():
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	beam_ins.target_position = get_global_mouse_position() - self.global_position
	self.get_tree().root.call_deferred("add_child",beam_ins)
	justAttacked = true
	cooldown_timer.start()

func _on_laser_cooldown_timer_timeout() -> void:
	justAttacked = false
