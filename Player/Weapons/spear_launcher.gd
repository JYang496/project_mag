extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/spear.tscn")
var bul_texture = preload("res://Textures/test/spear.png")
@onready var sprite = get_node("%SpearSprite")
@onready var spear_cooldownTimer = $SpearCooldownTimer

# Weapon
var ITEM_NAME = "Spear Launcher"
var level : int
var damage : int
var speed : int
var hp : int
var reload : float

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "10",
		"speed": "900",
		"hp": "10",
		"reload": "0.7",
		"cost": "1",
		"features": ["piercing"],
	},
	"2": {
		"level": "2",
		"damage": "15",
		"speed": "600",
		"hp": "10",
		"reload": "0.5",
		"cost": "1",
		"features": ["piercing"],
	},
	"3": {
		"level": "3",
		"damage": "20",
		"speed": "600",
		"hp": "10",
		"reload": "0.4",
		"cost": "1",
		"features": ["piercing"],
	},
	"4": {
		"level": "4",
		"damage": "30",
		"speed": "800",
		"hp": "10",
		"reload": "0.4",
		"cost": "1",
		"features": ["piercing"],
	},
	"5": {
		"level": "5",
		"damage": "40",
		"speed": "800",
		"hp": "20",
		"reload": "0.4",
		"cost": "1",
		"features": ["piercing"],
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
	spear_cooldownTimer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)
	
func _process(_delta):
	pass

func _on_shoot():
	justAttacked = true
	spear_cooldownTimer.start()
	var spawn_bullet = bullet.instantiate()
	spawn_bullet.damage = damage
	spawn_bullet.speed = speed
	spawn_bullet.hp = hp
	spawn_bullet.direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	get_tree().root.call_deferred("add_child",spawn_bullet)


func _on_spear_cooldown_timer_timeout():
	justAttacked = false
