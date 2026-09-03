extends Ranger

# Projectile
@onready var beam_blast = preload("res://Player/Weapons/Projectiles/beam_blast.tscn")

# Weapon
var ITEM_NAME = "Charged Blaster"
var hit_cd : float
var duration : float
var beam_range : float = 450.0
var beam_local_forward := Vector2.UP
@export_range(0.05, 1.0, 0.01) var firing_rotation_slow_multiplier: float = 0.1
@export_range(0.05, 1.0, 0.01) var firing_move_speed_multiplier: float = 0.75
@export_range(0.1, 1.0, 0.05) var minimum_committed_fire_sec: float = 0.35
@export var resonance_initial_damage_multiplier: float = 1.55
@export var resonance_ramp_per_repeat_hit: float = 0.14
@export var resonance_max_ramp_hits: int = 5
var is_firing_beam := false
var firing_turn_timer: Timer
var _feedback_refund_accum_sec: float = 0.0
var weapon_data = {
	"1": {"damage": "6", "hit_cd": "0.2", "fire_interval_sec": "4", "ammo": "3", "duration": "1.0"},
	"2": {"damage": "8", "hit_cd": "0.2", "fire_interval_sec": "4", "ammo": "3", "duration": "1.2"},
	"3": {"damage": "10", "hit_cd": "0.2", "fire_interval_sec": "4", "ammo": "3", "duration": "1.2"},
	"4": {"damage": "12", "hit_cd": "0.2", "fire_interval_sec": "3.6", "ammo": "3", "duration": "1.4"},
	"5": {"damage": "14", "hit_cd": "0.2", "fire_interval_sec": "3.6", "ammo": "3", "duration": "1.4"},
	"6": {"damage": "16", "hit_cd": "0.2", "fire_interval_sec": "3.6", "ammo": "3", "duration": "1.6"},
	"7": {"damage": "18", "hit_cd": "0.2", "fire_interval_sec": "3.3", "ammo": "3", "duration": "1.6"},
	"8": {"damage": "20", "hit_cd": "0.2", "fire_interval_sec": "3.3", "ammo": "3", "duration": "1.8"},
	"9": {"damage": "22", "hit_cd": "0.2", "fire_interval_sec": "3.3", "ammo": "3", "duration": "1.8"}
}


func _physics_process(delta):
	super._physics_process(delta)

func _update_weapon_rotation(delta: float = -1.0) -> void:
	var step_delta := get_physics_process_delta_time() if delta < 0.0 else delta
	var speed_multiplier := firing_rotation_slow_multiplier if is_firing_beam else 1.0
	speed_multiplier *= _get_charged_turn_speed_multiplier()
	turn_toward_world_position(get_mouse_target(), step_delta, speed_multiplier)
	beam_local_forward = get_aim_forward()

func set_level(lv):
	lv = str(lv)
	var level_data := get_weapon_level_data(lv, weapon_data)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	hit_cd = float(level_data["hit_cd"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	duration = float(level_data["duration"])
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)

func _on_shoot():
	if is_on_cooldown:
		return
	is_on_cooldown = true
	_feedback_refund_accum_sec = 0.0
	beam_local_forward = get_aim_forward()
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
	if is_energy_release_attack_active():
		base_profile["target_lock_mode"] = "first_hit"
		base_profile["energy_resonance"] = true
	var beam_profiles := _get_charged_beam_profiles(base_profile)
	var max_beam_duration: float = 0.0
	for profile in beam_profiles:
		max_beam_duration = maxf(max_beam_duration, _spawn_beam_from_profile(profile))
	if max_beam_duration > 0.0:
		_start_firing_turn_slowdown(max_beam_duration)
	start_weapon_cooldown(0.05)

func _on_remove_timer_timeout() -> void:
	remove_weapon()

func _on_charged_blast_timer_timeout() -> void:
	is_on_cooldown = false


func _start_firing_turn_slowdown(active_duration: float) -> void:
	is_firing_beam = true
	_apply_firing_move_slowdown()
	if firing_turn_timer == null:
		firing_turn_timer = Timer.new()
		firing_turn_timer.one_shot = true
		firing_turn_timer.timeout.connect(_on_firing_turn_timeout)
		add_child(firing_turn_timer)
	firing_turn_timer.wait_time = max(active_duration, 0.01)
	firing_turn_timer.start()


func _on_firing_turn_timeout() -> void:
	is_firing_beam = false
	_remove_firing_move_slowdown()

func _apply_firing_move_slowdown() -> void:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("apply_move_speed_mul"):
		player.call("apply_move_speed_mul", _get_firing_move_slow_source_id(), clampf(firing_move_speed_multiplier, 0.05, 1.0))

func _remove_firing_move_slowdown() -> void:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("remove_move_speed_mul"):
		player.call("remove_move_speed_mul", _get_firing_move_slow_source_id())

func _get_firing_move_slow_source_id() -> StringName:
	return StringName("charged_blaster_firing_%s" % str(get_instance_id()))

func _exit_tree() -> void:
	_remove_firing_move_slowdown()

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	if not can_run_active_behavior():
		return
	if not pressed:
		return
	request_primary_fire()

func on_beam_hit_target(target: Node, beam_profile: Dictionary = {}, hit_damage: int = 0, beam_node: Node = null) -> void:
	_update_energy_resonance_ramp(target, beam_profile, beam_node)
	for behavior in branch_runtime.get_branch_behaviors():
		behavior.on_charged_beam_hit(target, beam_profile, hit_damage)

func get_energy_full_fire_passive_id() -> StringName:
	return &"charged_blaster_multi_hit_triggered"

func get_energy_full_fire_display_name() -> String:
	return "Beam Resonance"

func get_energy_gain_per_damage_event() -> float:
	return 3.0

func get_energy_release_bonus_at_full() -> float:
	return maxf(resonance_initial_damage_multiplier - 1.0, 0.0)

func get_passive_status() -> Dictionary:
	return get_energy_full_fire_status()

func get_passive_max_charges() -> int:
	return 3

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
	var multiplier := 1.0
	for behavior in branch_runtime.get_branch_behaviors():
		multiplier *= maxf(behavior.get_charged_turn_speed_multiplier(), 0.05)
	return maxf(multiplier, 0.05)

func _get_charged_beam_profiles(base_profile: Dictionary) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = [base_profile]
	for behavior in branch_runtime.get_branch_behaviors():
		var next_profiles: Array[Dictionary] = []
		for profile in profiles:
			var branch_profiles := behavior.get_charged_beam_profiles(profile)
			if branch_profiles.is_empty():
				next_profiles.append(profile)
			else:
				next_profiles.append_array(branch_profiles)
		profiles = next_profiles
	return profiles

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
	# A charged shot is committed long enough to preserve its deliberate placement
	# cost even if a future branch supplies an unusually short duration multiplier.
	var beam_duration: float = maxf(duration * duration_multiplier, minimum_committed_fire_sec)
	var beam_hit_cd: float = maxf(hit_cd * hit_cd_multiplier, 0.01)
	var base_beam_width: float = 6.0 if fixed_width_no_charge else _get_full_power_beam_width()
	beam_blast_ins.target_position = dir * beam_range * range_multiplier
	beam_blast_ins.width = maxf(base_beam_width * width_multiplier, 1.0)
	var runtime_damage := get_runtime_damage()
	beam_blast_ins.damage = max(1, int(round(float(runtime_damage) * damage_multiplier)))
	beam_blast_ins.duration = beam_duration
	beam_blast_ins.hit_cd = beam_hit_cd
	beam_blast_ins.source_weapon = self
	apply_energy_release_marker(beam_blast_ins)
	apply_heat_snapshot_marker(beam_blast_ins)
	beam_blast_ins.beam_profile = profile.duplicate(true)
	beam_blast_ins.target_lock_mode = StringName(str(profile.get("target_lock_mode", "none")))
	beam_blast_ins.target_lock_release_multiplier = maxf(float(profile.get("target_lock_release_multiplier", 1.8)), 1.0)
	if bool(profile.get("energy_resonance", false)):
		var initial_multiplier := maxf(resonance_initial_damage_multiplier, 1.0)
		var unboosted_damage := float(runtime_damage) / initial_multiplier
		beam_blast_ins.set_meta(&"_energy_resonance_base_damage", beam_blast_ins.damage)
		beam_blast_ins.set_meta(
			&"_energy_resonance_step_damage",
			maxf(unboosted_damage * maxf(resonance_ramp_per_repeat_hit, 0.0) * damage_multiplier, 0.0)
		)
		beam_blast_ins.set_meta(&"_energy_resonance_hit_count", 0)
		beam_blast_ins.set_meta(&"_energy_resonance_target_id", 0)
	beam_blast_ins.global_position = global_position
	get_projectile_spawn_parent().call_deferred("add_child", beam_blast_ins)
	return beam_duration

func _update_energy_resonance_ramp(target: Node, profile: Dictionary, beam_node: Node) -> void:
	if not bool(profile.get("energy_resonance", false)):
		return
	if target == null or not is_instance_valid(target) or beam_node == null or not is_instance_valid(beam_node):
		return
	var target_id := target.get_instance_id()
	var previous_target_id := int(beam_node.get_meta(&"_energy_resonance_target_id", 0))
	var hit_count := int(beam_node.get_meta(&"_energy_resonance_hit_count", 0))
	if previous_target_id != target_id:
		hit_count = 0
	hit_count = mini(hit_count + 1, maxi(resonance_max_ramp_hits, 0))
	beam_node.set_meta(&"_energy_resonance_target_id", target_id)
	beam_node.set_meta(&"_energy_resonance_hit_count", hit_count)
	var base_value := float(beam_node.get_meta(&"_energy_resonance_base_damage", beam_node.get("damage")))
	var step_value := float(beam_node.get_meta(&"_energy_resonance_step_damage", 0.0))
	beam_node.set("damage", max(1, int(round(base_value + step_value * float(hit_count)))))

func _get_full_power_beam_width() -> float:
	if level >= 6:
		return 24.0
	if level >= 3:
		return 18.0
	return 12.0
