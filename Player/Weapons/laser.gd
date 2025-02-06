extends Ranger

# Bullet
@onready var beam = preload("res://Player/Weapons/Bullets/beam.tscn")

@onready var detect_area: Area2D = $DetectArea
@onready var oc_timer: Timer = $OCTimer

@onready var cooldown_timer = $LaserCooldownTimer
@onready var sprite = get_node("%Sprite")

# Weapon
var ITEM_NAME = "Laser"

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



func set_level(lv):
	lv = str(lv)
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
	if self.casting_oc_skill or PlayerData.cloestest_enemy == null:
		return
	self.casting_oc_skill = true
	print(self,"OVER CHARGE")
	justAttacked = true
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	beam_ins.target_position = to_local(PlayerData.cloestest_enemy.global_position)
	beam_ins.damage = damage
	beam_ins.oc_mode = true
	beam_ins.beam_owner = self
	self.get_tree().root.call_deferred("add_child",beam_ins)
	oc_timer.start()

func _on_laser_cooldown_timer_timeout() -> void:
	justAttacked = false


func _on_oc_timer_timeout() -> void:
	remove_weapon()
