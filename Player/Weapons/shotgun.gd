extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/sniper_bullet.png")
@onready var sprite = get_node("%GunSprite")
@onready var shotgun_attack_timer = $ShotgunAttackTimer

# Weapon
var ITEM_NAME = "Shotgun"
var level : int
var damage : int
var speed : int
var hp : int
var reload : float
@export_range(0, 180) var arc : float = 0
var bullet_count : int

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "10",
		"speed": "900",
		"hp": "1",
		"reload": "2",
		"bullet_count": "3",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "15",
		"speed": "600",
		"hp": "1",
		"reload": "1.8",
		"bullet_count": "3",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "20",
		"speed": "600",
		"hp": "1",
		"reload": "1.8",
		"bullet_count": "5",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "30",
		"speed": "800",
		"hp": "1",
		"reload": "1.4",
		"bullet_count": "5",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "40",
		"speed": "800",
		"hp": "2",
		"reload": "1.4",
		"bullet_count": "7",
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
	bullet_count = int(weapon_data[lv]["bullet_count"])
	shotgun_attack_timer.wait_time = reload
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)

func _on_shoot():
	justAttacked = true
	shotgun_attack_timer.start()
	var main_target = get_random_target()
	var start_angle = global_position.direction_to(main_target).normalized().angle()
	var angle_step = deg_to_rad(arc) / clampi((bullet_count - 1),1,9)
	var start_offset = -deg_to_rad(arc) / 2
	
	for i in bullet_count:
		var spawn_bullet = bullet.instantiate()
		var current_angle = start_angle + start_offset + (angle_step * i)
		var bullet_direction = Vector2.RIGHT.rotated(current_angle)
		spawn_bullet.damage = damage
		spawn_bullet.global_position = global_position
		spawn_bullet.blt_texture = bul_texture
		spawn_bullet.hp = hp
		apply_linear(spawn_bullet, bullet_direction, speed)
		apply_affects(spawn_bullet)
		get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	print(self,"OVER CHARGE")
	PlayerData.player_weapon_list.pop_at(PlayerData.on_select_weapon)
	queue_free()

func _on_shotgun_attack_timer_timeout() -> void:
	justAttacked = false
