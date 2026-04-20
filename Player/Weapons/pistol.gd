extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/minigun_bullet.png")
@export var auto_fire_range: float = 900.0

# Weapon
var ITEM_NAME = "Pistol"


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "4",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "45",
		"cost": "17",
	},
	"2": {
		"level": "2",
		"damage": "6",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "50",
		"cost": "17",
	},
	"3": {
		"level": "3",
		"damage": "8",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "55",
		"cost": "17",
	},
	"4": {
		"level": "4",
		"damage": "10",
		"speed": "800",
		"hp": "1",
		"fire_interval_sec": "0.75",
		"ammo": "60",
		"cost": "17",
	},
	"5": {
		"level": "5",
		"damage": "12",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "0.5",
		"ammo": "65",
		"cost": "17",
	},
	"6": {
		"level": "6",
		"damage": "14",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "0.5",
		"ammo": "70",
		"cost": "17",
	},
	"7": {
		"level": "7",
		"damage": "16",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "0.5",
		"ammo": "75",
		"cost": "17",
	}
}

var weapon_file
var minigun_data = JSON.new()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = _get_level_data(lv)
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["hp"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_process_auto_fire()

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	if not can_run_active_behavior():
		return
	if not pressed:
		return
	request_primary_fire()

func _process_auto_fire() -> void:
	if is_on_cooldown:
		return
	if not can_fire_with_heat():
		return
	if _find_closest_enemy() == null:
		return
	request_primary_fire()

func _on_shoot() -> void:
	var target_pos: Vector2 = get_mouse_target()
	var target := _find_closest_enemy()
	if target != null:
		target_pos = target.global_position

	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= maxf(branch_behavior.get_cooldown_multiplier(), 0.05)
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return

	projectile_direction = global_position.direction_to(target_pos).normalized()
	if projectile_direction == Vector2.ZERO:
		return
	spawn_projectile.damage = get_runtime_shot_damage()
	if branch_behavior and is_instance_valid(branch_behavior):
		spawn_projectile.damage = max(
			1,
			int(round(float(spawn_projectile.damage) * maxf(branch_behavior.get_projectile_damage_multiplier(), 0.05)))
		)
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if branch_behavior and is_instance_valid(branch_behavior) and branch_behavior.has_method("get_damage_type_override"):
		damage_type = Attack.normalize_damage_type(branch_behavior.call("get_damage_type_override"))
	spawn_projectile.damage_type = damage_type
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.size = size
	spawn_projectile.projectile_texture = projectile_texture_resource
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_target_hit(target)

func _resolve_auto_aim_direction() -> Vector2:
	var target := _find_closest_enemy()
	if target != null:
		var direction := global_position.direction_to(target.global_position).normalized()
		if direction != Vector2.ZERO:
			return direction
	var fallback := global_position.direction_to(get_mouse_target()).normalized()
	if fallback == Vector2.ZERO:
		return Vector2.RIGHT
	return fallback

func _find_closest_enemy() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy_ref in tree.get_nodes_in_group("enemies"):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance > maxf(auto_fire_range, 1.0):
			continue
		if distance < nearest_dist:
			nearest_dist = distance
			nearest = enemy
	return nearest

func _update_weapon_rotation() -> void:
	var direction := Vector2.ZERO
	var target := _find_closest_enemy()
	if target != null:
		direction = target.global_position - global_position
	else:
		direction = get_global_mouse_position() - global_position
	if direction == Vector2.ZERO:
		return
	rotation = direction.angle() + deg_to_rad(90)

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "4", "speed": "600", "hp": "1", "fire_interval_sec": "1", "ammo": "45", "cost": "17"}
