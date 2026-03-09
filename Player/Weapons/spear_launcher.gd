extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/spear.png")
var return_on_timeout = preload("res://Player/Weapons/Effects/return_on_timeout.tscn")

# Weapon
var ITEM_NAME = "Spear Launcher"

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "7",
		"speed": "900",
		"hp": "4",
		"reload": "0.6",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "9",
		"speed": "600",
		"hp": "4",
		"reload": "0.55",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "11",
		"speed": "600",
		"hp": "6",
		"reload": "0.5",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "13",
		"speed": "800",
		"hp": "6",
		"reload": "0.45",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "15",
		"speed": "800",
		"hp": "6",
		"reload": "0.4",
		"cost": "1",
	},
	"6": {
		"level": "6",
		"damage": "18",
		"speed": "800",
		"hp": "6",
		"reload": "0.35",
		"cost": "1",
	},
	"7": {
		"level": "7",
		"damage": "22",
		"speed": "800",
		"hp": "6",
		"reload": "0.3",
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
	spawn_projectile.size = size
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	apply_return_on_timeout(spawn_projectile)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func apply_return_on_timeout(projectile_node, stop_time : float = 0.5, return_time : float = 1.0) -> void:
	var return_on_timeour_ins = return_on_timeout.instantiate()
	return_on_timeour_ins.return_time = return_time
	return_on_timeour_ins.stop_time = stop_time
	projectile_node.call_deferred("add_child",return_on_timeour_ins)
	projectile_node.module_list.append(return_on_timeour_ins)
