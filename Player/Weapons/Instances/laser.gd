extends Ranger

const HYBRID_GROUND_REGISTRATION := preload("res://Visual/Oblique/hybrid_ground_registration.gd")

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
var _refraction_matrix_active := false
var _refraction_last_hit_msec: Dictionary = {}

var weapon_data = {
	"1": {"damage": "3", "fire_interval_sec": "1.6", "ammo": "6"},
	"2": {"damage": "3", "fire_interval_sec": "1.36", "ammo": "8"},
	"3": {"damage": "3", "fire_interval_sec": "1.2", "ammo": "9"},
	"4": {"damage": "4", "fire_interval_sec": "1.12", "ammo": "9"},
	"5": {"damage": "4", "fire_interval_sec": "1.04", "ammo": "10"},
	"6": {"damage": "4", "fire_interval_sec": "0.96", "ammo": "11"},
	"7": {"damage": "6", "fire_interval_sec": "0.8", "ammo": "13"},
	"8": {"damage": "6", "fire_interval_sec": "0.72", "ammo": "14"},
	"9": {"damage": "6", "fire_interval_sec": "0.68", "ammo": "15"}
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
	beam_ins.damage = max(1, int(round(float(get_runtime_damage()) * damage_multiplier)))
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
	_try_apply_refraction(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	super.on_hit_target_with_damage_type(target, damage_type)
	_try_apply_refraction(target)

func _try_apply_refraction(target: Node) -> void:
	if not _refraction_matrix_active or target == null or not is_instance_valid(target) or not target is Node2D:
		return
	var now := Time.get_ticks_msec()
	var target_id := target.get_instance_id()
	if now < int(_refraction_last_hit_msec.get(target_id, 0)) + 150:
		return
	_refraction_last_hit_msec[target_id] = now
	var ratios: Array[float] = [0.60, 0.45, 0.30]
	var candidates: Array[Node2D] = []
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(get_tree(), (target as Node2D).global_position, 260.0):
		var enemy := enemy_ref as Node2D
		if enemy != null and is_instance_valid(enemy) and enemy != target:
			candidates.append(enemy)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to((target as Node2D).global_position) \
			< b.global_position.distance_squared_to((target as Node2D).global_position)
	)
	var from_position := (target as Node2D).global_position
	for index in range(mini(candidates.size(), ratios.size())):
		var chained := candidates[index]
		var amount: int = maxi(1, int(round(float(get_runtime_damage()) * ratios[index])))
		var data := DamageManager.build_damage_data(
			self, amount, Attack.TYPE_ENERGY,
			{"amount": 0, "angle": Vector2.ZERO},
			DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.BEAM
		)
		DamageManager.apply_to_target(chained, data)
		_draw_refraction_line(from_position, chained.global_position)
		from_position = chained.global_position

func activate_weapon_skill_effect(_context: SkillActionContext) -> bool:
	_refraction_matrix_active = true
	_refraction_last_hit_msec.clear()
	return true

func finish_weapon_skill_effect() -> void:
	_refraction_matrix_active = false
	_refraction_last_hit_msec.clear()

func _draw_refraction_line(from_position: Vector2, to_position: Vector2) -> void:
	var world_root := get_tree().current_scene as Node2D
	if world_root == null:
		return
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.66, 0.46, 1.0, 0.92)
	line.set_meta(&"hybrid_ground_visible", true)
	line.set_meta(&"hybrid_segment_style", &"beam")
	line.set_meta(&"hybrid_segment_endpoints", true)
	world_root.add_child(line)
	# The hybrid segment renderer transforms Line2D points through its parent,
	# so store both endpoints in the world root's local coordinate space.
	line.points = PackedVector2Array([
		world_root.to_local(from_position),
		world_root.to_local(to_position),
	])
	line.add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	HYBRID_GROUND_REGISTRATION.register(line, &"register_ground_segment")
	line.tree_exiting.connect(func() -> void:
		HYBRID_GROUND_REGISTRATION.unregister(line)
	, CONNECT_ONE_SHOT)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.16)
	tween.tween_callback(line.queue_free)

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
	finish_weapon_skill_effect()
