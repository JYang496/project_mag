extends Ranger

const PROJECTILE_SCENE := preload("res://Player/Weapons/Projectiles/projectile.tscn")
const PROJECTILE_TEXTURE := preload("res://asset/images/weapons/projectiles/energy_bolt_a.png")
const PROJECTILE_FRAMES := preload("res://Player/Weapons/Projectiles/energy_bolt_frames.tres")
const HOMING_EFFECT := preload("res://Player/Weapons/Effects/homing_projectile_effect.gd")

const BOLT_DAMAGE_MULTIPLIER := 0.45
const BOLT_PIXEL_SIZE := Vector2(16, 16)

var ITEM_NAME := "Homing Energy Bolts"
var base_bolt_count := 3

@export_range(1.0, 90.0, 0.5) var volley_half_angle_deg: float = 60.0
@export var homing_turn_rate_deg_per_sec: float = 400.0
@export var homing_acquisition_radius: float = 500.0
@export_range(0.0, 180.0, 1.0) var homing_acquisition_half_angle_deg: float = 75.0
@export var homing_release_radius_multiplier: float = 1.35

var weapon_data := {
	"1": {"damage": "18", "speed": "460", "projectile_hits": "1", "bolt_count": "3", "fire_interval_sec": "1.10", "ammo": "9"},
	"2": {"damage": "22", "speed": "470", "projectile_hits": "1", "bolt_count": "3", "fire_interval_sec": "1.08", "ammo": "9"},
	"3": {"damage": "26", "speed": "480", "projectile_hits": "1", "bolt_count": "4", "fire_interval_sec": "1.05", "ammo": "10"},
	"4": {"damage": "30", "speed": "490", "projectile_hits": "1", "bolt_count": "4", "fire_interval_sec": "1.00", "ammo": "10"},
	"5": {"damage": "34", "speed": "500", "projectile_hits": "1", "bolt_count": "5", "fire_interval_sec": "0.95", "ammo": "11"},
	"6": {"damage": "38", "speed": "510", "projectile_hits": "1", "bolt_count": "5", "fire_interval_sec": "0.90", "ammo": "11"},
	"7": {"damage": "42", "speed": "520", "projectile_hits": "1", "bolt_count": "6", "fire_interval_sec": "0.85", "ammo": "12"},
	"8": {"damage": "46", "speed": "530", "projectile_hits": "1", "bolt_count": "6", "fire_interval_sec": "0.80", "ammo": "12"},
	"9": {"damage": "50", "speed": "540", "projectile_hits": "1", "bolt_count": "6", "fire_interval_sec": "0.75", "ammo": "13"},
}

func _init() -> void:
	super._init()
	range_mode = RangeMode.FIXED_DISTANCE
	configured_attack_range = 780.0

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := get_weapon_level_data(lv, weapon_data)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])
	base_bolt_count = maxi(int(level_data["bolt_count"]), 1)
	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)

func _on_shoot() -> void:
	is_on_cooldown = true
	start_weapon_cooldown(0.05)
	var base_direction := get_aim_forward()
	var shared_target := _find_pack_hunt_target(base_direction)
	var launcher_directions := branch_runtime.get_branch_shot_directions(base_direction)
	if launcher_directions.is_empty():
		launcher_directions = [base_direction]
	for launcher_direction in launcher_directions:
		for direction in _build_volley_directions(launcher_direction):
			_fire_energy_bolt(direction, shared_target)
	branch_runtime.notify_branch_weapon_shot(base_direction)

func supports_multi_launcher_module() -> bool:
	return true

func _build_volley_directions(base_direction: Vector2) -> Array[Vector2]:
	var safe_direction := base_direction.normalized()
	if safe_direction == Vector2.ZERO:
		safe_direction = Vector2.UP
	var bolt_count := get_effective_projectile_count(base_bolt_count)
	if bolt_count <= 1:
		return [safe_direction]
	var step_radians := deg_to_rad(volley_half_angle_deg * 2.0) / float(bolt_count - 1)
	return WeaponBranchBehavior.build_centered_spread_directions(safe_direction, bolt_count, step_radians)

func _fire_energy_bolt(direction: Vector2, shared_target: Node2D = null) -> void:
	var bolt := spawn_projectile_from_scene(PROJECTILE_SCENE) as Projectile
	if bolt == null:
		return
	projectile_direction = direction.normalized()
	bolt.damage = maxi(1, int(round(float(get_runtime_damage()) * BOLT_DAMAGE_MULTIPLIER)))
	bolt.damage_type = Attack.TYPE_ENERGY
	bolt.hp = projectile_hits
	bolt.global_position = get_muzzle_global_position()
	bolt.projectile_texture = PROJECTILE_TEXTURE
	bolt.projectile_frames = PROJECTILE_FRAMES
	bolt.desired_pixel_size = BOLT_PIXEL_SIZE
	bolt.size = size
	bolt.expire_time = get_effective_projectile_lifetime()
	bolt.configure_gameplay_hitbox(Vector2(10.0, 10.0))
	apply_effects_on_projectile(bolt)
	var homing := HOMING_EFFECT.new().setup(
		bolt,
		deg_to_rad(maxf(
			homing_turn_rate_deg_per_sec * branch_runtime.get_energy_bolt_homing_turn_multiplier(),
			0.1
		)),
		maxf(homing_acquisition_radius, 1.0),
		clampf(homing_acquisition_half_angle_deg, 0.0, 180.0),
		maxf(homing_release_radius_multiplier, 1.0),
		null,
		shared_target
	)
	bolt.add_child(homing)
	bolt.module_list.append(homing)
	get_projectile_spawn_parent().call_deferred("add_child", bolt)

func try_defer_projectile_hit_damage(
	projectile: Projectile,
	target: Node,
	base_damage_value: int,
	damage_type: StringName,
	knock_back_data: Dictionary
) -> bool:
	return branch_runtime.try_defer_energy_bolt_damage(
		projectile,
		target,
		base_damage_value,
		damage_type,
		knock_back_data
	)

func _find_pack_hunt_target(base_direction: Vector2) -> Node2D:
	if not branch_runtime.uses_energy_bolt_pack_hunt():
		return null
	var origin := get_muzzle_global_position()
	var forward := base_direction.normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.UP
	var max_angle := deg_to_rad(clampf(homing_acquisition_half_angle_deg, 0.0, 180.0))
	var best_target: Node2D
	var best_angle := INF
	var best_distance := INF
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(
		get_tree(),
		origin,
		maxf(homing_acquisition_radius, 1.0)
	):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		var dead_value: Variant = enemy.get("is_dead")
		if dead_value != null and bool(dead_value):
			continue
		var to_enemy := origin.direction_to(enemy.global_position)
		var angle := absf(forward.angle_to(to_enemy))
		if angle > max_angle:
			continue
		var distance := origin.distance_squared_to(enemy.global_position)
		if angle < best_angle or (is_equal_approx(angle, best_angle) and distance < best_distance):
			best_angle = angle
			best_distance = distance
			best_target = enemy
	return best_target
