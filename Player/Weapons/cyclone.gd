extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/bullet.png")
var tornado = preload("res://Player/Weapons/Projectiles/tornado.tscn")
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
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	knock_back_amount = int(weapon_data[lv]["knock_back_amount"])
	base_speed = int(weapon_data[lv]["speed"])
	spin_rate = float(weapon_data[lv]["spin_rate"])
	spin_speed = float(weapon_data[lv]["spin_speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	sync_stats()
	projectile_modifiers.set("spiral_movement",{"spin_rate":spin_rate, "spin_speed": spin_speed})


func _on_shoot():
	is_on_cooldown = true
	cooldown_timer.start()
	var spawn_projectile = projectile_template.instantiate()
	spawn_projectile.damage = damage
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = size
	projectile_modifiers.set("knock_back_effect",{"amount": knock_back_amount, "angle": projectile_direction})
	apply_effects_on_projectile(spawn_projectile)
	get_tree().root.call_deferred("add_child",spawn_projectile)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	print(self,"OVER CHARGE")
	speed = base_speed / 5
	var tornado_ins = tornado.instantiate()
	tornado_ins.hitbox_type = "dot"
	tornado_ins.dot_cd = 0.25
	tornado_ins.damage = damage
	tornado_ins.expire_time = 10
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	tornado_ins.hp = 999
	tornado_ins.projectile_texture = tornado_texture
	tornado_ins.global_position = global_position
	projectile_modifiers.set("knock_back_effect",{"amount": knock_back_amount, "angle": projectile_direction})
	apply_effects_on_projectile(tornado_ins)
	get_tree().root.call_deferred("add_child",tornado_ins)
	speed = base_speed
	remove_weapon()

func get_sprite():
	return sprite
