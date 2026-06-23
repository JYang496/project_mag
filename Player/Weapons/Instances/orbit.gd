extends Ranger

const CLOSE_CHAIN_RULES := preload("res://Player/Weapons/close_quarters_chain_rules.gd")

@onready var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
@onready var projectile_texture_resource = preload("res://asset/images/test/bullet.png")
@export var radius : float = 80.0
@export var angle : float = 0.0
var knock_back = {
	"amount": 0,
	"angle": Vector2.ZERO
}
# Effect
@onready var rotate_around_player = preload("res://Player/Weapons/Effects/rotate_around_player.tscn")

var satellites : Array = []
const ORBIT_PROJECTILE_LIFETIME_SEC: float = 5.0
const LV1_TARGET_ACTIVE_COUNT: float = 2.0
@export var orbit_radius_jitter: float = 12.0
@export var satellite_slow_multiplier: float = 0.85
@export var satellite_slow_duration_sec: float = 1.0



# Weapon
var ITEM_NAME = "Orbit"
var spin_speed : float = 5.0
@export var offhand_spin_speed_multiplier: float = 0.65
var _pending_satellite_spawn_count: int = 0

var weapon_data = {
	"1": {"damage": "8", "spin_speed": "3", "fire_interval_sec": "2.5", "ammo": "2"},
	"2": {"damage": "10", "spin_speed": "3", "fire_interval_sec": "2.5", "ammo": "2"},
	"3": {"damage": "12", "spin_speed": "3.5", "fire_interval_sec": "2.5", "ammo": "3"},
	"4": {"damage": "14", "spin_speed": "3.5", "fire_interval_sec": "2.5", "ammo": "3"},
	"5": {"damage": "16", "spin_speed": "4", "fire_interval_sec": "2.5", "ammo": "4"},
	"6": {"damage": "18", "spin_speed": "4", "fire_interval_sec": "2.5", "ammo": "5"},
	"7": {"damage": "20", "spin_speed": "5", "fire_interval_sec": "2.5", "ammo": "6"},
	"8": {"damage": "22", "spin_speed": "6", "fire_interval_sec": "2.5", "ammo": "7"},
	"9": {"damage": "24", "spin_speed": "7", "fire_interval_sec": "2.5", "ammo": "8"}
}

func set_level(lv) -> void:
	var requested_level := maxi(int(lv), 1)
	var key := get_weapon_level_key(requested_level, weapon_data)
	var level_data: Dictionary = get_weapon_level_data(key, weapon_data)
	if level_data.is_empty():
		return
	level = int(key)
	base_damage = int(level_data.get("damage", 1))
	spin_speed = int(level_data.get("spin_speed", spin_speed))
	base_attack_cooldown = float(level_data.get("fire_interval_sec", ORBIT_PROJECTILE_LIFETIME_SEC / maxf(LV1_TARGET_ACTIVE_COUNT, 1.0)))
	apply_level_ammo(level_data)
	base_projectile_hits = 99999
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)
	_refresh_orbit_mode_state()

func apply_rotate_around_player(projectile_node : Node2D, offset_step : float, n : int, spin_speed_value: float) -> void:
	var rotate_around_player_ins = rotate_around_player.instantiate()
	rotate_around_player_ins.spin_speed = spin_speed_value
	rotate_around_player_ins.radius = _resolve_orbit_spawn_radius()
	rotate_around_player_ins.angle_offset = offset_step * n
	
	projectile_node.call_deferred("add_child",rotate_around_player_ins)
	projectile_node.module_list.append(rotate_around_player_ins)
	pass


func remove_weapon() -> void:
	var idx := PlayerData.player_weapon_list.find(self)
	if idx >= 0:
		PlayerData.player_weapon_list.remove_at(idx)
	PlayerData.sanitize_main_weapon_index()
	PlayerData.on_select_weapon = PlayerData.main_weapon_index
	queue_free()

func _on_tree_exiting() -> void:
	# Remove satellites when weapon node exits.
	for s in satellites:
		s.queue_free()

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_prune_satellites()

func _on_weapon_role_changed(next_role: String) -> void:
	_update_satellite_runtime_state()

func _refresh_orbit_mode_state() -> void:
	_prune_satellites()
	_update_satellite_runtime_state()

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
	var spent_ammo := current_ammo
	if not consume_ammo(spent_ammo):
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	_pending_satellite_spawn_count = spent_ammo
	emit_signal("shoot")
	notify_main_weapon_fired()
	register_shot_heat()
	if uses_ammo_system() and current_ammo <= 0:
		request_reload()
	return true

func _on_shoot() -> void:
	var spawn_count := maxi(_pending_satellite_spawn_count, 0)
	_pending_satellite_spawn_count = 0
	if spawn_count <= 0:
		return
	is_on_cooldown = true
	start_weapon_cooldown(attack_cooldown)
	var new_satellites: Array[Projectile] = []
	var runtime_damage: int = get_runtime_shot_damage()
	var damage_multiplier: float = branch_runtime.get_branch_projectile_damage_multiplier()
	var damage_type: StringName = branch_runtime.get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	var effective_spin_speed: float = _get_effective_orbit_spin_speed()
	for n in range(spawn_count):
		var spawn_projectile = spawn_projectile_from_scene(projectile_template)
		if spawn_projectile == null:
			continue
		spawn_projectile.damage = max(1, int(round(float(runtime_damage) * damage_multiplier)))
		spawn_projectile.damage_type = damage_type
		spawn_projectile.hp = 99999
		spawn_projectile.expire_time = ORBIT_PROJECTILE_LIFETIME_SEC
		spawn_projectile.size = size
		spawn_projectile.projectile_texture = projectile_texture_resource
		apply_rotate_around_player(spawn_projectile, 0.0, n, effective_spin_speed)
		apply_effects_on_projectile(spawn_projectile)
		get_tree().root.call_deferred("add_child", spawn_projectile)
		satellites.append(spawn_projectile)
		new_satellites.append(spawn_projectile)
	_rebalance_new_satellite_offsets(new_satellites)

func _update_satellite_runtime_state() -> void:
	var runtime_damage: int = get_runtime_shot_damage()
	var damage_multiplier: float = branch_runtime.get_branch_projectile_damage_multiplier()
	var damage_type: StringName = branch_runtime.get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	var effective_spin_speed: float = _get_effective_orbit_spin_speed()
	for item in satellites:
		var satellite: Projectile = item as Projectile
		if satellite == null or not is_instance_valid(satellite):
			continue
		satellite.damage = max(1, int(round(float(runtime_damage) * damage_multiplier)))
		satellite.damage_type = damage_type
		var rotate_effect: RotateAroundPlayer = _find_rotate_module(satellite)
		if rotate_effect != null and is_instance_valid(rotate_effect):
			rotate_effect.spin_speed = effective_spin_speed

func _find_rotate_module(satellite: Projectile) -> RotateAroundPlayer:
	for module_item in satellite.module_list:
		var rotate_effect: RotateAroundPlayer = module_item as RotateAroundPlayer
		if rotate_effect != null and is_instance_valid(rotate_effect):
			return rotate_effect
	return null

func _clear_satellites() -> void:
	for s in satellites:
		if s and is_instance_valid(s):
			s.queue_free()
	satellites.clear()

func _prune_satellites() -> void:
	var kept: Array = []
	for s in satellites:
		if s and is_instance_valid(s):
			kept.append(s)
	satellites = kept

func _rebalance_new_satellite_offsets(new_satellites: Array[Projectile]) -> void:
	var count := new_satellites.size()
	if count <= 0:
		return
	var offset_step := TAU / float(count)
	for i in range(count):
		var satellite: Projectile = new_satellites[i]
		if satellite == null or not is_instance_valid(satellite):
			continue
		var rotate_effect: RotateAroundPlayer = _find_rotate_module(satellite)
		if rotate_effect == null or not is_instance_valid(rotate_effect):
			continue
		rotate_effect.angle_offset = offset_step * float(i)

func _resolve_orbit_spawn_radius() -> float:
	var jitter := maxf(orbit_radius_jitter, 0.0)
	if jitter <= 0.0:
		return maxf(radius, 1.0)
	return maxf(radius + randf_range(-jitter, jitter), 1.0)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	CLOSE_CHAIN_RULES.apply_slow_to_target(target, satellite_slow_multiplier, satellite_slow_duration_sec)
	branch_runtime.notify_branch_target_hit(target)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name == &"on_player_damaged":
		_try_trigger_player_damaged(detail)
	branch_runtime.notify_branch_passive_event(event_name, detail)

func _try_trigger_player_damaged(detail: Dictionary) -> void:
	if not is_offhand_skill_ready():
		return
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"orbit_player_damaged_triggered", {
		"attack": detail.get("attack", null),
		"player": detail.get("player", PlayerData.player),
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var state := "ready" if is_passive_ready() else "waiting_refresh"
	return with_passive_charge_status({
		"id": "orbit_player_damaged_triggered",
		"display_name": "Player Damaged",
		"state": state,
		"progress": 1.0 if state == "ready" else 0.0,
		"ready": state == "ready",
		"trigger_hint": "player_damaged",
		"refresh_hint": "reload",
	})

func get_satellites() -> Array[Node2D]:
	var valid_satellites: Array[Node2D] = []
	for item in satellites:
		var satellite: Node2D = item as Node2D
		if satellite == null or not is_instance_valid(satellite):
			continue
		valid_satellites.append(satellite)
	return valid_satellites

func get_auto_fire_target_range() -> float:
	return maxf(radius + maxf(orbit_radius_jitter, 0.0), 1.0)

func _get_branch_spin_speed_multiplier() -> float:
	return branch_runtime.get_branch_orbit_spin_speed_multiplier()

func _get_effective_orbit_spin_speed() -> float:
	var role_multiplier: float = 1.0 if is_main_weapon() else maxf(offhand_spin_speed_multiplier, 0.05)
	return spin_speed * _get_branch_spin_speed_multiplier() * role_multiplier
