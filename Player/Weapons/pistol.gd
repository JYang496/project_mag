extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/minigun_bullet.png")
@export var auto_fire_range: float = 900.0
@export var continuous_move_trigger_sec: float = 6.0

# Weapon
var ITEM_NAME = "Pistol"
var _continuous_move_accum_sec: float = 0.0


var weapon_data = {
	"1": {
		"level": "1",
		"damage": "4",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "45",
		"cost": "17",
	},
	"2": {
		"level": "2",
		"damage": "6",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "50",
		"cost": "17",
	},
	"3": {
		"level": "3",
		"damage": "8",
		"speed": "600",
		"hp": "1",
		"fire_interval_sec": "1",
		"ammo": "55",
		"cost": "17",
	},
	"4": {
		"level": "4",
		"damage": "10",
		"speed": "800",
		"hp": "1",
		"fire_interval_sec": "0.75",
		"ammo": "60",
		"cost": "17",
	},
	"5": {
		"level": "5",
		"damage": "12",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "0.5",
		"ammo": "65",
		"cost": "17",
	},
	"6": {
		"level": "6",
		"damage": "14",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "0.5",
		"ammo": "70",
		"cost": "17",
	},
	"7": {
		"level": "7",
		"damage": "16",
		"speed": "800",
		"hp": "2",
		"fire_interval_sec": "0.5",
		"ammo": "75",
		"cost": "17",
	}
}

var weapon_file
var minigun_data = JSON.new()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = _get_level_data(lv)
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["hp"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	notify_branch_level_applied(level)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_continuous_move_trigger(delta)
	_process_auto_fire()

func _update_continuous_move_trigger(delta: float) -> void:
	if not _is_battle_phase():
		_continuous_move_accum_sec = 0.0
		return
	var player := PlayerData.player as Player
	if player == null or not is_instance_valid(player):
		_continuous_move_accum_sec = 0.0
		return
	var is_moving := player.velocity.length_squared() > 1.0
	if not is_moving:
		_continuous_move_accum_sec = 0.0
		return
	_continuous_move_accum_sec += maxf(delta, 0.0)
	if _continuous_move_accum_sec < maxf(continuous_move_trigger_sec, 0.1):
		return
	_continuous_move_accum_sec = 0.0
	if not is_offhand_skill_ready():
		return
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"pistol_continuous_move_triggered", {
		"duration": maxf(continuous_move_trigger_sec, 0.1),
		"refresh": "reload",
		"player": player,
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var required_sec := maxf(continuous_move_trigger_sec, 0.1)
	var current_sec := clampf(_continuous_move_accum_sec, 0.0, required_sec)
	var state := "charging"
	if not is_main_weapon():
		state = "inactive"
	elif not is_passive_ready():
		state = "waiting_refresh"
	elif current_sec >= required_sec:
		state = "ready_pending_action"
	return {
		"id": "pistol_continuous_move_triggered",
		"display_name": "Continuous Move",
		"state": state,
		"progress": clampf(current_sec / required_sec, 0.0, 1.0),
		"current": current_sec,
		"required": required_sec,
		"ready": state == "ready_pending_action",
		"trigger_hint": "continuous_move",
		"refresh_hint": "reload",
	}

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

func _on_shoot() -> void:
	var target_pos: Vector2 = get_mouse_target()
	var target := _find_closest_enemy()
	if target != null:
		target_pos = target.global_position

	is_on_cooldown = true
	var cooldown := maxf(get_effective_cooldown(attack_cooldown), 0.05)
	cooldown *= get_branch_cooldown_multiplier()
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
		int(round(float(spawn_projectile.damage) * get_branch_projectile_damage_multiplier()))
	)
	spawn_projectile.damage_type = get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	spawn_projectile.hp = projectile_hits
	spawn_projectile.global_position = global_position
	spawn_projectile.size = size
	spawn_projectile.projectile_texture = projectile_texture_resource
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	notify_branch_target_hit(target)

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
	var tree := get_tree()
	if tree == null:
		return null
	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy_ref in WeaponModuleRuntimeUtils.get_nearby_enemies(tree, global_position, maxf(auto_fire_range, 1.0)):
		var enemy := enemy_ref as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_dist:
			nearest_dist = distance
			nearest = enemy
	return nearest

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
	if weapon_data.has(lv):
		return weapon_data[lv]
	if weapon_data.has("1"):
		return weapon_data["1"]
	return {"level": "1", "damage": "4", "speed": "600", "hp": "1", "fire_interval_sec": "1", "ammo": "45", "cost": "17"}
