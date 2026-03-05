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
var explosion_scale : float = 2.0


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "10",
		"speed": "500",
		"hp": "1",
		"reload": "2.4",
		"explosion_scale": "2.0",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "13",
		"speed": "560",
		"hp": "1",
		"reload": "2.2",
		"explosion_scale": "2.1",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "16",
		"speed": "600",
		"hp": "1",
		"reload": "2.0",
		"explosion_scale": "2.2",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "20",
		"speed": "650",
		"hp": "1",
		"reload": "1.8",
		"explosion_scale": "2.35",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "25",
		"speed": "700",
		"hp": "2",
		"reload": "1.6",
		"explosion_scale": "2.5",
		"cost": "1",
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	explosion_scale = float(weapon_data[lv]["explosion_scale"])
	sync_stats()
	projectile_modifiers.set("explosion_effect",{"damage":damage, "explosion_size": size * explosion_scale})

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
		projectile_modifiers["explosion_effect"]["explosion_size"] = size * explosion_scale
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)
