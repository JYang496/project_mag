extends Ranger

const CLOSE_CHAIN_RULES := preload("res://Player/Weapons/close_quarters_chain_rules.gd")

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/shotgun_pellet.png")

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
const VOLLEY_WAVE_META := "shotgun_volley_wave"
var _shotgun_volley_sequence: int = 0
var _shotgun_volley_hit_counts: Dictionary = {}

func _init() -> void:
	super._init()
	range_mode = RangeMode.FIXED_LIFETIME
	projectile_lifetime_sec = 0.3

var weapon_data = {
	"1": {"damage": "14", "speed": "1000", "projectile_hits": "1", "fire_interval_sec": "2", "ammo": "5", "bullet_count": "4"},
	"2": {"damage": "16", "speed": "1000", "projectile_hits": "1", "fire_interval_sec": "2", "ammo": "5", "bullet_count": "4"},
	"3": {"damage": "18", "speed": "1000", "projectile_hits": "1", "fire_interval_sec": "1.8", "ammo": "6", "bullet_count": "5"},
	"4": {"damage": "20", "speed": "1000", "projectile_hits": "1", "fire_interval_sec": "1.8", "ammo": "6", "bullet_count": "5"},
	"5": {"damage": "22", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "7", "bullet_count": "6"},
	"6": {"damage": "24", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "7", "bullet_count": "6"},
	"7": {"damage": "26", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "7", "bullet_count": "7"},
	"8": {"damage": "28", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "7", "bullet_count": "7"},
	"9": {"damage": "28", "speed": "1000", "projectile_hits": "2", "fire_interval_sec": "1.6", "ammo": "7", "bullet_count": "8"}
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
	var double_config := _get_double_volley_config()
	var base_direction: Vector2 = get_aim_forward()
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
	var runtime_damage := get_runtime_shot_damage()
	var damage_multiplier := branch_runtime.get_branch_projectile_damage_multiplier()
	if consume_entry_trigger():
		damage_multiplier *= 1.35
	var damage_type: StringName = branch_runtime.get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	_shotgun_volley_sequence += 1
	var volley_id := _shotgun_volley_sequence
	_shotgun_volley_hit_counts[volley_id] = {}
	_spawn_shotgun_wave(shot_directions, runtime_damage, damage_multiplier, damage_type, volley_id, 1)
	if not double_config.is_empty():
		var second_spread := spread_arc * clampf(float(double_config.get("second_spread_multiplier", 0.65)), 0.05, 1.0)
		var second_directions := _build_spread_directions(base_direction, shot_directions.size(), second_spread)
		_spawn_delayed_second_wave(
			second_directions,
			runtime_damage,
			damage_multiplier,
			damage_type,
			volley_id,
			maxf(float(double_config.get("second_wave_delay_sec", 0.12)), 0.01)
		)
	_cleanup_old_shotgun_volleys(volley_id)

func _spawn_shotgun_wave(
	shot_directions: Array[Vector2],
	runtime_damage: int,
	damage_multiplier: float,
	damage_type: StringName,
	volley_id: int,
	wave_index: int
) -> void:
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
		spawn_projectile.expire_time = get_effective_projectile_lifetime()
		spawn_projectile.set_meta(VOLLEY_ID_META, volley_id)
		spawn_projectile.set_meta(VOLLEY_PROJECTILE_META, true)
		spawn_projectile.set_meta(VOLLEY_WAVE_META, wave_index)
		apply_effects_on_projectile(spawn_projectile)
		get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func _spawn_delayed_second_wave(
	shot_directions: Array[Vector2],
	runtime_damage: int,
	damage_multiplier: float,
	damage_type: StringName,
	volley_id: int,
	delay_sec: float
) -> void:
	await get_tree().create_timer(maxf(delay_sec, 0.01), false).timeout
	if not is_inside_tree() or not is_attack_phase_allowed():
		return
	_spawn_shotgun_wave(shot_directions, runtime_damage, damage_multiplier, damage_type, volley_id, 2)
	emit_passive_trigger(&"shotgun_double_breach_second_wave", {
		"volley_id": volley_id,
		"projectile_count": shot_directions.size(),
		"delay_sec": delay_sec,
	}, PASSIVE_SCOPE_GLOBAL)

func get_primary_fire_ammo_cost() -> int:
	var config := _get_double_volley_config()
	return maxi(int(config.get("ammo_cost", 1)), 1)

func _get_double_volley_config() -> Dictionary:
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.has_method("get_shotgun_double_volley_config"):
			var config: Variant = behavior.call("get_shotgun_double_volley_config")
			if config is Dictionary:
				return config as Dictionary
	return {}

func supports_multi_launcher_module() -> bool:
	return true

func _build_spread_directions(base_direction: Vector2, shot_count: int, spread_arc: float) -> Array[Vector2]:
	var count: int = maxi(1, shot_count)
	if count == 1:
		return [base_direction.normalized()]
	var angle_step := deg_to_rad(spread_arc) / maxf(float(count), 1.0)
	return WeaponBranchBehavior.build_centered_spread_directions(base_direction, count, angle_step)

func get_random_position_in_circle(radius: float = 50.0) -> Vector2:
	var angle = randf_range(0, TAU)  # TAU is 2*PI in Godot
	var x = cos(angle) * radius
	var y = sin(angle) * radius
	return Vector2(x, y)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
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
	if int(projectile.get_meta(VOLLEY_WAVE_META, 1)) == 2:
		for behavior in branch_runtime.get_branch_behaviors():
			if behavior.has_method("apply_double_breach_vulnerability"):
				behavior.call("apply_double_breach_vulnerability", target, volley_id)
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

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name != &"on_cross_weapon_hit":
		return
	var target := detail.get("target", null) as Node
	if target == null or not is_instance_valid(target):
		return
	emit_passive_trigger(&"shotgun_close_hit_triggered", {
		"target": target,
		"trigger": "cross_weapon_hit",
		"refresh": "crossfire",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var state := "ready" if has_entry_trigger_ready() else "waiting_entry"
	return {
		"id": "shotgun_close_hit_triggered",
		"display_name": "Close Hit",
		"state": state,
		"progress": 1.0 if has_entry_trigger_ready() else 0.0,
		"ready": state == "ready",
		"condition_type": "weapon_entry",
		"required": 1,
		"trigger_hint": "weapon_entered_main",
		"refresh_hint": "weapon_entry",
		"same_volley_repeat_hit_bonus_ratio": maxf(same_volley_repeat_hit_bonus_ratio, 0.0),
	}

func get_auto_fire_target_range() -> float:
	return maxf(float(speed) * 0.3, maxf(close_hit_trigger_distance, 1.0))
