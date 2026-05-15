extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

# Weapon
var ITEM_NAME = "Machine Gun"
var attack_speed : float = 1.0

var max_speed_factor : float = 8.0

const BULLET_PIXEL_SIZE := Vector2(10.0, 10.0)
const HEAT_SPEED_POINTS: Array[Vector2] = [
	Vector2(0.0, 1.0),
	Vector2(20.0, 2.0),
	Vector2(40.0, 4.0),
	Vector2(80.0, 6.0),
	Vector2(100.0, 8.0),
]

@export var heat_accumulation: float = 4
@export var heat_accumulation_per_sec: float = 28.0
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 6.0
@export_range(5.0, 80.0, 1.0) var front_fire_half_angle_deg: float = 35.0
@export var heat_stabilized_duration_sec: float = 8.0
@export var heat_stabilized_full_decay_mul: float = 0.5
@export var heat_stabilized_full_cost_mul: float = 0.75
var attack_range: float = 800.0

var weapon_data = {
	"1": {"level": "1", "damage": "5", "speed": "600", "hp": "1", "fire_interval_sec": "1", "ammo": "50", "cost": "4"},
	"2": {"level": "2", "damage": "6", "speed": "600", "hp": "1", "fire_interval_sec": "1", "ammo": "50", "cost": "4"},
	"3": {"level": "3", "damage": "7", "speed": "600", "hp": "1", "fire_interval_sec": "0.9", "ammo": "55", "cost": "4"},
	"4": {"level": "4", "damage": "9", "speed": "800", "hp": "1", "fire_interval_sec": "0.9", "ammo": "55", "cost": "4"},
	"5": {"level": "5", "damage": "11", "speed": "800", "hp": "2", "fire_interval_sec": "0.8", "ammo": "65", "cost": "4"},
	"6": {"level": "6", "damage": "13", "speed": "800", "hp": "2", "fire_interval_sec": "0.8", "ammo": "65", "cost": "4"},
	"7": {"level": "7", "damage": "15", "speed": "800", "hp": "2", "fire_interval_sec": "0.8", "ammo": "65", "cost": "4"}
}

func _ready() -> void:
	super._ready()

func set_level(lv):
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["hp"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()
	notify_branch_level_applied(level)

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, delta: float) -> void:
	if not can_run_active_behavior():
		return
	if not pressed:
		return
	_add_held_trigger_heat(delta)
	request_primary_fire()

func request_primary_fire() -> bool:
	if not is_attack_phase_allowed():
		return false
	if is_on_cooldown:
		return false
	if not can_fire_with_heat():
		return false
	if not can_fire_with_ammo():
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	if not consume_ammo(1):
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	emit_signal("shoot")
	notify_main_weapon_fired()
	if uses_ammo_system() and current_ammo <= 0:
		request_reload()
	return true

func _on_shoot():
	is_on_cooldown = true
	attack_speed = _resolve_shared_heat_attack_speed()
	var cooldown := attack_cooldown / maxf(attack_speed, 0.1)
	cooldown = cooldown / maxf(get_external_attack_speed_multiplier(), 0.1)
	cooldown *= get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()
	var target_position: Vector2 = get_mouse_target()
	var base_direction: Vector2 = global_position.direction_to(target_position).normalized()
	var shot_directions: Array[Vector2] = [base_direction]
	shot_directions = get_branch_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]
	var fired_count := 0
	for dir in shot_directions:
		var spreaded := apply_distance_spread_to_target(dir.normalized(), target_position)
		var constrained := _constrain_to_forward_cone(spreaded, base_direction)
		_fire_single_bullet(constrained)
		fired_count += 1
	notify_branch_weapon_shot(base_direction)
	var extra_heat_multiplier := get_branch_extra_heat_shot_multiplier()
	var extra_heat_shots := float(max(0, fired_count - 1)) * clampf(extra_heat_multiplier, 0.0, 1.0)
	if extra_heat_shots > 0.0:
		register_shot_heat(extra_heat_shots)

func _resolve_shared_heat_attack_speed() -> float:
	var heat_value := _get_shared_heat_value()
	var resolved_speed := float(HEAT_SPEED_POINTS[0].y)
	for i in range(HEAT_SPEED_POINTS.size() - 1):
		var current := HEAT_SPEED_POINTS[i]
		var next := HEAT_SPEED_POINTS[i + 1]
		if heat_value <= next.x:
			var t := inverse_lerp(current.x, next.x, heat_value)
			resolved_speed = lerpf(current.y, next.y, clampf(t, 0.0, 1.0))
			return clampf(resolved_speed, 1.0, max_speed_factor)
	resolved_speed = float(HEAT_SPEED_POINTS[HEAT_SPEED_POINTS.size() - 1].y)
	return clampf(resolved_speed, 1.0, max_speed_factor)

func _get_shared_heat_value() -> float:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return get_heat_value()
	if PlayerData.player.has_method("get_total_heat_value"):
		return maxf(float(PlayerData.player.call("get_total_heat_value")), 0.0)
	return get_heat_value()

func _add_held_trigger_heat(delta: float) -> void:
	if delta <= 0.0:
		return
	if not can_fire_with_heat():
		return
	if not can_fire_with_ammo():
		return
	var core := _get_active_heat_core()
	if core == null:
		return
	var amount := maxf(heat_accumulation_per_sec, 0.0) * maxf(delta, 0.0)
	if amount <= 0.0:
		return
	if core.has_method("add_heat_amount"):
		core.call("add_heat_amount", amount)
	else:
		core.call("add_heat", amount / maxf(heat_per_shot, 0.001))

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name != &"on_reload_started":
		return
	if detail.get("source_weapon", null) != self:
		return
	if not is_offhand_skill_ready():
		return
	var spent_ratio := clampf(float(detail.get("spent_ratio", 0.0)), 0.0, 1.0)
	if spent_ratio <= 0.0:
		return
	var duration_sec := maxf(heat_stabilized_duration_sec, 0.05)
	var decay_mul := lerpf(1.0, clampf(heat_stabilized_full_decay_mul, 0.0, 1.0), spent_ratio)
	var cost_mul := lerpf(1.0, clampf(heat_stabilized_full_cost_mul, 0.0, 1.0), spent_ratio)
	notify_offhand_skill_triggered(0.0)
	if PlayerData.player and is_instance_valid(PlayerData.player):
		PlayerData.player.call("apply_heat_stabilized", duration_sec, decay_mul, cost_mul)
	emit_passive_trigger(&"machine_gun_heat_stabilized", {
		"trigger": "reload_started",
		"spent_ratio": spent_ratio,
		"duration": duration_sec,
		"cooldown": 0.0,
		"decay_multiplier": decay_mul,
		"cost_multiplier": cost_mul,
		"target_weapon": null,
	}, PASSIVE_SCOPE_GLOBAL)

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
	return {"level": "1", "damage": "5", "speed": "600", "hp": "1", "fire_interval_sec": "1", "ammo": "50", "cost": "4"}

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

func _fire_single_bullet(direction: Vector2) -> void:
	projectile_direction = direction
	var spawn_projectile = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	var runtime_damage: int = int(get_runtime_shot_damage())
	var damage_multiplier: float = get_branch_projectile_damage_multiplier()
	var final_damage: int = max(1, int(round(float(runtime_damage) * maxf(damage_multiplier, 0.05))))
	spawn_projectile.damage = final_damage
	var damage_type: StringName = get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	spawn_projectile.damage_type = damage_type
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.15)
	apply_effects_on_projectile(spawn_projectile)
	get_tree().root.call_deferred("add_child", spawn_projectile)
