extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/minigun_bullet.png")
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
	},
	"2": {
		"level": "2",
		"damage": "30",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "40",
		"speed": "600",
		"hp": "1",
		"reload": "1",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "50",
		"speed": "800",
		"hp": "1",
		"reload": "0.75",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "60",
		"speed": "800",
		"hp": "2",
		"reload": "0.5",
		"cost": "1",
	},
	"6": {
		"level": "6",
		"damage": "70",
		"speed": "800",
		"hp": "2",
		"reload": "0.5",
		"cost": "1",
	},
	"7": {
		"level": "7",
		"damage": "80",
		"speed": "800",
		"hp": "2",
		"reload": "0.5",
		"cost": "1",
	}
}

var weapon_file
var minigun_data = JSON.new()

func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	sync_stats()
	
func _on_shoot():
	is_on_cooldown = true
	cooldown_timer.start()
	var spawn_projectile = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	spawn_projectile.damage = damage
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.size = size
	spawn_projectile.projectile_texture = projectile_texture_resource
	apply_effects_on_projectile(spawn_projectile)
	get_tree().root.call_deferred("add_child",spawn_projectile)
		
func apply_hexagon_attack(projectile_node : Node2D, id : int, unit_of_time : float) -> void:
	var hexagon_attack_ins = hexagon_attack_effect.instantiate()
	hexagon_attack_ins.id = id
	hexagon_attack_ins.wait_time = unit_of_time
	projectile_node.call_deferred("add_child",hexagon_attack_ins)
	projectile_node.effect_list.append(hexagon_attack_ins)
	module_list.append(hexagon_attack_ins)
