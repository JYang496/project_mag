extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/sniper_bullet.png")

# Weapon
var ITEM_NAME = "Shotgun"
@export_range(0, 180) var arc : float = 30
var bullet_count : int
var base_arc: float = 0.0
var base_bullet_count: int = 3

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "14",
		"speed": "1000",
		"hp": "1",
		"fire_interval_sec": "2",
		"ammo": "24",
		"bullet_count": "3",
		"cost": "7",
	},
	"2": {
		"level": "2",
		"damage": "16",
		"speed": "1000",
		"hp": "1",
		"fire_interval_sec": "2",
		"ammo": "26",
		"bullet_count": "4",
		"cost": "7",
	},
	"3": {
		"level": "3",
		"damage": "18",
		"speed": "1000",
		"hp": "1",
		"fire_interval_sec": "1.8",
		"ammo": "28",
		"bullet_count": "5",
		"cost": "7",
	},
	"4": {
		"level": "4",
		"damage": "20",
		"speed": "1000",
		"hp": "1",
		"fire_interval_sec": "1.8",
		"ammo": "30",
		"bullet_count": "6",
		"cost": "7",
	},
	"5": {
		"level": "5",
		"damage": "22",
		"speed": "1000",
		"hp": "2",
		"fire_interval_sec": "1.6",
		"ammo": "32",
		"bullet_count": "7",
		"cost": "7",
	},
	"6": {
		"level": "6",
		"damage": "24",
		"speed": "1000",
		"hp": "2",
		"fire_interval_sec": "1.6",
		"ammo": "34",
		"bullet_count": "8",
		"cost": "7",
	},
	"7": {
		"level": "7",
		"damage": "26",
		"speed": "1000",
		"hp": "2",
		"fire_interval_sec": "1.6",
		"ammo": "36",
		"bullet_count": "9",
		"cost": "7",
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
	base_bullet_count = int(weapon_data[lv]["bullet_count"])
	bullet_count = base_bullet_count
	base_arc = arc
	sync_stats()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)

func _on_shoot():
	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= maxf(branch_behavior.get_cooldown_multiplier(), 0.05)
	cooldown_timer.wait_time = maxf(cooldown, 0.05)
	cooldown_timer.start()
	var main_target: Vector2 = get_mouse_target()
	var base_direction: Vector2 = global_position.direction_to(main_target).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.UP
	var shot_count: int = max(1, bullet_count)
	if branch_behavior and is_instance_valid(branch_behavior):
		if branch_behavior.has_method("get_projectile_count_override"):
			shot_count = max(1, int(branch_behavior.call("get_projectile_count_override", shot_count)))
	var spread_arc := base_arc
	if branch_behavior and is_instance_valid(branch_behavior):
		spread_arc *= maxf(branch_behavior.get_cone_or_spread_multiplier(), 0.05)
	# Ensure pellets do not collapse into a single line when arc config is missing/zero.
	if shot_count > 1:
		spread_arc = maxf(spread_arc, 18.0)
	var shot_directions: Array[Vector2] = _build_spread_directions(base_direction, shot_count, spread_arc)
	if branch_behavior and is_instance_valid(branch_behavior):
		var branch_dirs: Array[Vector2] = branch_behavior.get_shot_directions(base_direction, shot_count)
		if not branch_dirs.is_empty():
			shot_directions = branch_dirs
	# Guard against default branch fallback returning a single forward direction.
	if shot_count > 1 and shot_directions.size() <= 1:
		shot_directions = _build_spread_directions(base_direction, shot_count, spread_arc)
	if OS.is_debug_build():
		print("[Shotgun] shot_count=", shot_count, " dirs=", shot_directions.size(), " spread_arc=", spread_arc)
	var runtime_damage := get_runtime_shot_damage()
	var damage_multiplier := 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_multiplier = maxf(branch_behavior.get_projectile_damage_multiplier(), 0.05)
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if branch_behavior and is_instance_valid(branch_behavior):
		if branch_behavior.has_method("get_damage_type_override"):
			damage_type = Attack.normalize_damage_type(branch_behavior.call("get_damage_type_override"))
	for dir in shot_directions:
		var spawn_projectile = spawn_projectile_from_scene(projectile_template)
		if spawn_projectile == null:
			continue
		projectile_direction = dir.normalized()
		spawn_projectile.damage = max(1, int(round(float(runtime_damage) * damage_multiplier)))
		spawn_projectile.damage_type = damage_type
		spawn_projectile.global_position = global_position
		spawn_projectile.projectile_texture = projectile_texture_resource
		spawn_projectile.size = size
		spawn_projectile.hp = projectile_hits
		spawn_projectile.expire_time = 0.3
		apply_effects_on_projectile(spawn_projectile)
		get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _build_spread_directions(base_direction: Vector2, shot_count: int, spread_arc: float) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	var count: int = maxi(1, shot_count)
	if count == 1:
		dirs.append(base_direction.normalized())
		return dirs
	var start_angle := base_direction.angle()
	var angle_step := deg_to_rad(spread_arc) / maxf(float(max(1, count - 1)), 1.0)
	var start_offset := -deg_to_rad(spread_arc) / 2.0
	for i in range(count):
		var current_angle := start_angle + start_offset + (angle_step * float(i))
		dirs.append(Vector2.RIGHT.rotated(current_angle).normalized())
	return dirs

func get_random_position_in_circle(radius: float = 50.0) -> Vector2:
	var angle = randf_range(0, TAU)  # TAU is 2*PI in Godot
	var x = cos(angle) * radius
	var y = sin(angle) * radius
	return Vector2(x, y)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_target_hit(target)
