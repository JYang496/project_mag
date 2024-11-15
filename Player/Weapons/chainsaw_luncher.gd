extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/minigun_bullet.png")
@onready var sprite = get_node("%GunSprite")
@onready var gun_cooldownTimer = $ChainsawLuncherTimer

# Weapon
var ITEM_NAME = "Chainsaw Luncher"
var level : int
var damage : int
var speed : int
var hp : int
var reload : float

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "1",
		"speed": "600",
		"hp": "11",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "1",
		"speed": "600",
		"hp": "22",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "1",
		"speed": "600",
		"hp": "33",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "2",
		"speed": "800",
		"hp": "44",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "2",
		"speed": "800",
		"hp": "55",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	}
}
