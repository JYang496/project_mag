extends Ranger

const PASSIVE_ID := &"piercing_blade_dance"
const CHARGE_GAINED_EVENT := &"piercing_blade_dance_charge_gained"
const TRIGGERED_EVENT := &"piercing_blade_dance_triggered"
const RADIAL_PROJECTILE_META := "piercing_blade_dance_radial"
const SPEAR_PIERCE_MARK_ID := &"spear_pierce"
const MARK_BONUS_MULTIPLIER_KEY := &"bonus_multiplier"
const MARK_THRESHOLD_KEY := &"threshold"
const MARK_VISUAL_NODE_NAME := "SpearPierceMarkVisual"
const MARK_VISUAL_SCRIPT := preload("res://Player/Weapons/Effects/spear_pierce_mark_visual.gd")

# Projectile
var projectile_template = preload("res://Player/Weapons/Projectiles/projectile.tscn")
var projectile_texture_resource = preload("res://Textures/test/spear.png")
var return_on_timeout = preload("res://Player/Weapons/Effects/return_on_timeout.tscn")

# Weapon
var ITEM_NAME = "Spear Launcher"
@export var same_target_trigger_count: int = 2
@export var charge_max: int = 20
@export var radial_charge_cost: int = 10
@export var empowered_radial_charge_cost: int = 20
@export var radial_projectile_count: int = 8
@export var empowered_radial_projectile_count: int = 16
@export var radial_fire_interval_sec: float = 0.05
@export var pierce_mark_duration_sec: float = 20.0
@export var pierce_mark_damage_multiplier: float = 1.35
@export var high_pierce_threshold: int = 4
@export var radial_knockback_amount: float = 100.0
@export var mark_visual_size_px: float = 20.0
@export var mark_visual_vertical_offset: float = -30.0

var _piercing_blade_dance_charge: int = 0
var _projectile_hit_state: Dictionary = {}

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
	var cooldown := base_attack_cooldown
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = maxf(cooldown, 0.05)
	cooldown_timer.start()

	var target_position: Vector2 = get_mouse_target()
	var base_direction: Vector2 = global_position.direction_to(target_position).normalized()
	var shot_directions: Array[Vector2] = branch_runtime.get_branch_shot_directions(base_direction)
	if shot_directions.is_empty():
		shot_directions = [base_direction]

	var damage_multiplier := branch_runtime.get_branch_projectile_damage_multiplier()
	for direction in shot_directions:
		_spawn_spear_projectile(direction, global_position, damage_multiplier, false)

	branch_runtime.notify_branch_weapon_shot(base_direction)


func _spawn_spear_projectile(
	direction: Vector2,
	spawn_position: Vector2,
	damage_multiplier: float = 1.0,
	is_radial_projectile: bool = false
) -> Node2D:
	var spawn_projectile := spawn_projectile_from_scene(projectile_template)
	if spawn_projectile == null:
		return null
	spawn_projectile.damage = max(1, int(round(float(get_runtime_shot_damage()) * maxf(damage_multiplier, 0.05))))
	spawn_projectile.hp = projectile_hits
	spawn_projectile.size = size
	spawn_projectile.global_position = spawn_position
	spawn_projectile.projectile_texture = projectile_texture_resource
	spawn_projectile.set_meta(RADIAL_PROJECTILE_META, is_radial_projectile)
	projectile_direction = direction.normalized()
	apply_return_on_timeout(spawn_projectile)
	apply_effects_on_projectile(spawn_projectile)
	get_projectile_spawn_parent().call_deferred("add_child", spawn_projectile)
	return spawn_projectile


func apply_return_on_timeout(projectile_node, stop_time: float = 0.5, return_time: float = 1.0) -> void:
	var return_on_timeout_instance = return_on_timeout.instantiate()
	return_on_timeout_instance.return_time = return_time
	return_on_timeout_instance.stop_time = stop_time
	projectile_node.call_deferred("add_child", return_on_timeout_instance)
	projectile_node.module_list.append(return_on_timeout_instance)


func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	branch_runtime.notify_branch_target_hit(target)


func on_projectile_hit_damage_dealt(
	projectile: Node,
	target: Node,
	_hit_damage_type: StringName,
	final_damage: int
) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if target == null or not is_instance_valid(target):
		return
	if final_damage <= 0:
		return
	if bool(projectile.get_meta(RADIAL_PROJECTILE_META, false)):
		if not _is_target_dead(target):
			_apply_pierce_mark(target)
			_apply_radial_knockback(target)
		return
	_try_gain_charge_from_same_target_hits(projectile, target)


func _try_gain_charge_from_same_target_hits(projectile: Node, target: Node) -> void:
	if not is_main_weapon() or is_reloading:
		return
	if _piercing_blade_dance_charge >= maxi(charge_max, 1):
		return
	_cleanup_projectile_hit_state()
	var projectile_id := projectile.get_instance_id()
	var target_id := target.get_instance_id()
	var state: Dictionary = _projectile_hit_state.get(projectile_id, {
		"projectile": projectile,
		"counts": {},
		"charged_targets": {},
	})
	var charged_targets: Dictionary = state.get("charged_targets", {})
	if bool(charged_targets.get(target_id, false)):
		return
	var counts: Dictionary = state.get("counts", {})
	var hit_count := int(counts.get(target_id, 0)) + 1
	counts[target_id] = hit_count
	state["counts"] = counts
	state["projectile"] = projectile
	if hit_count >= maxi(1, same_target_trigger_count):
		charged_targets[target_id] = true
		state["charged_targets"] = charged_targets
		_gain_piercing_blade_dance_charge(projectile, target)
	_projectile_hit_state[projectile_id] = state


func _gain_piercing_blade_dance_charge(projectile: Node, target: Node) -> void:
	var previous_charge := _piercing_blade_dance_charge
	_piercing_blade_dance_charge = mini(previous_charge + 1, maxi(charge_max, 1))
	emit_passive_trigger(CHARGE_GAINED_EVENT, {
		"passive_id": str(PASSIVE_ID),
		"projectile": projectile,
		"target": target,
		"charge_before": previous_charge,
		"charge": _piercing_blade_dance_charge,
		"charge_max": maxi(charge_max, 1),
		"trigger": "same_projectile_same_target_damage_twice",
	}, PASSIVE_SCOPE_GLOBAL)


func _cleanup_projectile_hit_state() -> void:
	for state_key in _projectile_hit_state.keys():
		var state: Dictionary = _projectile_hit_state.get(state_key, {})
		var projectile = state.get("projectile", null)
		if projectile == null or not is_instance_valid(projectile):
			_projectile_hit_state.erase(state_key)


func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name != &"on_reload_started":
		return
	if detail.get("source_weapon", null) != self:
		return
	if not is_main_weapon():
		return
	_try_start_piercing_blade_dance()


func _try_start_piercing_blade_dance() -> bool:
	var available_charge := _piercing_blade_dance_charge
	var charge_cost := 0
	var projectile_count := 0
	if available_charge >= maxi(empowered_radial_charge_cost, 1):
		charge_cost = maxi(empowered_radial_charge_cost, 1)
		projectile_count = maxi(empowered_radial_projectile_count, 1)
	elif available_charge >= maxi(radial_charge_cost, 1):
		charge_cost = maxi(radial_charge_cost, 1)
		projectile_count = maxi(radial_projectile_count, 1)
	else:
		return false

	_piercing_blade_dance_charge = maxi(0, available_charge - charge_cost)
	var directions := _build_radial_directions(projectile_count)
	emit_passive_trigger(TRIGGERED_EVENT, {
		"passive_id": str(PASSIVE_ID),
		"trigger": "reload_started",
		"charge_before": available_charge,
		"charge_cost": charge_cost,
		"charge": _piercing_blade_dance_charge,
		"projectile_count": projectile_count,
		"fire_interval_sec": maxf(radial_fire_interval_sec, 0.0),
	}, PASSIVE_SCOPE_GLOBAL)
	_fire_radial_volley(directions)
	return true


func _build_radial_directions(count: int) -> Array[Vector2]:
	var output: Array[Vector2] = []
	var player := PlayerData.player as Node2D
	var origin := player.global_position if player != null and is_instance_valid(player) else global_position
	var base_direction := origin.direction_to(get_mouse_target()).normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT
	for index in range(maxi(count, 1)):
		output.append(base_direction.rotated(TAU * float(index) / float(maxi(count, 1))).normalized())
	return output


func _fire_radial_volley(directions: Array[Vector2]) -> void:
	_fire_radial_volley_step(directions, 0)


func _fire_radial_volley_step(directions: Array[Vector2], index: int) -> void:
	if not is_inside_tree():
		return
	if index < 0 or index >= directions.size():
		return
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player):
		return
	_spawn_spear_projectile(directions[index], player.global_position, 1.0, true)
	if index >= directions.size() - 1:
		return
	var timer := get_tree().create_timer(maxf(radial_fire_interval_sec, 0.0))
	timer.timeout.connect(
		Callable(self, "_fire_radial_volley_step").bind(directions, index + 1),
		CONNECT_ONE_SHOT
	)


func _apply_pierce_mark(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_mark"):
		return
	target.call("apply_mark", SPEAR_PIERCE_MARK_ID, maxf(pierce_mark_duration_sec, 0.1), {
		MARK_BONUS_MULTIPLIER_KEY: maxf(pierce_mark_damage_multiplier, 1.0),
		MARK_THRESHOLD_KEY: maxi(1, high_pierce_threshold),
	})
	_refresh_pierce_mark_visual(target)


func _refresh_pierce_mark_visual(target: Node) -> void:
	var visual := target.get_node_or_null(MARK_VISUAL_NODE_NAME)
	if visual == null:
		visual = MARK_VISUAL_SCRIPT.new()
		visual.name = MARK_VISUAL_NODE_NAME
		target.add_child(visual)
	if visual.has_method("configure"):
		visual.call(
			"configure",
			_get_mark_visual_icon(),
			SPEAR_PIERCE_MARK_ID,
			mark_visual_size_px,
			mark_visual_vertical_offset
		)


func _get_mark_visual_icon() -> Texture2D:
	if DataHandler != null and DataHandler.has_method("read_weapon_data"):
		var definition := DataHandler.call("read_weapon_data", "3") as Resource
		if definition != null:
			var icon := definition.get("icon") as Texture2D
			if icon != null:
				return icon
	return null


func _apply_radial_knockback(target: Node) -> void:
	var knockback_value: Variant = target.get("knockback")
	if not (knockback_value is Dictionary):
		return
	var target_node := target as Node2D
	var player := PlayerData.player as Node2D
	if target_node == null or player == null or not is_instance_valid(player):
		return
	var push_direction := player.global_position.direction_to(target_node.global_position).normalized()
	if push_direction == Vector2.ZERO:
		push_direction = Vector2.RIGHT
	var knockback_data: Dictionary = knockback_value
	knockback_data["amount"] = maxf(radial_knockback_amount, 0.0)
	knockback_data["angle"] = push_direction
	target.set("knockback", knockback_data)


func _is_target_dead(target: Node) -> bool:
	var dead_value: Variant = target.get("is_dead")
	if dead_value != null and bool(dead_value):
		return true
	var hp_value: Variant = target.get("hp")
	return hp_value != null and int(hp_value) <= 0


func get_passive_status() -> Dictionary:
	var max_charge := maxi(charge_max, 1)
	var charge := clampi(_piercing_blade_dance_charge, 0, max_charge)
	var state := "charging"
	if not is_main_weapon():
		state = "inactive"
	elif is_reloading:
		state = "waiting_refresh"
	elif charge >= maxi(radial_charge_cost, 1):
		state = "ready_pending_action"
	return {
		"id": str(PASSIVE_ID),
		"display_name": "Piercing Blade Dance",
		"state": state,
		"progress": clampf(float(charge) / float(max_charge), 0.0, 1.0),
		"current": charge,
		"required": max_charge,
		"ready": state == "ready_pending_action",
		"trigger_hint": "reload_started",
		"refresh_hint": "gain_charge_from_repeat_projectile_damage",
		"radial_projectile_count": _get_next_radial_projectile_count(),
	}


func _get_next_radial_projectile_count() -> int:
	if _piercing_blade_dance_charge >= maxi(empowered_radial_charge_cost, 1):
		return maxi(empowered_radial_projectile_count, 1)
	if _piercing_blade_dance_charge >= maxi(radial_charge_cost, 1):
		return maxi(radial_projectile_count, 1)
	return 0
