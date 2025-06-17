extends Ranger

var spin_effect = preload("res://Player/Weapons/Effects/spin_effect.tscn")
var scale_up_by_time_effect = preload("res://Player/Weapons/Effects/scale_up_by_time.tscn")
var chase_closest_enemy_effect = preload("res://Player/Weapons/Effects/chase_closest_enemy.tscn")

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/chainsaw_spin.png")
#@onready var sprite = get_node("%Sprite")

# Weapon
var ITEM_NAME = "Chainsaw Luncher"

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "2",
		"speed": "200",
		"hp": "10",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "4",
		"speed": "200",
		"hp": "15",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "7",
		"speed": "200",
		"hp": "20",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "10",
		"speed": "200",
		"hp": "25",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "15",
		"speed": "200",
		"hp": "25",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	},
	"6": {
		"level": "6",
		"damage": "20",
		"speed": "200",
		"hp": "30",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	},
	"7": {
		"level": "25",
		"damage": "15",
		"speed": "200",
		"hp": "30",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_hp = int(weapon_data[lv]["hp"])
	dot_cd = float(weapon_data[lv]["dot_cd"])
	base_reload = float(weapon_data[lv]["reload"])
	calculate_status()
	for feature in weapon_data[lv]["features"]:
		if not features.has(feature):
			features.append(feature)

	
func _on_shoot():
	justAttacked = true
	cooldown_timer.start()
	var spawn_bullet = bullet.instantiate()
	bullet_direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.damage = damage
	spawn_bullet.hp = hp
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	spawn_bullet.size = size
	spawn_bullet.hitbox_type = "dot"
	spawn_bullet.dot_cd = dot_cd
	apply_effects_on_bullet(spawn_bullet)
	apply_spin(spawn_bullet)
	apply_speed_change_on_hit(spawn_bullet, 0.3)
	get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	print(self,"OVER CHARGE")
	justAttacked = true
	var spawn_bullet = bullet.instantiate()
	bullet_direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.damage = damage
	spawn_bullet.hp = 7777
	spawn_bullet.expire_time = 17
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	spawn_bullet.hitbox_type = "dot"
	spawn_bullet.dot_cd = dot_cd
	apply_effects_on_bullet(spawn_bullet)
	apply_spin(spawn_bullet)
	apply_speed_change_on_hit(spawn_bullet, 0.3)
	get_tree().root.call_deferred("add_child",spawn_bullet)
	apply_dmg_up_on_enemy_death(spawn_bullet)
	apply_scale_up_by_time(spawn_bullet)
	apply_chase_closest_enemy(spawn_bullet)
	remove_weapon()

func apply_spin(blt_node) -> void:
	var spin_movement_ins = spin_effect.instantiate()
	blt_node.call_deferred("add_child",spin_movement_ins)
	blt_node.module_list.append(spin_movement_ins)
	module_list.append(spin_movement_ins)

func apply_scale_up_by_time(blt_node) -> void:
	var scale_up_by_time = scale_up_by_time_effect.instantiate()
	blt_node.call_deferred("add_child",scale_up_by_time)
	blt_node.module_list.append(scale_up_by_time)
	module_list.append(scale_up_by_time)

func apply_chase_closest_enemy(blt_node) -> void:
	var chase_ins = chase_closest_enemy_effect.instantiate()
	blt_node.call_deferred("add_child",chase_ins)
	blt_node.module_list.append(chase_ins)
	module_list.append(chase_ins)

func _on_chainsaw_luncher_timer_timeout() -> void:
	justAttacked = false
