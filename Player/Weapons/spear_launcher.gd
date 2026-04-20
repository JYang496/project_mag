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
		"damage": "6",
		"speed": "900",
		"hp": "4",
		"fire_interval_sec": "0.6",
		"ammo": "30",
		"cost": "9",
	},
	"2": {
		"level": "2",
		"damage": "7",
		"speed": "600",
		"hp": "4",
		"fire_interval_sec": "0.55",
		"ammo": "32",
		"cost": "9",
	},
	"3": {
		"level": "3",
		"damage": "9",
		"speed": "600",
		"hp": "6",
		"fire_interval_sec": "0.5",
		"ammo": "34",
		"cost": "9",
	},
	"4": {
		"level": "4",
		"damage": "10",
		"speed": "800",
		"hp": "6",
		"fire_interval_sec": "0.45",
		"ammo": "36",
		"cost": "9",
	},
	"5": {
		"level": "5",
		"damage": "12",
		"speed": "800",
		"hp": "6",
		"fire_interval_sec": "0.4",
		"ammo": "38",
		"cost": "9",
	},
	"6": {
		"level": "6",
		"damage": "14",
		"speed": "800",
		"hp": "6",
		"fire_interval_sec": "0.35",
		"ammo": "40",
		"cost": "9",
	},
	"7": {
		"level": "7",
		"damage": "18",
		"speed": "800",
		"hp": "6",
		"fire_interval_sec": "0.3",
		"ammo": "42",
		"cost": "9",
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])

	base_attack_cooldown = float(weapon_data[lv]["fire_interval_sec"])
	apply_level_ammo(weapon_data[lv])
	sync_stats()


func _on_shoot():
	is_on_cooldown = true
	# 应用分支冷却倍率
	var cooldown := base_attack_cooldown
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= maxf(branch_behavior.get_cooldown_multiplier(), 0.05)
	cooldown_timer.wait_time = maxf(cooldown, 0.05)
	cooldown_timer.start()

	# 获取发射方向（支持分支多发）
	var target_position: Vector2 = get_mouse_target()
	var base_direction: Vector2 = global_position.direction_to(target_position).normalized()
	var shot_directions: Array[Vector2] = [base_direction]
	if branch_behavior and is_instance_valid(branch_behavior):
		shot_directions = branch_behavior.get_shot_directions(base_direction)
		if shot_directions.is_empty():
			shot_directions = [base_direction]

	# 获取伤害倍率
	var damage_multiplier := 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_multiplier = maxf(branch_behavior.get_projectile_damage_multiplier(), 0.05)

	# 对每个方向发射投射物
	for dir in shot_directions:
		var spawn_projectile = spawn_projectile_from_scene(projectile_template)
		if spawn_projectile == null:
			continue
		spawn_projectile.damage = max(1, int(round(float(get_runtime_shot_damage()) * damage_multiplier)))
		spawn_projectile.hp = projectile_hits
		spawn_projectile.size = size
		spawn_projectile.global_position = global_position
		spawn_projectile.projectile_texture = projectile_texture_resource
		projectile_direction = dir  # 设置方向供 apply_base_movement 使用
		apply_return_on_timeout(spawn_projectile)
		apply_effects_on_projectile(spawn_projectile)
		get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_weapon_shot(base_direction)

func apply_return_on_timeout(projectile_node, stop_time : float = 0.5, return_time : float = 1.0) -> void:
	var return_on_timeour_ins = return_on_timeout.instantiate()
	return_on_timeour_ins.return_time = return_time
	return_on_timeour_ins.stop_time = stop_time
	projectile_node.call_deferred("add_child",return_on_timeour_ins)
	projectile_node.module_list.append(return_on_timeour_ins)

func on_hit_target(target: Node) -> void:
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_target_hit(target)

