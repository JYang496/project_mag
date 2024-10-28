extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/bullet.png")
var linear_movement = preload("res://Player/Weapons/Bullets/linear_movement.tscn")
@onready var sprite = get_node("%GunSprite")
@onready var sniper_attack_timer = $SniperAttackTimer
@onready var sniper_charging_timer = $SniperChargingTimer

# Weapon
var ITEM_NAME = "Cyclone"
var level : int
var damage : int
var speed : int
var hp : int
var reload : float

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "5",
		"speed": "400",
		"hp": "5",
		"reload": "2",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "7",
		"speed": "400",
		"hp": "7",
		"reload": "2",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "10",
		"speed": "400",
		"hp": "10",
		"reload": "2",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "15",
		"speed": "400",
		"hp": "15",
		"reload": "2",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "25",
		"speed": "400",
		"hp": "25",
		"reload": "1.5",
		"cost": "1",
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
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	enable_linear(spawn_bullet, global_position.direction_to(get_random_target()).normalized(), speed)
	get_tree().root.call_deferred("add_child",spawn_bullet)

func enable_linear(bullet : Node2D, direction : Vector2 = Vector2.UP, speed : float = 400.0) -> void:
	var linear_movement_ins = linear_movement.instantiate()
	linear_movement_ins.direction = direction
	bullet.call_deferred("add_child",linear_movement_ins)

func _on_sniper_attack_timer_timeout():
	justAttacked = false
