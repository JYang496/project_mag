extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/bullet.png")
var tornado = preload("res://Player/Weapons/Bullets/tornado.tscn")
var tornado_texture = preload("res://Textures/test/tornado.png")


# Weapon
var ITEM_NAME = "Cyclone"
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}
var knock_back_amount = 30
var spin_rate : float = PI
var spin_speed : float = 600


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "24",
		"knock_back_amount": "100",
		"speed": "400",
		"spin_rate": "6",
		"spin_speed": "600",
		"hp": "8",
		"reload": "2",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "27",
		"knock_back_amount": "100",
		"speed": "400",
		"spin_rate": "6",
		"spin_speed": "600",
		"hp": "10",
		"reload": "2",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "30",
		"knock_back_amount": "150",
		"speed": "400",
		"spin_rate": "6",
		"spin_speed": "600",
		"hp": "12",
		"reload": "1.8",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "40",
		"knock_back_amount": "150",
		"speed": "400",
		"spin_rate": "9",
		"spin_speed": "600",
		"hp": "15",
		"reload": "1.8",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "50",
		"knock_back_amount": "200",
		"speed": "400",
		"spin_rate": "12",
		"spin_speed": "600",
		"hp": "20",
		"reload": "1.5",
		"cost": "1",
		"features": [],
	},
	"6": {
		"level": "6",
		"damage": "65",
		"knock_back_amount": "200",
		"speed": "400",
		"spin_rate": "12",
		"spin_speed": "600",
		"hp": "20",
		"reload": "1.5",
		"cost": "1",
		"features": [],
	},
	"7": {
		"level": "7",
		"damage": "80",
		"knock_back_amount": "200",
		"speed": "400",
		"spin_rate": "12",
		"spin_speed": "600",
		"hp": "20",
		"reload": "1.5",
		"cost": "1",
		"features": [],
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	knock_back_amount = int(weapon_data[lv]["knock_back_amount"])
	speed = int(weapon_data[lv]["speed"])
	spin_rate = float(weapon_data[lv]["spin_rate"])
	spin_speed = float(weapon_data[lv]["spin_speed"])
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
	spawn_bullet.damage = damage
	var direction = global_position.direction_to(get_random_target()).normalized()
	spawn_bullet.knock_back = {"amount": knock_back_amount, "angle": direction}
	spawn_bullet.hp = hp
	spawn_bullet.global_position = global_position
	spawn_bullet.blt_texture = bul_texture
	apply_linear(spawn_bullet, direction, speed)
	apply_spiral(spawn_bullet, spin_rate,spin_speed)
	apply_affects(spawn_bullet)
	get_tree().root.call_deferred("add_child",spawn_bullet)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	print(self,"OVER CHARGE")
	var tornado_ins = tornado.instantiate()
	tornado_ins.hitbox_type = "dot"
	tornado_ins.dot_cd = 0.25
	tornado_ins.damage = damage
	tornado_ins.expire_time = 10
	var direction = global_position.direction_to(get_random_target()).normalized()
	tornado_ins.hp = 999
	tornado_ins.blt_texture = tornado_texture
	tornado_ins.global_position = global_position
	apply_linear(tornado_ins, direction, 60)
	get_tree().root.call_deferred("add_child",tornado_ins)
	remove_weapon()

func get_sprite():
	return sprite
