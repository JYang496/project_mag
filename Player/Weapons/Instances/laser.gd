extends Ranger

# Projectile
@onready var beam = preload("res://Player/Weapons/Projectiles/beam.tscn")

@onready var detect_area: Area2D = $DetectArea
@onready var oc_timer: Timer = $OCTimer

# Weapon
var ITEM_NAME = "Laser"
const PASSIVE_ID: StringName = &"laser_focus_channel_triggered"

var weapon_data = {
	"1": {"damage": "1", "fire_interval_sec": "2", "ammo": "5"},
	"2": {"damage": "1", "fire_interval_sec": "1.7", "ammo": "6"},
	"3": {"damage": "1", "fire_interval_sec": "1.5", "ammo": "7"},
	"4": {"damage": "2", "fire_interval_sec": "1.4", "ammo": "7"},
	"5": {"damage": "2", "fire_interval_sec": "1.3", "ammo": "8"},
	"6": {"damage": "2", "fire_interval_sec": "1.2", "ammo": "9"},
	"7": {"damage": "3", "fire_interval_sec": "1.0", "ammo": "10"},
	"8": {"damage": "3", "fire_interval_sec": "0.9", "ammo": "13"},
	"9": {"damage": "3", "fire_interval_sec": "0.85", "ammo": "16"}
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

func _on_shoot():
	fire_laser_toward(get_mouse_target() - global_position)
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
		"width_multiplier": 1.0,
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
	if beam_ins.has_method("configure_laser_beam"):
		beam_ins.call("configure_laser_beam", profile)
	self.get_tree().root.call_deferred("add_child",beam_ins)


func _on_oc_timer_timeout() -> void:
	remove_weapon()

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	if target == null or not is_instance_valid(target):
		return
	if not is_passive_ready():
		return
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(PASSIVE_ID, {
		"trigger": "beam_hit",
		"target": target,
		"cooldown": 0.0,
	})

func get_passive_status() -> Dictionary:
	var state := "ready" if is_passive_ready() else "waiting_refresh"
	return with_passive_charge_status({
		"id": str(PASSIVE_ID),
		"display_name": "Focus Channel",
		"state": state,
		"progress": 1.0 if state == "ready" else 0.0,
		"current": 1 if state == "ready" else 0,
		"required": 1,
		"ready": state == "ready",
		"trigger_hint": "beam_hit",
		"refresh_hint": "reload",
	})
