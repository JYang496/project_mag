extends Ranger

const CLOSE_CHAIN_RULES := preload("res://Player/Weapons/close_quarters_chain_rules.gd")

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/test/sniper_bullet.png")

# Weapon
var ITEM_NAME = "Shotgun"
@export_range(0, 180) var arc : float = 30
@export var close_hit_trigger_distance: float = 180.0
@export var same_volley_repeat_hit_bonus_ratio: float = 0.25
var bullet_count : int
var base_arc: float = 0.0
var base_bullet_count: int = 3
const VOLLEY_ID_META := "shotgun_base_volley_id"
const VOLLEY_PROJECTILE_META := "shotgun_base_volley_projectile"
var _shotgun_volley_sequence: int = 0
var _shotgun_volley_hit_counts: Dictionary = {}

var weapon_data = {
	"1": {"damage": "14", "speed": "1000", "projectile_hits": "1", "fire_interval_sec": "2", "ammo": "24", "bullet_count": "3"},
	"2": {"damage": "16", "speed": "1000", "projectile_hits": "1", "fire_interval_sec": "2", "ammo": "26", "bullet_count": "4"},
	"3": {"damage": "18", "speed": "1000", "projectile_hits": "1", "fire_interval_sec": "1.8", "ammo": "28", "bullet_count": "5"},
	"4": {"damage": "20", "speed": "1000", "projectile_hits": "1", "fire_interval_sec": "1.8", "ammo": "30", "bullet_count": "6"},
	"5": {"damage": "22", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "32", "bullet_count": "7"},
	"6": {"damage": "24", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "34", "bullet_count": "8"},
	"7": {"damage": "26", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "36", "bullet_count": "9"},
	"8": {"damage": "28", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "38", "bullet_count": "10"},
	"9": {"damage": "30", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "40", "bullet_count": "11"}
}


func set_level(lv):
	lv = str(lv)
	var level_data := get_weapon_level_data(lv, weapon_data)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	base_bullet_count = int(level_data["bullet_count"])
	bullet_count = base_bullet_count
	base_arc = arc
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)

func _on_shoot():
	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = maxf(cooldown, 0.05)
	cooldown_timer.start()
	var main_target: Vector2 = get_mouse_target()
	var base_direction: Vector2 = global_position.direction_to(main_target).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.UP
	var shot_count: int = max(1, bullet_count)
	for behavior in branch_runtime.get_branch_behaviors():
		shot_count = max(1, behavior.get_projectile_count_override(shot_count))
	var spread_arc := base_arc
	for behavior in branch_runtime.get_branch_behaviors():
		spread_arc *= maxf(behavior.get_cone_or_spread_multiplier(), 0.05)
	spread_arc = get_effective_cone_half_angle(spread_arc)
	# Ensure pellets do not collapse into a single line when arc config is missing/zero.
	if shot_count > 1:
		spread_arc = maxf(spread_arc, 18.0)
	var shot_directions: Array[Vector2] = _build_spread_directions(base_direction, shot_count, spread_arc)
	var branch_dirs: Array[Vector2] = branch_runtime.get_branch_shot_directions(base_direction, shot_count)
	if not branch_dirs.is_empty():
		shot_directions = branch_dirs
	# Guard against default branch fallback returning a single forward direction.
	if shot_count > 1 and shot_directions.size() <= 1:
		shot_directions = _build_spread_directions(base_direction, shot_count, spread_arc)
	if OS.is_debug_build():
		print("[Shotgun] shot_count=", shot_count, " dirs=", shot_directions.size(), " spread_arc=", spread_arc)
	var runtime_damage := get_runtime_shot_damage()
	var damage_multiplier := branch_runtime.get_branch_projectile_damage_multiplier()
	var damage_type: StringName = branch_runtime.get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	_shotgun_volley_sequence += 1
	var volley_id := _shotgun_volley_sequence
	_shotgun_volley_hit_counts[volley_id] = {}
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
		spawn_projectile.set_meta(VOLLEY_ID_META, volley_id)
		spawn_projectile.set_meta(VOLLEY_PROJECTILE_META, true)
		apply_effects_on_projectile(spawn_projectile)
		get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)
	_cleanup_old_shotgun_volleys(volley_id)

func supports_multi_launcher_module() -> bool:
	return true

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
	_try_trigger_close_hit(target)
	branch_runtime.notify_branch_target_hit(target)

func on_projectile_hit_damage_dealt(projectile: Node, target: Node, hit_damage_type: StringName, final_damage: int) -> void:
	if final_damage <= 0:
		return
	if projectile == null or not is_instance_valid(projectile):
		return
	if target == null or not is_instance_valid(target):
		return
	if not bool(projectile.get_meta(VOLLEY_PROJECTILE_META, false)):
		return
	var volley_id := int(projectile.get_meta(VOLLEY_ID_META, 0))
	if volley_id <= 0:
		return
	var hit_counts: Dictionary = _shotgun_volley_hit_counts.get(volley_id, {})
	var target_id := target.get_instance_id()
	var next_count := int(hit_counts.get(target_id, 0)) + 1
	hit_counts[target_id] = next_count
	_shotgun_volley_hit_counts[volley_id] = hit_counts
	if next_count <= 1:
		return
	_apply_same_volley_repeat_hit_bonus(target, hit_damage_type, final_damage, volley_id, target_id, next_count)

func _apply_same_volley_repeat_hit_bonus(
	target: Node,
	hit_damage_type: StringName,
	final_damage: int,
	volley_id: int,
	target_id: int,
	hit_index: int
) -> void:
	CLOSE_CHAIN_RULES.apply_final_bonus_damage(
		self,
		target,
		Attack.normalize_damage_type(hit_damage_type),
		final_damage,
		same_volley_repeat_hit_bonus_ratio,
		StringName("shotgun_same_volley_bonus_%d_%d_%d" % [volley_id, target_id, hit_index])
	)

func _cleanup_old_shotgun_volleys(current_volley_id: int) -> void:
	var min_kept := maxi(1, current_volley_id - 6)
	for key in _shotgun_volley_hit_counts.keys():
		if int(key) < min_kept:
			_shotgun_volley_hit_counts.erase(key)

func _try_trigger_close_hit(target: Node) -> void:
	var target_node := target as Node2D
	if target_node == null or not is_instance_valid(target_node):
		return
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player):
		return
	var distance := player.global_position.distance_to(target_node.global_position)
	if distance >= maxf(close_hit_trigger_distance, 0.0):
		return
	if not is_offhand_skill_ready():
		return
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"shotgun_close_hit_triggered", {
		"target": target,
		"distance": distance,
		"threshold": close_hit_trigger_distance,
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var state := "ready"
	if not is_passive_ready():
		state = "waiting_refresh"
	var charge_current := passive_controller.get_passive_charge_current()
	var charge_max := passive_controller.get_passive_charge_max()
	return with_passive_charge_status({
		"id": "shotgun_close_hit_triggered",
		"display_name": "Close Hit",
		"state": state,
		"progress": float(charge_current) / float(maxi(charge_max, 1)),
		"ready": state == "ready",
		"condition_type": "distance_threshold",
		"required": maxf(close_hit_trigger_distance, 0.0),
		"comparison": "<",
		"trigger_hint": "hit_distance",
		"refresh_hint": "reload",
		"charge_current": charge_current,
		"charge_max": charge_max,
		"charges_current": charge_current,
		"charges_max": charge_max,
		"same_volley_repeat_hit_bonus_ratio": maxf(same_volley_repeat_hit_bonus_ratio, 0.0),
	})

func get_passive_max_charges() -> int:
	return 3
