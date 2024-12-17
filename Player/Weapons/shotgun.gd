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
		"speed": "1200",
		"hp": "1",
		"reload": "2",
		"bullet_count": "3",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "15",
		"speed": "1200",
		"hp": "1",
		"reload": "1.8",
		"bullet_count": "5",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "20",
		"speed": "1200",
		"hp": "1",
		"reload": "1.8",
		"bullet_count": "5",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "30",
		"speed": "1200",
		"hp": "1",
		"reload": "1.4",
		"bullet_count": "7",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "40",
		"speed": "1200",
		"hp": "2",
		"reload": "1.4",
		"bullet_count": "9",
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
		spawn_bullet.expire_time = 0.3
		apply_linear(spawn_bullet, bullet_direction, speed)
		apply_affects(spawn_bullet)
		get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	print(self,"OVER CHARGE")
	for n in 10:
		bullet_count += 1
		var main_target = get_random_position_in_circle(100.0)
		var start_angle = position.direction_to(main_target).normalized().angle()
		var angle_step = deg_to_rad(arc) / clampi((bullet_count - 1),1,66)
		var start_offset = -deg_to_rad(arc) / 2
		
		for i in bullet_count:
			var spawn_bullet = bullet.instantiate()
			var current_angle = start_angle + start_offset + (angle_step * i)
			var bullet_direction = Vector2.RIGHT.rotated(current_angle)
			spawn_bullet.damage = damage * 2
			spawn_bullet.global_position = global_position
			spawn_bullet.blt_texture = bul_texture
			spawn_bullet.hp = hp
			spawn_bullet.expire_time = 0.3
			apply_linear(spawn_bullet, bullet_direction, speed)
			apply_affects(spawn_bullet)
			get_tree().root.call_deferred("add_child",spawn_bullet)
		await get_tree().create_timer(0.3).timeout
	remove_weapon()

func get_random_position_in_circle(radius: float = 50.0) -> Vector2:
	var angle = randf_range(0, TAU)  # TAU is 2*PI in Godot
	var x = cos(angle) * radius
	var y = sin(angle) * radius
	return Vector2(x, y)

func _on_shotgun_attack_timer_timeout() -> void:
	justAttacked = false
