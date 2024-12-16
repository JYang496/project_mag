extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/bullet.png")
var tornado = preload("res://Player/Weapons/Bullets/tornado.tscn")
var tornado_texture = preload("res://Textures/test/tornado.png")

@onready var sprite = get_node("%GunSprite")
@onready var sniper_attack_timer = $SniperAttackTimer
@onready var sniper_charging_timer = $SniperChargingTimer

# Weapon
var ITEM_NAME = "Cyclone"
var level : int = 1
var damage : int = 1
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}
var knock_back_amount = 30
var spin_rate : float = PI
var spin_speed : float = 600
var speed : int = 300
var hp : int = 1
var reload : float =1


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "5",
		"knock_back_amount": "100",
		"speed": "400",
		"spin_rate": "6",
		"spin_speed": "600",
		"hp": "5",
		"reload": "2",
		"cost": "1",
		"features": ["piercing"],
	},
	"2": {
		"level": "2",
		"damage": "7",
		"knock_back_amount": "100",
		"speed": "400",
		"spin_rate": "6",
		"spin_speed": "600",
		"hp": "7",
		"reload": "2",
		"cost": "1",
		"features": ["piercing"],
	},
	"3": {
		"level": "3",
		"damage": "10",
		"knock_back_amount": "150",
		"speed": "400",
		"spin_rate": "6",
		"spin_speed": "600",
		"hp": "10",
		"reload": "2",
		"cost": "1",
		"features": ["piercing"],
	},
	"4": {
		"level": "4",
		"damage": "15",
		"knock_back_amount": "150",
		"speed": "400",
		"spin_rate": "9",
		"spin_speed": "600",
		"hp": "15",
		"reload": "2",
		"cost": "1",
		"features": ["piercing"],
	},
	"5": {
		"level": "5",
		"damage": "25",
		"knock_back_amount": "200",
		"speed": "400",
		"spin_rate": "12",
		"spin_speed": "600",
		"hp": "25",
		"reload": "1.5",
		"cost": "1",
		"features": ["piercing"],
	}
}


func _ready():
	set_level("1")


func set_level(lv):
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	knock_back_amount = int(weapon_data[lv]["knock_back_amount"])
	speed = int(weapon_data[lv]["speed"])
	spin_rate = float(weapon_data[lv]["spin_rate"])
	spin_speed = float(weapon_data[lv]["spin_speed"])
	hp = int(weapon_data[lv]["hp"])
	reload = float(weapon_data[lv]["reload"])
	sniper_attack_timer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)


func _on_shoot():
	justAttacked = true
	sniper_attack_timer.start()
	var spawn_bullet = bullet.instantiate()
	spawn_bullet.damage = damage
	var direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.knock_back = {"amount": knock_back_amount, "angle": direction}
	spawn_bullet.hp = hp
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	apply_linear(spawn_bullet, direction, speed)
	apply_spiral(spawn_bullet, spin_rate,spin_speed)
	apply_affects(spawn_bullet)
	get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	if self.is_overcharged:
		return
	self.is_overcharged = true
	print(self,"OVER CHARGE")
	var tornado_ins = tornado.instantiate()
	tornado_ins.hitbox_type = "dot"
	tornado_ins.dot_cd = 0.25
	tornado_ins.damage = damage
	tornado_ins.expire_time = 10
	var direction = global_position.direction_to(get_random_target()).normalized()
	tornado_ins.hp = 999
	tornado_ins.blt_texture = tornado_texture
	tornado_ins.global_position = global_position
	apply_linear(tornado_ins, direction, 60)
	get_tree().root.call_deferred("add_child",tornado_ins)
	remove_weapon()

func _on_sniper_attack_timer_timeout():
	justAttacked = false
