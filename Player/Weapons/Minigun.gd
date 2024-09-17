extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/bullet.tscn")
var bul_texture = preload("res://Textures/test/minigun_bullet.png")
@onready var sprite = get_node("%GunSprite")
@onready var gun_cooldownTimer = $GunCooldownTimer

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
		"damage": "10",
		"speed": "600",
		"hp": "1",
		"reload": "0.7"
	},
	"2": {
		"level": "2",
		"damage": "15",
		"speed": "600",
		"hp": "1",
		"reload": "0.5"
	},
	"3": {
		"level": "3",
		"damage": "20",
		"speed": "600",
		"hp": "1",
		"reload": "0.4"
	},
	"4": {
		"level": "4",
		"damage": "30",
		"speed": "800",
		"hp": "1",
		"reload": "0.4"
	},
	"5": {
		"level": "5",
		"damage": "40",
		"speed": "800",
		"hp": "2",
		"reload": "0.4"
	}
}

var weapon_file
var minigun_data = JSON.new()

func _ready():
	set_level("1")


func set_level(lv):
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	speed = int(weapon_data[lv]["speed"])
	hp = int(weapon_data[lv]["hp"])
	reload = float(weapon_data[lv]["reload"])
	gun_cooldownTimer.wait_time = reload
	
func _on_shoot():
	justAttacked = true
	gun_cooldownTimer.start()
	var spawn_bullet = bullet.instantiate()
	spawn_bullet.damage = damage
	spawn_bullet.speed = speed
	spawn_bullet.hp = hp
	spawn_bullet.target = get_random_target()
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	player.add_sibling(spawn_bullet)

func _on_gun_cooldown_timer_timeout():
	justAttacked = false
