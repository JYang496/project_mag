extends Ranger

var spin_module = preload("res://Player/Weapons/Bullets/spin_module.tscn")
var speed_change_on_hit_module = preload("res://Player/Weapons/Bullets/speed_change_on_hit.tscn")
var scale_up_by_time_module = preload("res://Player/Weapons/Bullets/scale_up_by_time.tscn")
var chase_closest_enemy_module = preload("res://Player/Weapons/Bullets/chase_closest_enemy.tscn")

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/chainsaw_spin.png")
@onready var sprite = get_node("%GunSprite")
@onready var gun_cooldownTimer = $ChainsawLuncherTimer

# Weapon
var ITEM_NAME = "Chainsaw Luncher"
var level : int
var damage : int
var speed : int
var hp : int
var dot_cd : float
var reload : float

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "1",
		"speed": "200",
		"hp": "11",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "1",
		"speed": "200",
		"hp": "22",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "1",
		"speed": "200",
		"hp": "33",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "2",
		"speed": "200",
		"hp": "44",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "2",
		"speed": "200",
		"hp": "55",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	}
}


func _ready():
	set_level("1")


func set_level(lv):
	level = int(weapon_data[lv]["level"])
	damage = int(weapon_data[lv]["damage"])
	speed = int(weapon_data[lv]["speed"])
	hp = int(weapon_data[lv]["hp"])
	dot_cd = float(weapon_data[lv]["dot_cd"])
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
	spawn_bullet.hitbox_type = "dot"
	spawn_bullet.dot_cd = dot_cd
	apply_linear(spawn_bullet, bullet_direction, speed)
	apply_affects(spawn_bullet)
	apply_spin(spawn_bullet)
	apply_speed_change_on_hit(spawn_bullet, 0.3)
	get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	print(self,"OVER CHARGE")
	justAttacked = true
	var spawn_bullet = bullet.instantiate()
	var bullet_direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.damage = damage
	spawn_bullet.hp = 7777
	spawn_bullet.expire_time = 17
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	spawn_bullet.hitbox_type = "dot"
	spawn_bullet.dot_cd = dot_cd
	apply_linear(spawn_bullet, bullet_direction, speed)
	apply_affects(spawn_bullet)
	apply_spin(spawn_bullet)
	apply_speed_change_on_hit(spawn_bullet, 0.3)
	get_tree().root.call_deferred("add_child",spawn_bullet)
	apply_dmg_up_on_enemy_death(spawn_bullet)
	apply_scale_up_by_time(spawn_bullet)
	apply_chase_closest_enemy(spawn_bullet)
	remove_weapon()

func apply_spin(blt_node) -> void:
	var spin_movement_ins = spin_module.instantiate()
	blt_node.call_deferred("add_child",spin_movement_ins)
	blt_node.module_list.append(spin_movement_ins)
	module_list.append(spin_movement_ins)

func apply_scale_up_by_time(blt_node) -> void:
	var scale_up_by_time = scale_up_by_time_module.instantiate()
	blt_node.call_deferred("add_child",scale_up_by_time)
	blt_node.module_list.append(scale_up_by_time)
	module_list.append(scale_up_by_time)

func apply_chase_closest_enemy(blt_node) -> void:
	var chase_ins = chase_closest_enemy_module.instantiate()
	blt_node.call_deferred("add_child",chase_ins)
	blt_node.module_list.append(chase_ins)
	module_list.append(chase_ins)

func _on_chainsaw_luncher_timer_timeout() -> void:
	justAttacked = false
