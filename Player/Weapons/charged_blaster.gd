extends Ranger

# Projectile
@onready var beam_blast = preload("res://Player/Weapons/Projectiles/beam_blast.tscn")

# Weapon
var ITEM_NAME = "Charged Blaster"
var hit_cd : float
var duration : float
var beam_range : float = 450.0
var beam_local_forward := Vector2.UP
var normal_turn_speed := 12.0
@export_range(0.05, 1.0, 0.01) var firing_rotation_slow_multiplier: float = 0.1
var is_firing_beam := false
var firing_turn_timer: Timer
var _force_active_cast: bool = false
var _feedback_refund_accum_sec: float = 0.0

var weapon_data = {
	"1": {
		"level": "1",
		"damage": "6",
		"hit_cd": "0.2",
		"fire_interval_sec": "4",
		"ammo": "10",
		"duration": "1.0",
		"cost": "9",
	},
	"2": {
		"level": "2",
		"damage": "8",
		"hit_cd": "0.2",
		"fire_interval_sec": "4",
		"ammo": "10",
		"duration": "1.2",
		"cost": "9",
	},
	"3": {
		"level": "3",
		"damage": "12",
		"hit_cd": "0.2",
		"fire_interval_sec": "4",
		"ammo": "12",
		"duration": "1.2",
		"cost": "9",
	},
	"4": {
		"level": "4",
		"damage": "15",
		"hit_cd": "0.2",
		"fire_interval_sec": "4",
		"ammo": "12",
		"duration": "1.4",
		"cost": "9",
	},
	"5": {
		"level": "5",
		"damage": "18",
		"hit_cd": "0.2",
		"fire_interval_sec": "4",
		"ammo": "14",
		"duration": "1.6",
		"cost": "9",
	},
	"6": {
		"level": "6",
		"damage": "28",
		"hit_cd": "0.2",
		"fire_interval_sec": "4",
		"ammo": "14",
		"duration": "1.8",
		"cost": "9",
	},
	"7": {
		"level": "7",
		"damage": "32",
		"hit_cd": "0.2",
		"fire_interval_sec": "4",
		"ammo": "16",
		"duration": "2.0",
		"cost": "9",
	},
}


func _physics_process(delta):
	super._physics_process(delta)
	_update_smoothed_rotation(delta)

# Charged Blaster drives its own smoothed rotation, so skip Ranger's instant snap-to-mouse rotation.
func _update_weapon_rotation() -> void:
	pass

func set_level(lv):
	lv = str(lv)
	level = int(weapon_data[lv]["level"])
	base_damage = int(weapon_data[lv]["damage"])
	hit_cd = float(weapon_data[lv]["hit_cd"])

	base_attack_cooldown = float(weapon_data[lv]["fire_interval_sec"])
	apply_level_ammo(weapon_data[lv])
	duration = float(weapon_data[lv]["duration"])
	sync_stats()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)

func _on_shoot():
	if is_on_cooldown and not _force_active_cast:
		return
	is_on_cooldown = true
	_feedback_refund_accum_sec = 0.0
	var base_profile := {
		"direction": beam_local_forward.normalized(),
		"range_multiplier": 1.0,
		"width_multiplier": 1.0,
		"damage_multiplier": 1.0,
		"duration_multiplier": 1.0,
		"angle_offset_deg": 0.0,
		"target_lock_mode": "none",
		"target_lock_release_multiplier": 1.8,
		"beam_tag": "main",
	}
	var beam_profiles := _get_charged_beam_profiles(base_profile)
	var max_beam_duration: float = 0.0
	for profile in beam_profiles:
		max_beam_duration = maxf(max_beam_duration, _spawn_beam_from_profile(profile))
	if max_beam_duration > 0.0:
		_start_firing_turn_slowdown(max_beam_duration)
	start_weapon_cooldown(attack_cooldown, 0.05)

func _on_remove_timer_timeout() -> void:
	remove_weapon()

func _on_charged_blast_timer_timeout() -> void:
	is_on_cooldown = false


func _update_smoothed_rotation(delta: float) -> void:
	var mouse_direction := get_global_mouse_position() - global_position
	if mouse_direction == Vector2.ZERO:
		return
	var target_rotation := mouse_direction.angle() + AIM_ROTATION_OFFSET
	var firing_turn_speed := normal_turn_speed * clampf(firing_rotation_slow_multiplier, 0.05, 1.0)
	var turn_speed := firing_turn_speed if is_firing_beam else normal_turn_speed
	turn_speed *= _get_charged_turn_speed_multiplier()
	rotation = lerp_angle(rotation, target_rotation, clamp(turn_speed * delta, 0.0, 1.0))


func _start_firing_turn_slowdown(active_duration: float) -> void:
	is_firing_beam = true
	if firing_turn_timer == null:
		firing_turn_timer = Timer.new()
		firing_turn_timer.one_shot = true
		firing_turn_timer.timeout.connect(_on_firing_turn_timeout)
		add_child(firing_turn_timer)
	firing_turn_timer.wait_time = max(active_duration, 0.01)
	firing_turn_timer.start()


func _on_firing_turn_timeout() -> void:
	is_firing_beam = false

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	if not can_run_active_behavior():
		return
	if not pressed:
		return
	request_primary_fire()

func _execute_weapon_active(damage_multiplier: float) -> bool:
	if not can_run_active_behavior():
		return false
	_force_active_cast = true
	emit_signal("shoot")
	_force_active_cast = false
	if is_on_cooldown and damage_multiplier > 1.0:
		_apply_weapon_active_multiplier_buff(damage_multiplier)
	return is_on_cooldown

func on_beam_hit_target(target: Node, beam_profile: Dictionary = {}, hit_damage: int = 0) -> void:
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_charged_beam_hit(target, beam_profile, hit_damage)

func reduce_cooldown_remaining(seconds: float) -> float:
	if seconds <= 0.0:
		return 0.0
	if not is_on_cooldown:
		return 0.0
	if cooldown_timer == null:
		return 0.0
	var time_left: float = cooldown_timer.time_left
	if time_left <= 0.0:
		return 0.0
	var reduced: float = minf(maxf(seconds, 0.0), time_left)
	var next_time_left: float = maxf(time_left - reduced, 0.0)
	if next_time_left <= 0.0:
		cooldown_timer.stop()
		is_on_cooldown = false
	else:
		cooldown_timer.start(next_time_left)
	return reduced

func get_feedback_refund_accum_sec() -> float:
	return _feedback_refund_accum_sec

func add_feedback_refund_accum_sec(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_feedback_refund_accum_sec += seconds

func _get_charged_turn_speed_multiplier() -> float:
	if branch_behavior and is_instance_valid(branch_behavior):
		return maxf(branch_behavior.get_charged_turn_speed_multiplier(), 0.05)
	return 1.0

func _get_charged_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	if branch_behavior and is_instance_valid(branch_behavior):
		return branch_behavior.get_charged_beam_profiles(base_profile)
	return [base_profile]

func _spawn_beam_from_profile(profile: Dictionary) -> float:
	var beam_blast_ins = beam_blast.instantiate()
	if beam_blast_ins == null:
		return 0.0
	var dir: Vector2 = beam_local_forward.normalized()
	var angle_offset_deg: float = float(profile.get("angle_offset_deg", 0.0))
	if angle_offset_deg != 0.0:
		dir = dir.rotated(deg_to_rad(angle_offset_deg))
	var range_multiplier: float = maxf(float(profile.get("range_multiplier", 1.0)), 0.1)
	var width_multiplier: float = maxf(float(profile.get("width_multiplier", 1.0)), 0.1)
	var damage_multiplier: float = maxf(float(profile.get("damage_multiplier", 1.0)), 0.05)
	var hit_cd_multiplier: float = maxf(float(profile.get("hit_cd_multiplier", 1.0)), 0.05)
	var duration_multiplier: float = maxf(float(profile.get("duration_multiplier", 1.0)), 0.05)
	var fixed_width_no_charge: bool = bool(profile.get("fixed_width_no_charge", false))
	var beam_duration: float = maxf(duration * duration_multiplier, 0.05)
	var beam_hit_cd: float = maxf(hit_cd * hit_cd_multiplier, 0.01)
	var base_beam_width: float = 6.0 if fixed_width_no_charge else _get_full_power_beam_width()
	beam_blast_ins.target_position = dir * beam_range * range_multiplier
	beam_blast_ins.width = maxf(base_beam_width * width_multiplier, 1.0)
	beam_blast_ins.damage = max(1, int(round(float(get_runtime_shot_damage()) * damage_multiplier)))
	beam_blast_ins.duration = beam_duration
	beam_blast_ins.hit_cd = beam_hit_cd
	beam_blast_ins.source_weapon = self
	beam_blast_ins.beam_profile = profile.duplicate(true)
	beam_blast_ins.target_lock_mode = StringName(str(profile.get("target_lock_mode", "none")))
	beam_blast_ins.target_lock_release_multiplier = maxf(float(profile.get("target_lock_release_multiplier", 1.8)), 1.0)
	call_deferred("add_child", beam_blast_ins)
	return beam_duration

func _get_full_power_beam_width() -> float:
	if level >= 6:
		return 24.0
	if level >= 3:
		return 18.0
	return 12.0
