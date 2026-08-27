extends Ranger

const CLOSE_CHAIN_RULES := preload("res://Player/Weapons/close_quarters_chain_rules.gd")
const CHAINSAW_SPIN_FRAMES := preload("res://Player/Weapons/Projectiles/chainsaw_spin_frames.tres")
const CHAINSAW_PROJECTILE_PIXEL_SIZE := PixelArtPolicyType.PROJECTILE_LARGE_SIZE
const CELL_BOUNDS_PROVIDER_GROUP := &"board_cell_bounds_provider"

var scale_up_by_time_effect = preload("res://Player/Weapons/Effects/scale_up_by_time.tscn")

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/chainsaw_spin_01.png")

# Weapon
var ITEM_NAME = "Chainsaw Launcher"
var _last_hit_projectile: Projectile
var _cell_bounce_hit_effect_active: bool = false
@export_flags_2d_physics var chainsaw_wall_collision_mask: int = 32
@export var bounce_lifetime_bonus_sec: float = 1.0
@export var bounce_lifetime_bonus_max_sec: float = 2.0
@export var bounce_slow_multiplier: float = 0.7
@export var bounce_slow_duration_sec: float = 3.0
@export var close_vulnerability_multiplier: float = 1.15
@export var close_vulnerability_duration_sec: float = 6.0

func _init() -> void:
	super._init()
	range_mode = RangeMode.FIXED_LIFETIME
	projectile_lifetime_sec = 2.5

var weapon_data = {
	"1": {"damage": "3", "speed": "200", "projectile_hits": "15", "dot_cd": "0.1", "fire_interval_sec": "1", "ammo": "12"},
	"2": {"damage": "4", "speed": "200", "projectile_hits": "15", "dot_cd": "0.1", "fire_interval_sec": "1", "ammo": "12"},
	"3": {"damage": "5", "speed": "200", "projectile_hits": "20", "dot_cd": "0.1", "fire_interval_sec": "1", "ammo": "12"},
	"4": {"damage": "7", "speed": "200", "projectile_hits": "25", "dot_cd": "0.1", "fire_interval_sec": "0.75", "ammo": "18"},
	"5": {"damage": "9", "speed": "200", "projectile_hits": "25", "dot_cd": "0.1", "fire_interval_sec": "0.75", "ammo": "18"},
	"6": {"damage": "12", "speed": "200", "projectile_hits": "30", "dot_cd": "0.1", "fire_interval_sec": "0.75", "ammo": "18"},
	"7": {"damage": "15", "speed": "200", "projectile_hits": "30", "dot_cd": "0.1", "fire_interval_sec": "0.75", "ammo": "18"},
	"8": {"damage": "18", "speed": "200", "projectile_hits": "30", "dot_cd": "0.1", "fire_interval_sec": "0.75", "ammo": "18"},
	"9": {"damage": "21", "speed": "200", "projectile_hits": "30", "dot_cd": "0.1", "fire_interval_sec": "0.75", "ammo": "18"}
}


func set_level(lv):
	var requested_level := maxi(int(lv), 1)
	var key := get_weapon_level_key(requested_level, weapon_data)
	var level_data: Dictionary = get_weapon_level_data(key, weapon_data)
	if level_data.is_empty():
		return
	level = int(key)
	base_damage = int(level_data.get("damage", 1))
	base_speed = int(level_data.get("speed", 0))
	base_projectile_hits = int(level_data.get("projectile_hits", 1))
	dot_cd = float(level_data.get("dot_cd", 0.1))
	base_attack_cooldown = float(level_data.get("fire_interval_sec", 1.0))
	apply_level_ammo(level_data)
	sync_stats()
	_sync_speed_change_effect_config()
	branch_runtime.notify_branch_level_applied(level)


func _on_shoot():
	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()
	var spawn_projectile = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	projectile_direction = get_aim_forward()
	var runtime_damage: int = get_runtime_shot_damage()
	runtime_damage = maxi(1, int(round(float(runtime_damage) * branch_runtime.get_branch_projectile_damage_multiplier())))
	spawn_projectile.damage = runtime_damage
	spawn_projectile.damage_type = Attack.TYPE_PHYSICAL
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.projectile_frames = CHAINSAW_SPIN_FRAMES
	spawn_projectile.desired_pixel_size = CHAINSAW_PROJECTILE_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.hitbox_type = "dot"
	spawn_projectile.dot_cd = dot_cd
	spawn_projectile.wall_collision_mask = chainsaw_wall_collision_mask
	spawn_projectile.expire_time = get_effective_projectile_lifetime()
	_configure_projectile_cell_boundary(spawn_projectile)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)
	branch_runtime.notify_branch_weapon_shot(projectile_direction)

func apply_scale_up_by_time(projectile_node) -> void:
	var scale_up_by_time = scale_up_by_time_effect.instantiate()
	projectile_node.call_deferred("add_child",scale_up_by_time)
	projectile_node.module_list.append(scale_up_by_time)

func _on_chainsaw_luncher_timer_timeout() -> void:
	is_on_cooldown = false

# Ensures the typed speed-change effect config exists and stays synced.
func _sync_speed_change_effect_config() -> void:
	var config := ensure_effect_config(&"speed_change_on_hit")
	if config is SpeedChangeOnHitEffectConfig:
		var speed_config := config as SpeedChangeOnHitEffectConfig
		speed_config.speed_rate = 0.3

func on_projectile_hit_target(projectile: Projectile, target: Node) -> void:
	_last_hit_projectile = projectile
	_try_apply_cell_bounce_hit_effects(target)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	_notify_chainsaw_target_hit(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	super.on_hit_target_with_damage_type(target, damage_type)
	_notify_chainsaw_target_hit(target)

func _notify_chainsaw_target_hit(target: Node) -> void:
	for behavior in branch_runtime.get_branch_behaviors():
		behavior.on_chainsaw_target_hit(target, _last_hit_projectile)
		behavior.on_target_hit(target)

func _try_apply_cell_bounce_hit_effects(target: Node) -> void:
	if not _cell_bounce_hit_effect_active:
		return
	CLOSE_CHAIN_RULES.apply_slow_to_target(target, bounce_slow_multiplier, bounce_slow_duration_sec)
	CLOSE_CHAIN_RULES.apply_chainsaw_vulnerability(target, close_vulnerability_multiplier, close_vulnerability_duration_sec)

func on_projectile_hit_wall(projectile: Projectile, wall_hit: Dictionary) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	var applied_lifetime_bonus := projectile.extend_remaining_lifetime(
		bounce_lifetime_bonus_sec,
		bounce_lifetime_bonus_max_sec
	)
	projectile.set_meta("chainsaw_lifetime_bonus_applied", applied_lifetime_bonus)

func get_passive_status() -> Dictionary:
	var state := "ready"
	if _cell_bounce_hit_effect_active:
		state = "active"
	return {
		"id": "chainsaw_wall_contact_triggered",
		"display_name": "Wall Contact",
		"state": state,
		"progress": 1.0 if state == "ready" or state == "active" else 0.0,
		"ready": state == "active",
		"trigger_hint": "continuous_hits",
		"refresh_hint": "continuous_hits",
		"bounce_lifetime_bonus": maxf(bounce_lifetime_bonus_sec, 0.0),
		"bounce_lifetime_bonus_max": maxf(bounce_lifetime_bonus_max_sec, 0.0),
		"slow_multiplier": clampf(bounce_slow_multiplier, 0.05, 1.0),
		"slow_duration": maxf(bounce_slow_duration_sec, 0.1),
		"vulnerability_multiplier": maxf(close_vulnerability_multiplier, 1.0),
		"vulnerability_duration": maxf(close_vulnerability_duration_sec, 0.1),
	}

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name == &"on_continuous_hit_threshold" and int(detail.get("threshold", 0)) >= 3:
		_cell_bounce_hit_effect_active = true
		emit_passive_trigger(&"chainsaw_wall_contact_triggered", {
			"trigger": "continuous_hits",
			"target": detail.get("target"),
			"hit_count": int(detail.get("hit_count", 0)),
			"threshold": int(detail.get("threshold", 3)),
			"state_after_trigger": "active",
		}, PASSIVE_SCOPE_GLOBAL)
	branch_runtime.notify_branch_passive_event(event_name, detail)

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
	split_projectile.projectile_frames = source.projectile_frames
	split_projectile.size = source.size
	split_projectile.desired_pixel_size = source.desired_pixel_size
	split_projectile.hitbox_type = source.hitbox_type
	split_projectile.dot_cd = source.dot_cd
	split_projectile.knock_back = source.knock_back.duplicate(true)
	split_projectile.source_weapon = source.source_weapon
	split_projectile.wall_collision_mask = source.wall_collision_mask
	if source.boundary_bounce_enabled:
		split_projectile.configure_boundary_bounce(
			source.boundary_bounce_rect.grow(source.boundary_bounce_margin),
			source.boundary_bounce_margin
		)
	split_projectile.collision_arming_delay_sec = source.collision_arming_delay_sec
	var source_timer: Timer = source.get_node_or_null("ExpireTimer") as Timer
	if source_timer != null:
		split_projectile.expire_time = maxf(source_timer.time_left, 0.1)
	else:
		split_projectile.expire_time = maxf(source.expire_time, 0.1)
	# Keep base motion unless caller overrides for ricochet behavior.
	split_projectile.base_displacement = source.base_displacement
	split_projectile.projectile_displacement = source.projectile_displacement
	get_projectile_spawn_parent().call_deferred("add_child", split_projectile)
	return split_projectile

func _configure_projectile_cell_boundary(projectile: Projectile) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	var tree := get_tree()
	if tree == null:
		return
	var provider := tree.get_first_node_in_group(CELL_BOUNDS_PROVIDER_GROUP)
	if provider == null or not provider.has_method("get_cell_world_rect_for_point"):
		return
	var bounds_value: Variant = provider.call("get_cell_world_rect_for_point", projectile.global_position)
	if not bounds_value is Rect2:
		return
	var bounds := bounds_value as Rect2
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var projectile_margin := maxf(
		maxf(projectile.desired_pixel_size.x, projectile.desired_pixel_size.y) * maxf(projectile.size, 0.01) * 0.5,
		1.0
	)
	projectile.configure_boundary_bounce(bounds, projectile_margin)

func _resolve_direction_to_closest_enemy(from_position: Vector2) -> Vector2:
	var tree := get_tree()
	if tree == null:
		return Vector2.ZERO
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy_ref in WeaponModuleRuntimeUtils.get_enemy_candidates(tree):
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
