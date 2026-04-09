extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

# Weapon
var ITEM_NAME = "Machine Gun"
var attack_speed : float = 1.0
@export var attack_speed_decay_interval: float = 0.35

var max_speed_factor : float = 10.0
var as_timer: Timer

const BULLET_PIXEL_SIZE := Vector2(10.0, 10.0)
const MIN_SPREAD_ANGLE_DEG := 1.0
const MAX_SPREAD_ANGLE_DEG := 18.0

@export var spread_full_distance: float = 900.0
@export var close_range_miss_chance: float = 0.05
@export var long_range_miss_chance: float = 0.85
@export var heat_accumulation: float = 5.5
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 18.0
@export_range(5.0, 80.0, 1.0) var front_fire_half_angle_deg: float = 35.0
var attack_range: float = 800.0

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "5",
		"speed": "600",
		"hp": "1",
		"reload": "2",
		"cost": "1",
	},
	"2": {
		"level": "2",
		"damage": "6",
		"speed": "600",
		"hp": "1",
		"reload": "1.8",
		"cost": "1",
	},
	"3": {
		"level": "3",
		"damage": "7",
		"speed": "600",
		"hp": "1",
		"reload": "1.6",
		"cost": "1",
	},
	"4": {
		"level": "4",
		"damage": "9",
		"speed": "800",
		"hp": "1",
		"reload": "1.3",
		"cost": "1",
	},
	"5": {
		"level": "5",
		"damage": "11",
		"speed": "800",
		"hp": "2",
		"reload": "1.0",
		"cost": "1",
	}
}

var weapon_file
var minigun_data = JSON.new()

func _ready() -> void:
	super._ready()
	_setup_attack_speed_decay_timer()

func _setup_attack_speed_decay_timer() -> void:
	if as_timer and is_instance_valid(as_timer):
		return
	as_timer = Timer.new()
	as_timer.name = "AttackSpeedDecayTimer"
	as_timer.one_shot = false
	as_timer.wait_time = maxf(attack_speed_decay_interval, 0.05)
	add_child(as_timer)
	as_timer.timeout.connect(Callable(self, "_on_as_timer_timeout"))
	as_timer.start()


func set_level(lv):
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["hp"])
	base_attack_cooldown = float(level_data["reload"])
	attack_range = float(level_data.get("range", attack_range))
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)

func _on_shoot():
	is_on_cooldown = true
	var cooldown := attack_cooldown / attack_speed
	cooldown = cooldown / maxf(get_external_attack_speed_multiplier(), 0.1)
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= branch_behavior.get_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()
	var target_position: Vector2 = get_mouse_target()
	var base_direction: Vector2 = global_position.direction_to(target_position).normalized()
	var shot_distance: float = global_position.distance_to(target_position)
	var shot_directions: Array[Vector2] = [base_direction]
	if branch_behavior and is_instance_valid(branch_behavior):
		shot_directions = branch_behavior.get_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]
	var fired_count := 0
	for dir in shot_directions:
		var spreaded := _apply_distance_based_spread(dir.normalized(), shot_distance)
		var constrained := _constrain_to_forward_cone(spreaded, base_direction)
		_fire_single_bullet(constrained)
		fired_count += 1
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_weapon_shot(base_direction)
	var extra_heat_multiplier := 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		if branch_behavior.has_method("get_extra_heat_shot_multiplier"):
			extra_heat_multiplier = float(branch_behavior.call("get_extra_heat_shot_multiplier"))
	var extra_heat_shots := float(max(0, fired_count - 1)) * clampf(extra_heat_multiplier, 0.0, 1.0)
	register_shot_heat(extra_heat_shots)
	adjust_attack_speed(1.2)

func adjust_attack_speed(rate : float) -> void:
	attack_speed = clampf(attack_speed * rate, 1.0, max_speed_factor)


func _on_as_timer_timeout() -> void:
	if not is_on_cooldown:
		adjust_attack_speed(0.8)

func _get_level_data(lv: String) -> Dictionary:
	if weapon_data.has(lv):
		return weapon_data[lv]
	var lv_int := int(lv)
	for i in range(lv_int, 0, -1):
		var key := str(i)
		if weapon_data.has(key):
			return weapon_data[key]
	if weapon_data.has("1"):
		return weapon_data["1"]
	
	# This should not trigger
	return {
		"level": "1",
		"damage": "5",
		"speed": "600",
		"hp": "1",
		"reload": "2",
	}

func _constrain_to_forward_cone(direction: Vector2, forward: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return forward
	if forward == Vector2.ZERO:
		return direction
	var normalized_dir := direction.normalized()
	var normalized_forward := forward.normalized()
	var cone_rad := deg_to_rad(front_fire_half_angle_deg)
	var angle := normalized_forward.angle_to(normalized_dir)
	if absf(angle) <= cone_rad:
		return normalized_dir
	return normalized_forward.rotated(signf(angle) * cone_rad).normalized()

func _apply_distance_based_spread(direction: Vector2, shot_distance: float) -> Vector2:
	if direction == Vector2.ZERO:
		return direction
	var distance_ratio := 0.0
	if spread_full_distance > 0.0:
		distance_ratio = clampf(shot_distance / spread_full_distance, 0.0, 1.0)
	var miss_chance := lerpf(close_range_miss_chance, long_range_miss_chance, distance_ratio)
	if randf() > miss_chance:
		return direction
	var max_spread_radians := deg_to_rad(lerpf(MIN_SPREAD_ANGLE_DEG, MAX_SPREAD_ANGLE_DEG, distance_ratio))
	var spread_offset := randf_range(-max_spread_radians, max_spread_radians)
	return direction.rotated(spread_offset).normalized()

func _fire_single_bullet(direction: Vector2) -> void:
	projectile_direction = direction
	var spawn_projectile = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	var runtime_damage: int = int(get_runtime_shot_damage())
	var damage_multiplier: float = 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		if branch_behavior.has_method("get_projectile_damage_multiplier"):
			damage_multiplier = float(branch_behavior.call("get_projectile_damage_multiplier"))
	var final_damage: int = max(1, int(round(float(runtime_damage) * maxf(damage_multiplier, 0.05))))
	spawn_projectile.damage = final_damage
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if branch_behavior and is_instance_valid(branch_behavior):
		if branch_behavior.has_method("get_damage_type_override"):
			damage_type = Attack.normalize_damage_type(branch_behavior.call("get_damage_type_override"))
	spawn_projectile.damage_type = damage_type
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.15)
	apply_effects_on_projectile(spawn_projectile)
	get_tree().root.call_deferred("add_child", spawn_projectile)
