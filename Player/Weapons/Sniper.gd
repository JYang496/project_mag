extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/bullet.tscn")
var bul_texture = preload("res://Textures/test/sniper_bullet.png")
@onready var sprite = get_node("%GunSprite")
@onready var sniper_attack_timer = $SniperAttackTimer
@onready var sniper_charging_timer = $SniperChargingTimer

# Weapon
var ITEM_NAME = "Sniper"
var level : int
var damage : int
var speed : int
var hp : int
var reload : float

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "30",
		"speed": "1200",
		"hp": "2",
		"reload": "2"
	},
	"2": {
		"level": "2",
		"damage": "45",
		"speed": "1200",
		"hp": "2",
		"reload": "2"
	},
	"3": {
		"level": "3",
		"damage": "55",
		"speed": "1200",
		"hp": "3",
		"reload": "2"
	},
	"4": {
		"level": "4",
		"damage": "65",
		"speed": "1200",
		"hp": "4",
		"reload": "2"
	},
	"5": {
		"level": "5",
		"damage": "80",
		"speed": "1200",
		"hp": "5",
		"reload": "1.5"
	}
}


func _ready():
	set_level("1")


func set_level(lv):
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	speed = int(weapon_data[lv]["speed"])
	hp = int(weapon_data[lv]["hp"])
	reload = float(weapon_data[lv]["reload"])
	sniper_attack_timer.wait_time = reload


func _on_shoot():
	justAttacked = true
	sniper_attack_timer.start()
	var spawn_bullet = bullet.instantiate()
	spawn_bullet.damage = damage
	spawn_bullet.speed = speed
	spawn_bullet.target = get_random_target()
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	player.add_sibling(spawn_bullet)


func _on_sniper_attack_timer_timeout():
	justAttacked = false
