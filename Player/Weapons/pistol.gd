extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/minigun_bullet.png")
var hexagon_attack_effect = preload("res://Player/Weapons/Effects/hexagon_attack.tscn")

# Weapon
var ITEM_NAME = "Pistol"


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "20",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "30",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "40",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "50",
		"speed": "800",
		"hp": "1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "60",
		"speed": "800",
		"hp": "2",
		"reload": "0.5",
		"cost": "1",
		"features": [],
	},
	"6": {
		"level": "6",
		"damage": "70",
		"speed": "800",
		"hp": "2",
		"reload": "0.5",
		"cost": "1",
		"features": [],
	},
	"7": {
		"level": "7",
		"damage": "80",
		"speed": "800",
		"hp": "2",
		"reload": "0.5",
		"cost": "1",
		"features": [],
	}
}

var weapon_file
var minigun_data = JSON.new()

func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_hp = int(weapon_data[lv]["hp"])
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
	spawn_bullet.size = size
	spawn_bullet.blt_texture = bul_texture
	apply_effects_on_bullet(spawn_bullet)
	get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	print(self,"OVER CHARGE")
	Engine.time_scale = 0.1
	PlayerData.player_bonus_speed += PlayerData.player_speed * 2
	justAttacked = true
	speed = 2000
	var unit_of_time = (get_random_target() - self.global_position).length() / speed
	var wait_time = 0.05
	for i in range(6):
		var spawn_bullet = bullet.instantiate()
		bullet_direction = global_position.direction_to(get_random_target()).normalized()
		spawn_bullet.damage = damage
		spawn_bullet.expire_time = 6.6
		spawn_bullet.hp = 66
		spawn_bullet.global_position = global_position
		spawn_bullet.blt_texture = bul_texture
		apply_effects_on_bullet(spawn_bullet)
		apply_hexagon_attack(spawn_bullet,i,unit_of_time)
		get_tree().root.call_deferred("add_child",spawn_bullet)
		await get_tree().create_timer(wait_time).timeout
	PlayerData.player_bonus_speed -= PlayerData.player_speed * 2
	Engine.time_scale = 1
	remove_weapon()
		
func apply_hexagon_attack(blt_node : Node2D, id : int, unit_of_time : float) -> void:
	var hexagon_attack_ins = hexagon_attack_effect.instantiate()
	hexagon_attack_ins.id = id
	hexagon_attack_ins.wait_time = unit_of_time
	blt_node.call_deferred("add_child",hexagon_attack_ins)
	blt_node.effect_list.append(hexagon_attack_ins)
	module_list.append(hexagon_attack_ins)
