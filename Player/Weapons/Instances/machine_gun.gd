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
	Vector2(10.0, 2.0),
	Vector2(20.0, 4.0),
	Vector2(40.0, 6.0),
	Vector2(50.0, 8.0),
]

@export var heat_accumulation: float = 4
@export var heat_accumulation_per_sec: float = 25.0
@export var max_heat: float = 50.0
@export var heat_cooldown_rate: float = 20.0
@export_range(5.0, 80.0, 1.0) var front_fire_half_angle_deg: float = 35.0
@export var heat_expansion_duration_sec: float = 8.0
@export var heat_expansion_max_heat_multiplier: float = 2.0
var attack_range: float = 800.0

var weapon_data = {
	"1": {"damage": "6", "speed": "600", "projectile_hits": "1", "fire_interval_sec": "1", "ammo": "40"},
	"2": {"damage": "8", "speed": "600", "projectile_hits": "1", "fire_interval_sec": "1", "ammo": "40"},
	"3": {"damage": "10", "speed": "600", "projectile_hits": "1", "fire_interval_sec": "1", "ammo": "40"},
	"4": {"damage": "11", "speed": "800", "projectile_hits": "1", "fire_interval_sec": "0.9", "ammo": "45"},
	"5": {"damage": "13", "speed": "800", "projectile_hits": "1", "fire_interval_sec": "0.9", "ammo": "45"},
	"6": {"damage": "15", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.9", "ammo": "45"},
	"7": {"damage": "16", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.82", "ammo": "50"},
	"8": {"damage": "18", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.82", "ammo": "50"},
	"9": {"damage": "20", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.82", "ammo": "50"}
}

func _ready() -> void:
	super._ready()

func set_level(lv):
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)

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
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()
	var target_position: Vector2 = get_mouse_target()
	var base_direction: Vector2 = global_position.direction_to(target_position).normalized()
	var shot_directions: Array[Vector2] = [base_direction]
	shot_directions = branch_runtime.get_branch_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]
	var fired_count := 0
	for dir in shot_directions:
		var spreaded := apply_distance_spread_to_target(dir.normalized(), target_position)
		var constrained := _constrain_to_forward_cone(spreaded, base_direction)
		_fire_single_bullet(constrained)
		fired_count += 1
	branch_runtime.notify_branch_weapon_shot(base_direction)
	var extra_heat_multiplier := branch_runtime.get_branch_extra_heat_shot_multiplier()
	var extra_heat_shots := float(max(0, fired_count - 1)) * clampf(extra_heat_multiplier, 0.0, 1.0)
	if extra_heat_shots > 0.0:
		register_shot_heat(extra_heat_shots)

func supports_multi_launcher_module() -> bool:
	return true

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
	var duration_sec := maxf(heat_expansion_duration_sec, 0.05)
	var max_heat_mul := lerpf(1.0, maxf(heat_expansion_max_heat_multiplier, 1.0), spent_ratio)
	notify_offhand_skill_triggered(0.0)
	var scaled_current_heat := false
	if PlayerData.player and is_instance_valid(PlayerData.player):
		scaled_current_heat = bool(PlayerData.player.call("apply_heat_expansion", duration_sec, max_heat_mul))
	emit_passive_trigger(&"machine_gun_heat_expansion", {
		"trigger": "reload_started",
		"spent_ratio": spent_ratio,
		"duration": duration_sec,
		"cooldown": 0.0,
		"max_heat_multiplier": max_heat_mul,
		"scaled_current_heat": scaled_current_heat,
		"target_weapon": null,
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var effective_capacity := get_effective_magazine_capacity()
	var spent: int = max(0, effective_capacity - current_ammo)
	var progress: float = clampf(float(spent) / float(effective_capacity), 0.0, 1.0)
	var state := "charging"
	if not is_main_weapon():
		state = "inactive"
	elif not is_passive_ready():
		state = "waiting_refresh"
	elif spent > 0:
		state = "ready_pending_action"
	return {
		"id": "machine_gun_heat_expansion",
		"display_name": "Heat Expansion",
		"state": state,
		"progress": progress,
		"current": spent,
		"required": get_effective_magazine_capacity(),
		"ready": state == "ready_pending_action",
		"trigger_hint": "reload_started",
		"refresh_hint": "reload_finished",
	}

func _get_level_data(lv: String) -> Dictionary:
	return get_weapon_level_data(lv, weapon_data)

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
	var damage_multiplier: float = branch_runtime.get_branch_projectile_damage_multiplier()
	var final_damage: int = max(1, int(round(float(runtime_damage) * maxf(damage_multiplier, 0.05))))
	spawn_projectile.damage = final_damage
	var damage_type: StringName = branch_runtime.get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	spawn_projectile.damage_type = damage_type
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.15)
	apply_effects_on_projectile(spawn_projectile)
	get_tree().root.call_deferred("add_child", spawn_projectile)
