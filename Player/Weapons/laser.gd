extends Ranger

# Bullet
@onready var beam = preload("res://Player/Weapons/Bullets/beam.tscn")

@onready var cooldown_timer = $LaserCooldownTimer
@onready var sprite = get_node("%GunSprite")

# Weapon
var ITEM_NAME = "Laser"
var level : int
var damage : int
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
	set_level("1")


func set_level(lv):
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	reload = float(weapon_data[lv]["reload"])
	cooldown_timer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)

func _on_shoot():
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	beam_ins.target_position = get_global_mouse_position() - self.global_position
	beam_ins.damage = damage
	self.get_tree().root.call_deferred("add_child",beam_ins)
	justAttacked = true
	cooldown_timer.start()

func _on_over_charge():
	print(self,"OVER CHARGE")
	remove_weapon()

func _on_laser_cooldown_timer_timeout() -> void:
	justAttacked = false
