extends Ranger

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/spear.png")
var return_on_timeout = preload("res://Player/Weapons/Effects/return_on_timeout.tscn")

# Weapon
var ITEM_NAME = "Spear Launcher"
@export var unique_targets_trigger_count: int = 3
var _projectile_unique_hit_state: Dictionary = {}

var weapon_data = {
	"1": {"damage": "6", "speed": "900", "projectile_hits": "4", "fire_interval_sec": "0.6", "ammo": "30"},
	"2": {"damage": "7", "speed": "600", "projectile_hits": "4", "fire_interval_sec": "0.55", "ammo": "32"},
	"3": {"damage": "9", "speed": "600", "projectile_hits": "6", "fire_interval_sec": "0.5", "ammo": "34"},
	"4": {"damage": "10", "speed": "800", "projectile_hits": "6", "fire_interval_sec": "0.45", "ammo": "36"},
	"5": {"damage": "12", "speed": "800", "projectile_hits": "6", "fire_interval_sec": "0.4", "ammo": "38"},
	"6": {"damage": "14", "speed": "800", "projectile_hits": "6", "fire_interval_sec": "0.35", "ammo": "40"},
	"7": {"damage": "18", "speed": "800", "projectile_hits": "6", "fire_interval_sec": "0.3", "ammo": "42"},
	"8": {"damage": "22", "speed": "800", "projectile_hits": "6", "fire_interval_sec": "0.25", "ammo": "44"},
	"9": {"damage": "26", "speed": "800", "projectile_hits": "6", "fire_interval_sec": "0.20", "ammo": "46"}
}


func set_level(lv):
	lv = str(lv)
	var level_data := get_weapon_level_data(lv, weapon_data)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()


func _on_shoot():
	is_on_cooldown = true
	# 应用分支冷却倍率
	var cooldown := base_attack_cooldown
	cooldown *= get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = maxf(cooldown, 0.05)
	cooldown_timer.start()

	# 获取发射方向（支持分支多发）
	var target_position: Vector2 = get_mouse_target()
	var base_direction: Vector2 = global_position.direction_to(target_position).normalized()
	var shot_directions: Array[Vector2] = [base_direction]
	shot_directions = get_branch_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]

	# 获取伤害倍率
	var damage_multiplier := get_branch_projectile_damage_multiplier()

	# 对每个方向发射投射物
	for dir in shot_directions:
		var spawn_projectile = spawn_projectile_from_scene(projectile_template)
		if spawn_projectile == null:
			continue
		spawn_projectile.damage = max(1, int(round(float(get_runtime_shot_damage()) * damage_multiplier)))
		spawn_projectile.hp = projectile_hits
		spawn_projectile.size = size
		spawn_projectile.global_position = global_position
		spawn_projectile.projectile_texture = projectile_texture_resource
		projectile_direction = dir  # 设置方向供 apply_base_movement 使用
		apply_return_on_timeout(spawn_projectile)
		apply_effects_on_projectile(spawn_projectile)
		get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)

	notify_branch_weapon_shot(base_direction)

func apply_return_on_timeout(projectile_node, stop_time : float = 0.5, return_time : float = 1.0) -> void:
	var return_on_timeour_ins = return_on_timeout.instantiate()
	return_on_timeour_ins.return_time = return_time
	return_on_timeour_ins.stop_time = stop_time
	projectile_node.call_deferred("add_child",return_on_timeour_ins)
	projectile_node.module_list.append(return_on_timeour_ins)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	notify_branch_target_hit(target)

func on_projectile_hit_target(projectile: Node, target: Node) -> void:
	_try_trigger_unique_projectile_hits(projectile, target)

func _try_trigger_unique_projectile_hits(projectile: Node, target: Node) -> void:
	if not is_main_weapon():
		return
	if projectile == null or not is_instance_valid(projectile):
		return
	if target == null or not is_instance_valid(target):
		return
	if not is_offhand_skill_ready():
		return
	var projectile_id := projectile.get_instance_id()
	var target_id := target.get_instance_id()
	var state: Dictionary = _projectile_unique_hit_state.get(projectile_id, {
		"projectile": projectile,
		"ids": {},
		"targets": [],
	})
	state["projectile"] = projectile
	var ids: Dictionary = state.get("ids", {})
	if ids.has(target_id):
		return
	ids[target_id] = true
	var targets: Array = state.get("targets", [])
	targets.append(target)
	state["ids"] = ids
	state["targets"] = targets
	_projectile_unique_hit_state[projectile_id] = state
	var required_hits := maxi(1, unique_targets_trigger_count)
	if ids.size() < required_hits:
		return
	_projectile_unique_hit_state.erase(projectile_id)
	notify_offhand_skill_triggered(0.0)
	emit_passive_trigger(&"spear_multi_pierce_triggered", {
		"projectile": projectile,
		"target": target,
		"hit_count": required_hits,
		"targets": targets,
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var required_hits := maxi(1, unique_targets_trigger_count)
	var current_hits := _get_current_unique_projectile_hit_count()
	var state := "charging"
	if not is_main_weapon():
		state = "inactive"
	elif not is_passive_ready():
		state = "waiting_refresh"
	elif current_hits >= required_hits:
		state = "ready_pending_action"
	return {
		"id": "spear_multi_pierce_triggered",
		"display_name": "Multi Pierce",
		"state": state,
		"progress": clampf(float(current_hits) / float(required_hits), 0.0, 1.0),
		"current": current_hits,
		"required": required_hits,
		"ready": state == "ready_pending_action",
		"trigger_hint": "same_projectile_unique_targets",
		"refresh_hint": "reload",
	}

func _get_current_unique_projectile_hit_count() -> int:
	var best_count := 0
	for state_key in _projectile_unique_hit_state.keys():
		var state: Dictionary = _projectile_unique_hit_state.get(state_key, {})
		var projectile = state.get("projectile", null)
		if projectile == null or not is_instance_valid(projectile):
			continue
		var ids: Dictionary = state.get("ids", {})
		best_count = maxi(best_count, ids.size())
	return best_count
