extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/minigun_bullet.png")
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
	base_projectile_hits = int(weapon_data[lv]["hp"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	sync_stats()
	projectile_modifiers.set("explosion_effect",{"damage":damage, "explosion_size": size * 2})

func _on_shoot():
	is_on_cooldown = true
	cooldown_timer.start()
	var spawn_projectile = projectile_template.instantiate()
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	spawn_projectile.damage = damage
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = size
	if projectile_modifiers.has("explosion_effect"):
		projectile_modifiers["explosion_effect"]["damage"] = damage
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _on_over_charge():
	if self.casting_oc_skill:
		return
	self.casting_oc_skill = true
	var n = 0
	var max_n = 20
	var spawn_projectile = null
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
			spawn_projectile = projectile_template.instantiate()
			projectile_direction = null
			spawn_projectile.damage = damage
			spawn_projectile.projectile_texture = projectile_texture_resource
			var fall_ins = fall_effect.instantiate()
			fall_ins.destination = area.global_position
			if projectile_modifiers.has("explosion_effect"):
				projectile_modifiers["explosion_effect"]["damage"] = damage
			apply_effects_on_projectile(spawn_projectile)
			spawn_projectile.call_deferred("add_child",fall_ins)
			get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)
			n += 1
		await get_tree().create_timer(0.2).timeout		
	remove_weapon()
	self.casting_oc_skill = false
