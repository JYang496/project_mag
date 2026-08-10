extends Ranger

# Projectile
@onready var beam = preload("res://Player/Weapons/Projectiles/beam.tscn")

@onready var detect_area: Area2D = $DetectArea
@onready var oc_timer: Timer = $OCTimer

# Weapon
var ITEM_NAME = "Laser"
const PASSIVE_ID: StringName = &"laser_focus_channel_triggered"
@export var focus_channel_duration_sec: float = 2.5
@export var focus_channel_damage_multiplier: float = 1.30
@export var focus_channel_width_multiplier: float = 1.35
var _focus_channel_remaining_sec: float = 0.0
var _focus_channel_energy_per_sec: float = 0.0

var weapon_data = {
	"1": {"damage": "3", "fire_interval_sec": "2", "ammo": "5"},
	"2": {"damage": "3", "fire_interval_sec": "1.7", "ammo": "6"},
	"3": {"damage": "3", "fire_interval_sec": "1.5", "ammo": "7"},
	"4": {"damage": "4", "fire_interval_sec": "1.4", "ammo": "7"},
	"5": {"damage": "4", "fire_interval_sec": "1.3", "ammo": "8"},
	"6": {"damage": "4", "fire_interval_sec": "1.2", "ammo": "9"},
	"7": {"damage": "6", "fire_interval_sec": "1.0", "ammo": "10"},
	"8": {"damage": "6", "fire_interval_sec": "0.9", "ammo": "11"},
	"9": {"damage": "6", "fire_interval_sec": "0.85", "ammo": "12"}
}


func set_level(lv):
	lv = str(lv)
	var level_data := get_weapon_level_data(lv, weapon_data)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_focus_channel(delta)

func _on_shoot():
	fire_laser_toward(get_aim_forward())
	is_on_cooldown = true
	cooldown_timer.start()

func fire_laser_toward(target_offset: Vector2) -> void:
	var profiles := build_laser_beam_profiles(target_offset)
	for profile in profiles:
		_spawn_laser_beam(profile)
	branch_runtime.notify_branch_weapon_shot(target_offset.normalized())

func build_laser_beam_profiles(target_offset: Vector2) -> Array[Dictionary]:
	var base_direction := target_offset.normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT
	var base_profile := {
		"direction": base_direction,
		"damage_multiplier": 1.0,
		"width_multiplier": focus_channel_width_multiplier if _is_focus_channel_active() else 1.0,
		"angle_offset_deg": 0.0,
		"beam_tag": "main",
	}
	var profiles: Array[Dictionary] = [base_profile]
	for behavior in branch_runtime.get_branch_behaviors():
		var next_profiles: Array[Dictionary] = []
		for profile in profiles:
			var branch_profiles := behavior.get_laser_beam_profiles(profile)
			if branch_profiles.is_empty():
				next_profiles.append(profile)
			else:
				next_profiles.append_array(branch_profiles)
		profiles = next_profiles
	for behavior in branch_runtime.get_branch_behaviors():
		var next_profiles: Array[Dictionary] = []
		for profile in profiles:
			next_profiles.append(behavior.apply_laser_tracking_to_profile(profile))
		profiles = next_profiles
	return profiles

func _spawn_laser_beam(profile: Dictionary) -> void:
	var beam_ins = beam.instantiate()
	beam_ins.global_position = self.global_position
	var direction: Vector2 = profile.get("direction", Vector2.RIGHT)
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var angle_offset := deg_to_rad(float(profile.get("angle_offset_deg", 0.0)))
	direction = direction.rotated(angle_offset).normalized()
	beam_ins.target_position = direction * 1000.0
	var damage_multiplier := maxf(float(profile.get("damage_multiplier", 1.0)), 0.05)
	beam_ins.damage = max(1, int(round(float(get_runtime_shot_damage()) * damage_multiplier)))
	beam_ins.source_weapon = self
	apply_energy_release_marker(beam_ins)
	apply_heat_snapshot_marker(beam_ins)
	if beam_ins.has_method("configure_laser_beam"):
		beam_ins.call("configure_laser_beam", profile)
	self.get_tree().root.call_deferred("add_child",beam_ins)


func _on_oc_timer_timeout() -> void:
	remove_weapon()

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)

func get_energy_full_fire_passive_id() -> StringName:
	return PASSIVE_ID

func get_energy_full_fire_display_name() -> String:
	return "Focus Channel"

func get_passive_status() -> Dictionary:
	var status := get_energy_full_fire_status()
	if _is_focus_channel_active():
		status["state"] = "active"
		status["ready"] = false
		status["active_remaining_sec"] = _focus_channel_remaining_sec
		status["active_duration_sec"] = maxf(focus_channel_duration_sec, 0.1)
		status["release_mode"] = &"focus_channel"
	return status

func get_energy_release_bonus_at_full() -> float:
	return maxf(focus_channel_damage_multiplier - 1.0, 0.0)

func _prepare_special_energy_release_attack(
	_player: Node,
	current_energy: float,
	max_energy: float
) -> Dictionary:
	if _is_focus_channel_active() and current_energy > 0.001:
		return activate_energy_release_attack(0.0, focus_channel_damage_multiplier, {
			"release_mode": &"focus_channel",
			"focus_remaining_sec": _focus_channel_remaining_sec,
		})
	if current_energy < max_energy - 0.001:
		return {}
	_focus_channel_remaining_sec = maxf(focus_channel_duration_sec, 0.1)
	_focus_channel_energy_per_sec = max_energy / _focus_channel_remaining_sec
	return activate_energy_release_attack(0.0, focus_channel_damage_multiplier, {
		"release_mode": &"focus_channel",
		"focus_duration_sec": _focus_channel_remaining_sec,
	})

func _update_focus_channel(delta: float) -> void:
	if not _is_focus_channel_active():
		return
	var player := _resolve_energy_pool_player()
	if player == null or not is_instance_valid(player) \
			or not player.has_method("consume_global_weapon_energy") \
			or not player.has_method("get_global_weapon_energy"):
		_end_focus_channel()
		return
	var safe_delta := maxf(delta, 0.0)
	var remaining_before := maxf(float(player.call("get_global_weapon_energy")), 0.0)
	var requested := minf(_focus_channel_energy_per_sec * safe_delta, remaining_before)
	if requested > 0.0:
		player.call("consume_global_weapon_energy", requested)
	_focus_channel_remaining_sec = maxf(_focus_channel_remaining_sec - safe_delta, 0.0)
	var remaining_energy := maxf(float(player.call("get_global_weapon_energy")), 0.0)
	if _focus_channel_remaining_sec <= 0.0 or remaining_energy <= 0.001:
		_end_focus_channel()

func _is_focus_channel_active() -> bool:
	return _focus_channel_remaining_sec > 0.0

func _end_focus_channel() -> void:
	_focus_channel_remaining_sec = 0.0
	_focus_channel_energy_per_sec = 0.0

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_end_focus_channel()
