extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/minigun_bullet.png")
var hexagon_attack = preload("res://Player/Weapons/Bullets/hexagon_attack.tscn")
@onready var sprite = get_node("%GunSprite")
@onready var gun_cooldownTimer = $GunCooldownTimer

# Weapon
var ITEM_NAME = "Pistol"
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
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "15",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "20",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "20",
		"speed": "800",
		"hp": "1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "25",
		"speed": "800",
		"hp": "2",
		"reload": "0.75",
		"cost": "1",
		"features": ["piercing"],
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
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)
	
func _on_shoot():
	justAttacked = true
	gun_cooldownTimer.start()
	var spawn_bullet = bullet.instantiate()
	var bullet_direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.damage = damage
	spawn_bullet.hp = hp
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	apply_linear(spawn_bullet, bullet_direction, speed)
	apply_affects(spawn_bullet)
	#get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	print(self,"OVER CHARGE")
	Engine.time_scale = 0.333
	PlayerData.player_bonus_speed += PlayerData.player_speed * 2
	justAttacked = true
	speed = 800
	var wait_time = (get_random_target() - self.global_position).length() / speed
	var wait_unit_list = [3, 2, 1, 2, 3, 0]
	for i in range(6):
		var spawn_bullet = bullet.instantiate()
		var bullet_direction = global_position.direction_to(get_random_target()).normalized()
		spawn_bullet.damage = damage
		spawn_bullet.expire_time = 6.6
		spawn_bullet.hp = 66
		spawn_bullet.global_position = global_position
		spawn_bullet.blt_texture = bul_texture
		apply_linear(spawn_bullet, bullet_direction, speed)
		apply_hexagon_attack(spawn_bullet, i, wait_time)
		get_tree().root.call_deferred("add_child",spawn_bullet)
		await get_tree().create_timer(wait_time *  wait_unit_list[i]).timeout
	PlayerData.player_bonus_speed -= PlayerData.player_speed * 2
	Engine.time_scale = 1
		
func apply_hexagon_attack(blt_node : Node2D, id : int, wait_time : float) -> void:
	var hexagon_attack_ins = hexagon_attack.instantiate()
	hexagon_attack_ins.id = id
	hexagon_attack_ins.wait_time = wait_time
	blt_node.call_deferred("add_child",hexagon_attack_ins)
	blt_node.module_list.append(hexagon_attack_ins)
	module_list.append(hexagon_attack_ins)

func _on_gun_cooldown_timer_timeout():
	justAttacked = false
