extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/weapons/projectiles/plasma.png")

# Weapon
var ITEM_NAME = "Machine Gun"
var attack_speed : float = 1.0
@export var attack_speed_decay_interval: float = 0.35

var max_speed_factor : float = 5.0
var as_timer: Timer

const BULLET_PIXEL_SIZE := Vector2(10.0, 10.0)

@export var heat_accumulation: float = 3
@export var max_heat: float = 100.0
@export var heat_cooldown_rate: float = 20.0
@export_range(5.0, 80.0, 1.0) var front_fire_half_angle_deg: float = 35.0
@export var offhand_trigger_window_sec: float = 2.0
@export var offhand_trigger_hits: int = 10
@export var offhand_buff_duration_sec: float = 12.0
@export var offhand_main_attack_speed_mult: float = 125.5
@export var offhand_main_spread_mult: float = 0.5
var attack_range: float = 800.0
var _offhand_hit_timestamps_msec: Array[int] = []
var _offhand_buff_expires_at_msec: int = 0
var _offhand_buff_target: Weapon = null

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "5",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "70",
		"cost": "4",
	},
	"2": {
		"level": "2",
		"damage": "6",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "75",
		"cost": "4",
	},
	"3": {
		"level": "3",
		"damage": "7",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "80",
		"cost": "4",
	},
	"4": {
		"level": "4",
		"damage": "9",
		"speed": "800",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "85",
		"cost": "4",
	},
	"5": {
		"level": "5",
		"damage": "11",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "1.0",
		"ammo": "90",
		"cost": "4",
	},
	"6": {
		"level": "6",
		"damage": "13",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "1.0",
		"ammo": "95",
		"cost": "4",
	},
	"7": {
		"level": "7",
		"damage": "15",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "1.0",
		"ammo": "100",
		"cost": "4",
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

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
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
	var shot_directions: Array[Vector2] = [base_direction]
	if branch_behavior and is_instance_valid(branch_behavior):
		shot_directions = branch_behavior.get_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]
	var fired_count := 0
	for dir in shot_directions:
		var spreaded := apply_distance_spread_to_target(dir.normalized(), target_position)
		var constrained := _constrain_to_forward_cone(spreaded, base_direction)
		_fire_single_bullet(constrained)
		fired_count += 1
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_weapon_shot(base_direction)
	var extra_heat_multiplier := 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		extra_heat_multiplier = branch_behavior.get_extra_heat_shot_multiplier()
	var extra_heat_shots := float(max(0, fired_count - 1)) * clampf(extra_heat_multiplier, 0.0, 1.0)
	register_shot_heat(extra_heat_shots)
	adjust_attack_speed(1.2)

func adjust_attack_speed(rate : float) -> void:
	attack_speed = clampf(attack_speed * rate, 1.0, max_speed_factor)


func _on_as_timer_timeout() -> void:
	if not is_on_cooldown:
		adjust_attack_speed(0.8)

func _process_main_weapon_effect(_delta: float) -> void:
	_update_offhand_focus_runtime()

func _process_offhand_weapon_effect(_delta: float) -> void:
	_update_offhand_focus_runtime()

func _update_offhand_focus_runtime() -> void:
	var now_msec := Time.get_ticks_msec()
	if _offhand_buff_expires_at_msec <= 0:
		return
	if now_msec >= _offhand_buff_expires_at_msec:
		_clear_offhand_main_focus_buff()
		return
	_sync_offhand_main_focus_buff_target()

func _on_offhand_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_offhand_passive_event(event_name, detail)
	if event_name != &"on_hit":
		return
	if not bool(detail.get("source_is_main", false)):
		return
	var source_variant: Variant = detail.get("source_weapon", null)
	var source_weapon := source_variant as Weapon
	if source_weapon == null or not is_instance_valid(source_weapon):
		return
	var current_main := _resolve_current_main_weapon_for_offhand()
	if current_main == null or source_weapon != current_main:
		return
	var now_msec := Time.get_ticks_msec()
	_cleanup_offhand_hit_window(now_msec)
	if not is_offhand_skill_ready():
		return
	_offhand_hit_timestamps_msec.append(now_msec)
	_cleanup_offhand_hit_window(now_msec)
	if _offhand_hit_timestamps_msec.size() < max(1, offhand_trigger_hits):
		return
	_offhand_hit_timestamps_msec.clear()
	var buff_duration_sec := maxf(offhand_buff_duration_sec, 0.05)
	notify_offhand_skill_triggered(0.0)
	_offhand_buff_expires_at_msec = now_msec + int(buff_duration_sec * 1000.0)
	_sync_offhand_main_focus_buff_target()
	var spread_applied := _offhand_buff_target != null and is_instance_valid(_offhand_buff_target)
	passive_triggered.emit(&"offhand_machine_gun_focus_buff", {
		"trigger_hits": max(1, offhand_trigger_hits),
		"trigger_window": maxf(offhand_trigger_window_sec, 0.1),
		"duration": buff_duration_sec,
		"cooldown": 0.0,
		"attack_speed_multiplier": maxf(offhand_main_attack_speed_mult, 0.1),
		"spread_multiplier": maxf(offhand_main_spread_mult, 0.01),
		"spread_applied": spread_applied,
		"target_weapon": _offhand_buff_target,
	})

func _on_enter_main_weapon_role() -> void:
	_offhand_hit_timestamps_msec.clear()

func _on_tree_exiting() -> void:
	_clear_offhand_main_focus_buff()
	_offhand_hit_timestamps_msec.clear()

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
		"fire_interval_sec": "2",
		"ammo": "70",
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

func _resolve_current_main_weapon_for_offhand() -> Weapon:
	if PlayerData.player_weapon_list.is_empty():
		return null
	PlayerData.sanitize_main_weapon_index()
	var idx := PlayerData.main_weapon_index
	if idx < 0 or idx >= PlayerData.player_weapon_list.size():
		return null
	var weapon_variant: Variant = PlayerData.player_weapon_list[idx]
	var weapon := weapon_variant as Weapon
	if weapon == null or not is_instance_valid(weapon) or weapon == self:
		return null
	return weapon

func _cleanup_offhand_hit_window(now_msec: int) -> void:
	var window_msec := int(maxf(offhand_trigger_window_sec, 0.1) * 1000.0)
	while not _offhand_hit_timestamps_msec.is_empty():
		var oldest := _offhand_hit_timestamps_msec[0]
		if now_msec - oldest <= window_msec:
			break
		_offhand_hit_timestamps_msec.remove_at(0)

func _apply_offhand_main_focus_buff(target_weapon: Weapon) -> bool:
	if target_weapon == null or not is_instance_valid(target_weapon):
		return false
	if target_weapon.has_method("set_external_attack_speed_multiplier"):
		target_weapon.call("set_external_attack_speed_multiplier", maxf(offhand_main_attack_speed_mult, 0.1))
	var spread_applied := false
	if target_weapon.has_method("set_external_spread_multiplier"):
		target_weapon.call("set_external_spread_multiplier", maxf(offhand_main_spread_mult, 0.01))
		spread_applied = true
	return spread_applied

func _sync_offhand_main_focus_buff_target() -> void:
	var current_main := _resolve_current_main_weapon_for_buff_sync()
	if current_main == null:
		_clear_offhand_main_focus_buff()
		return
	if _offhand_buff_target != current_main:
		_clear_offhand_main_focus_buff_effect_only()
		_offhand_buff_target = current_main
	_apply_offhand_main_focus_buff(current_main)

func _resolve_current_main_weapon_for_buff_sync() -> Weapon:
	if PlayerData.player_weapon_list.is_empty():
		return null
	PlayerData.sanitize_main_weapon_index()
	var idx := PlayerData.main_weapon_index
	if idx < 0 or idx >= PlayerData.player_weapon_list.size():
		return null
	var weapon_variant: Variant = PlayerData.player_weapon_list[idx]
	var weapon := weapon_variant as Weapon
	if weapon == null or not is_instance_valid(weapon):
		return null
	return weapon

func _clear_offhand_main_focus_buff() -> void:
	_clear_offhand_main_focus_buff_effect_only()
	_offhand_buff_expires_at_msec = 0

func _clear_offhand_main_focus_buff_effect_only() -> void:
	if _offhand_buff_target != null and is_instance_valid(_offhand_buff_target):
		if _offhand_buff_target.has_method("set_external_attack_speed_multiplier"):
			_offhand_buff_target.call("set_external_attack_speed_multiplier", 1.0)
		if _offhand_buff_target.has_method("set_external_spread_multiplier"):
			_offhand_buff_target.call("set_external_spread_multiplier", 1.0)
	_offhand_buff_target = null

func _fire_single_bullet(direction: Vector2) -> void:
	projectile_direction = direction
	var spawn_projectile = spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return
	var runtime_damage: int = int(get_runtime_shot_damage())
	var damage_multiplier: float = 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_multiplier = branch_behavior.get_projectile_damage_multiplier()
	var final_damage: int = max(1, int(round(float(runtime_damage) * maxf(damage_multiplier, 0.05))))
	spawn_projectile.damage = final_damage
	var damage_type: StringName = Attack.TYPE_PHYSICAL
	if branch_behavior and is_instance_valid(branch_behavior):
		damage_type = Attack.normalize_damage_type(branch_behavior.get_damage_type_override())
	spawn_projectile.damage_type = damage_type
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.desired_pixel_size = BULLET_PIXEL_SIZE
	spawn_projectile.size = size
	spawn_projectile.expire_time = maxf(attack_range / maxf(float(speed), 1.0), 0.15)
	apply_effects_on_projectile(spawn_projectile)
	get_tree().root.call_deferred("add_child", spawn_projectile)
