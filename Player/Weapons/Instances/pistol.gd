extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://asset/images/test/minigun_bullet.png")
@export var auto_fire_range: float = 900.0
@export var pierce_mark_cycle_sec: float = 8.0
@export var pierce_mark_window_sec: float = 3.0
@export var pierce_mark_duration_sec: float = 5.0
const PISTOL_PIERCE_MARK_ID := &"pistol_pierce"

# Weapon
var ITEM_NAME = "Auto Pistol"
var _pierce_mark_cycle_elapsed_sec: float = 0.0
var _pierce_mark_window_remaining_sec: float = 0.0


var weapon_data = {
	"1": {"damage": "4", "speed": "600", "projectile_hits": "1", "fire_interval_sec": "1", "ammo": "45"},
	"2": {"damage": "6", "speed": "600", "projectile_hits": "1", "fire_interval_sec": "1", "ammo": "50"},
	"3": {"damage": "8", "speed": "600", "projectile_hits": "1", "fire_interval_sec": "1", "ammo": "55"},
	"4": {"damage": "10", "speed": "800", "projectile_hits": "1", "fire_interval_sec": "0.75", "ammo": "60"},
	"5": {"damage": "12", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.5", "ammo": "65"},
	"6": {"damage": "14", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.5", "ammo": "70"},
	"7": {"damage": "16", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.5", "ammo": "75"},
	"8": {"damage": "18", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.5", "ammo": "80"},
	"9": {"damage": "20", "speed": "800", "projectile_hits": "2", "fire_interval_sec": "0.5", "ammo": "85"}
}

var weapon_file
var minigun_data = JSON.new()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = _get_level_data(lv)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_pierce_mark_window(delta)
	_process_auto_fire()

func _update_pierce_mark_window(delta: float) -> void:
	if not _is_battle_phase():
		_pierce_mark_cycle_elapsed_sec = 0.0
		_pierce_mark_window_remaining_sec = 0.0
		return
	if _pierce_mark_window_remaining_sec > 0.0:
		_pierce_mark_window_remaining_sec = maxf(_pierce_mark_window_remaining_sec - maxf(delta, 0.0), 0.0)
		return
	if not is_offhand_skill_ready():
		return
	_pierce_mark_cycle_elapsed_sec += maxf(delta, 0.0)
	var required_sec := maxf(pierce_mark_cycle_sec, 0.1)
	if _pierce_mark_cycle_elapsed_sec < required_sec:
		return
	_pierce_mark_cycle_elapsed_sec = 0.0
	_pierce_mark_window_remaining_sec = maxf(pierce_mark_window_sec, 0.1)
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"pistol_continuous_move_triggered", {
		"window_duration": _pierce_mark_window_remaining_sec,
		"mark_duration": maxf(pierce_mark_duration_sec, 0.1),
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var required_sec := maxf(pierce_mark_cycle_sec, 0.1)
	var current_sec := clampf(_pierce_mark_cycle_elapsed_sec, 0.0, required_sec)
	var state := "charging"
	if _pierce_mark_window_remaining_sec > 0.0:
		state = "active"
	elif not is_passive_ready():
		state = "waiting_refresh"
	var charge_current := passive_controller.get_passive_charge_current()
	var charge_max := passive_controller.get_passive_charge_max()
	return with_passive_charge_status({
		"id": "pistol_continuous_move_triggered",
		"display_name": "Pierce Mark",
		"state": state,
		"progress": 1.0 if state == "active" else clampf(current_sec / required_sec, 0.0, 1.0),
		"current": _pierce_mark_window_remaining_sec if state == "active" else current_sec,
		"required": required_sec,
		"ready": state == "active",
		"trigger_hint": "periodic_auto_pistol_hits_mark_targets",
		"refresh_hint": "reload",
		"charge_current": charge_current,
		"charge_max": charge_max,
		"charges_current": charge_current,
		"charges_max": charge_max,
	})

func get_passive_max_charges() -> int:
	return 3

func _is_battle_phase() -> bool:
	if PhaseManager == null or not PhaseManager.has_method("current_state"):
		return true
	return str(PhaseManager.current_state()) == str(PhaseManager.BATTLE)

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	if not can_run_active_behavior():
		return
	if not pressed:
		return
	request_primary_fire()

func _process_auto_fire() -> void:
	if is_on_cooldown:
		return
	if not can_fire_with_heat():
		return
	if _find_closest_enemy() == null:
		return
	request_primary_fire()

func should_skip_benchmark_forced_fire() -> bool:
	return true

func _on_shoot() -> void:
	var target_pos: Vector2 = get_mouse_target()
	var target := _find_closest_enemy()
	if target != null:
		target_pos = target.global_position

	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()

	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return

	projectile_direction = global_position.direction_to(target_pos).normalized()
	if projectile_direction == Vector2.ZERO:
		return
	spawn_projectile.damage = get_runtime_shot_damage()
	spawn_projectile.damage = max(
		1,
		int(round(float(spawn_projectile.damage) * branch_runtime.get_branch_projectile_damage_multiplier()))
	)
	spawn_projectile.damage_type = branch_runtime.get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.size = size
	spawn_projectile.projectile_texture = projectile_texture_resource
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	_apply_pierce_mark(target)
	branch_runtime.notify_branch_target_hit(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	super.on_hit_target_with_damage_type(target, damage_type)
	_apply_pierce_mark(target)
	branch_runtime.notify_branch_target_hit(target)

func _apply_pierce_mark(target: Node) -> void:
	if _pierce_mark_window_remaining_sec <= 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_mark"):
		return
	var duration_sec := maxf(pierce_mark_duration_sec, 0.1)
	target.call("apply_mark", PISTOL_PIERCE_MARK_ID, duration_sec, {})

func _resolve_auto_aim_direction() -> Vector2:
	var target := _find_closest_enemy()
	if target != null:
		var direction := global_position.direction_to(target.global_position).normalized()
		if direction != Vector2.ZERO:
			return direction
	var fallback := global_position.direction_to(get_mouse_target()).normalized()
	if fallback == Vector2.ZERO:
		return Vector2.RIGHT
	return fallback

func _find_closest_enemy() -> Node2D:
	return find_closest_enemy(global_position, maxf(auto_fire_range, 1.0))

func _update_weapon_rotation() -> void:
	var direction := Vector2.ZERO
	var target := _find_closest_enemy()
	if target != null:
		direction = target.global_position - global_position
	else:
		direction = get_global_mouse_position() - global_position
	if direction == Vector2.ZERO:
		return
	rotation = direction.angle() + deg_to_rad(90)

func _get_level_data(lv: String) -> Dictionary:
	return get_weapon_level_data(lv, weapon_data)
