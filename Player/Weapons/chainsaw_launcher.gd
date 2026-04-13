extends Ranger

var spin_effect = preload("res://Player/Weapons/Effects/spin_effect.tscn")
var scale_up_by_time_effect = preload("res://Player/Weapons/Effects/scale_up_by_time.tscn")
var chase_closest_enemy_effect = preload("res://Player/Weapons/Effects/chase_closest_enemy.tscn")

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/chainsaw_spin.png")
#@onready var sprite = get_node("%Sprite")

# Weapon
var ITEM_NAME = "Chainsaw Luncher"
var _last_hit_projectile: Projectile

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "2",
		"speed": "200",
		"hp": "15",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "4",
		"speed": "200",
		"hp": "15",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "7",
		"speed": "200",
		"hp": "20",
		"dot_cd": "0.1",
		"reload": "1",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "10",
		"speed": "200",
		"hp": "25",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "15",
		"speed": "200",
		"hp": "25",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
	},
	"6": {
		"level": "6",
		"damage": "20",
		"speed": "200",
		"hp": "30",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
	},
	"7": {
		"level": "25",
		"damage": "15",
		"speed": "200",
		"hp": "30",
		"dot_cd": "0.1",
		"reload": "0.75",
		"cost": "1",
	}
}


func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	base_speed = int(weapon_data[lv]["speed"])
	base_projectile_hits = int(weapon_data[lv]["hp"])
	dot_cd = float(weapon_data[lv]["dot_cd"])
	base_attack_cooldown = float(weapon_data[lv]["reload"])
	sync_stats()
	_sync_speed_change_effect_config()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)


func _on_shoot():
	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= maxf(branch_behavior.get_cooldown_multiplier(), 0.05)
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()
	var spawn_projectile = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	projectile_direction = global_position.direction_to(get_mouse_target()).normalized()
	var runtime_damage: int = get_runtime_shot_damage()
	if branch_behavior and is_instance_valid(branch_behavior):
		runtime_damage = maxi(1, int(round(float(runtime_damage) * maxf(branch_behavior.get_projectile_damage_multiplier(), 0.05))))
	spawn_projectile.damage = runtime_damage
	spawn_projectile.damage_type = Attack.TYPE_PHYSICAL
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.size = size
	spawn_projectile.hitbox_type = "dot"
	spawn_projectile.dot_cd = dot_cd
	apply_spin(spawn_projectile)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_weapon_shot(projectile_direction)

func apply_spin(projectile_node) -> void:
	var spin_movement_ins = spin_effect.instantiate()
	projectile_node.call_deferred("add_child",spin_movement_ins)
	projectile_node.module_list.append(spin_movement_ins)
	module_list.append(spin_movement_ins)

func apply_scale_up_by_time(projectile_node) -> void:
	var scale_up_by_time = scale_up_by_time_effect.instantiate()
	projectile_node.call_deferred("add_child",scale_up_by_time)
	projectile_node.module_list.append(scale_up_by_time)
	module_list.append(scale_up_by_time)

func apply_chase_closest_enemy(projectile_node) -> void:
	var chase_ins = chase_closest_enemy_effect.instantiate()
	projectile_node.call_deferred("add_child",chase_ins)
	projectile_node.module_list.append(chase_ins)
	module_list.append(chase_ins)

func _on_chainsaw_luncher_timer_timeout() -> void:
	is_on_cooldown = false

# Ensures the typed speed-change effect config exists and stays synced.
func _sync_speed_change_effect_config() -> void:
	var config := ensure_effect_config(&"speed_change_on_hit")
	if config is SpeedChangeOnHitEffectConfig:
		var speed_config := config as SpeedChangeOnHitEffectConfig
		speed_config.speed_rate = 0.3

func on_projectile_hit_target(projectile: Projectile, _target: Node) -> void:
	_last_hit_projectile = projectile

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if branch_behavior and is_instance_valid(branch_behavior):
		if branch_behavior.has_method("on_chainsaw_target_hit"):
			branch_behavior.call("on_chainsaw_target_hit", target, _last_hit_projectile)
		else:
			branch_behavior.on_target_hit(target)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if branch_behavior and is_instance_valid(branch_behavior) and branch_behavior.has_method("on_passive_event"):
		branch_behavior.call("on_passive_event", event_name, detail)

func split_projectile_with_ricochet(source: Projectile) -> void:
	if source == null or not is_instance_valid(source):
		return
	var split_projectile: Projectile = _spawn_split_projectile_from(source)
	if split_projectile == null:
		return
	var current_speed: float = source.base_displacement.length()
	if current_speed <= 0.01:
		current_speed = maxf(float(speed), 1.0)
	current_speed = maxf(current_speed, 1.0)
	var chase_direction: Vector2 = _resolve_direction_to_closest_enemy(split_projectile.global_position)
	if chase_direction == Vector2.ZERO:
		chase_direction = source.base_displacement.normalized()
	if chase_direction == Vector2.ZERO:
		chase_direction = Vector2.RIGHT
	split_projectile.base_displacement = chase_direction * current_speed
	split_projectile.rotation = chase_direction.angle() + deg_to_rad(90.0)
	split_projectile.set_meta("ricochet_split_done", true)
	source.set_meta("ricochet_split_done", true)

func _spawn_split_projectile_from(source: Projectile) -> Projectile:
	var split_node: Node2D = spawn_projectile_from_scene(projectile_template)
	var split_projectile: Projectile = split_node as Projectile
	if split_projectile == null:
		return null
	split_projectile.damage = int(source.damage)
	split_projectile.damage_type = Attack.normalize_damage_type(source.damage_type)
	split_projectile.hp = maxi(1, int(source.hp))
	split_projectile.global_position = source.global_position
	split_projectile.projectile_texture = source.projectile_texture
	split_projectile.size = source.size
	split_projectile.desired_pixel_size = source.desired_pixel_size
	split_projectile.hitbox_type = source.hitbox_type
	split_projectile.dot_cd = source.dot_cd
	split_projectile.knock_back = source.knock_back.duplicate(true)
	var source_timer: Timer = source.get_node_or_null("ExpireTimer") as Timer
	if source_timer != null:
		split_projectile.expire_time = maxf(source_timer.time_left, 0.1)
	else:
		split_projectile.expire_time = maxf(source.expire_time, 0.1)
	# Keep base motion unless caller overrides for ricochet behavior.
	split_projectile.base_displacement = source.base_displacement
	split_projectile.projectile_displacement = source.projectile_displacement
	apply_spin(split_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", split_projectile)
	return split_projectile

func _resolve_direction_to_closest_enemy(from_position: Vector2) -> Vector2:
	var tree := get_tree()
	if tree == null:
		return Vector2.ZERO
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy_ref in tree.get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist: float = from_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest == null:
		return Vector2.ZERO
	return from_position.direction_to(nearest.global_position).normalized()
