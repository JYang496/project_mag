extends Ranger

# Bullet
var bullet = preload("res://Player/Weapons/Bullets/bullet.tscn")
var bul_texture = preload("res://Textures/test/minigun_bullet.png")
#@onready var sprite = get_node("%Sprite")

#OC
@onready var fall_effect = preload("res://Player/Weapons/Effects/fall.tscn")
@onready var oc_booming_area: Area2D = $OCBoomingArea

# Weapon
var ITEM_NAME = "Rocket Luncher"


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "1",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"2": {
		"level": "2",
		"damage": "1",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"3": {
		"level": "3",
		"damage": "1",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
		"features": [],
	},
	"4": {
		"level": "4",
		"damage": "2",
		"speed": "800",
		"hp": "1",
		"reload": "0.75",
		"cost": "1",
		"features": [],
	},
	"5": {
		"level": "5",
		"damage": "2",
		"speed": "800",
		"hp": "1",
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
	base_reload = float(weapon_data[lv]["reload"])
	calculate_status()
	bullet_effects.set("explosion_effect",{"damage":damage, "explosion_size": size * 2})
	
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
	if bullet_effects.has("explosion_effect"):
		bullet_effects["explosion_effect"]["damage"] = damage
	apply_effects_on_bullet(spawn_bullet)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_bullet)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	var n = 0
	var max_n = 20
	var spawn_bullet = null
	while n < max_n:
		var overlap_areas = oc_booming_area.get_overlapping_areas()
		if overlap_areas.is_empty():
			n += 1
			break
		var valid_targets: Array[Area2D] = []
		for area in overlap_areas:
			if area is HurtBox:
				valid_targets.append(area)
		if valid_targets.is_empty():
			n += 1
			break
		for area in valid_targets:
			if n >= max_n:
				break
			spawn_bullet = bullet.instantiate()
			bullet_direction = null
			spawn_bullet.damage = damage
			spawn_bullet.blt_texture = bul_texture
			var fall_ins = fall_effect.instantiate()
			fall_ins.destination = area.global_position
			if bullet_effects.has("explosion_effect"):
				bullet_effects["explosion_effect"]["damage"] = damage
			apply_effects_on_bullet(spawn_bullet)
			spawn_bullet.call_deferred("add_child",fall_ins)
			get_projectile_spawn_parent().call_deferred("add_child", spawn_bullet)
			n += 1
		await get_tree().create_timer(0.2).timeout		
	remove_weapon()
	self.casting_oc_skill = false
