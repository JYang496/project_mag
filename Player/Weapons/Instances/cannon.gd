extends Ranger
class_name Mortar

var ITEM_NAME := "Mortar"
const DELAYED_GROUND_IMPACT := preload("res://Player/Weapons/Geometry/delayed_ground_impact.gd")
const WALKING_BARRAGE_DAMAGE_RATIOS: Array[float] = [0.50, 0.60, 0.70, 0.90]
const WALKING_BARRAGE_DISTANCE_OFFSETS: Array[float] = [-96.0, -32.0, 32.0, 96.0]
const WALKING_BARRAGE_LATERAL_OFFSETS: Array[float] = [-18.0, 18.0, -18.0, 18.0]
const WALKING_BARRAGE_FIRST_IMPACT_SEC := 0.48
const WALKING_BARRAGE_IMPACT_INTERVAL_SEC := 0.16
const WALKING_BARRAGE_RADIUS := 68.0

@export var windup_sec: float = 0.15
@export var idle_fire_empowered_shots: int = 1
@export var idle_fire_direct_damage_multiplier: float = 1.45
@export var idle_fire_breach_multiplier: float = 1.2
@export var idle_fire_breach_duration_sec: float = 4.0
@export var ground_impact_delay_sec: float = 0.55
@export var ground_impact_radius: float = 72.0
@export var ground_impact_min_distance: float = 80.0
@export_flags_2d_physics var ground_target_blocker_mask: int = 32
const IDLE_FIRE_BREACH_STATUS_ID := &"cannon_breach"
var attack_range: float = 920.0
var _windup_in_progress: bool = false
var _idle_fire_empowered_shots_remaining: int = 0

var weapon_data := {
	"1": {"damage": "50", "speed": "1120", "projectile_hits": "2", "fire_interval_sec": "1.667", "ammo": "4"},
	"2": {"damage": "60", "speed": "1140", "projectile_hits": "2", "fire_interval_sec": "1.600", "ammo": "4"},
	"3": {"damage": "67", "speed": "1170", "projectile_hits": "2", "fire_interval_sec": "1.533", "ammo": "4"},
	"4": {"damage": "80", "speed": "1200", "projectile_hits": "2", "fire_interval_sec": "1.467", "ammo": "4"},
	"5": {"damage": "100", "speed": "1230", "projectile_hits": "2", "fire_interval_sec": "1.400", "ammo": "4"},
	"6": {"damage": "120", "speed": "1260", "projectile_hits": "2", "fire_interval_sec": "1.333", "ammo": "4"},
	"7": {"damage": "140", "speed": "1290", "projectile_hits": "3", "fire_interval_sec": "1.267", "ammo": "4"},
	"8": {"damage": "160", "speed": "1320", "projectile_hits": "4", "fire_interval_sec": "1.201", "ammo": "4"},
	"9": {"damage": "180", "speed": "1350", "projectile_hits": "5", "fire_interval_sec": "1.135", "ammo": "4"}
}

@onready var windup_timer: Timer = $WindupTimer

func set_level(lv) -> void:
	lv = str(lv)
	var level_data := _get_level_data(lv)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])
	base_speed = int(level_data["speed"])
	base_projectile_hits = int(level_data["projectile_hits"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)

func request_primary_fire() -> bool:
	if not is_attack_phase_allowed():
		return false
	if is_on_cooldown or _windup_in_progress:
		return false
	if not can_fire_with_heat():
		return false
	if not can_fire_with_ammo():
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	if not consume_ammo(1):
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return false
	if windup_sec <= 0.0:
		prepare_energy_release_attack()
		emit_signal("shoot")
		finish_energy_release_attack()
		play_fire_feedback()
		notify_main_weapon_fired()
		register_shot_heat()
		if uses_ammo_system() and current_ammo <= 0:
			request_reload()
		return true
	_windup_in_progress = true
	is_on_cooldown = true
	if windup_timer:
		windup_timer.wait_time = maxf(windup_sec, 0.01)
		windup_timer.start()
	else:
		_on_windup_timer_timeout()
	return true

func allows_held_attack_on_battle_entry() -> bool:
	return true

func _on_windup_timer_timeout() -> void:
	if not _windup_in_progress:
		return
	_windup_in_progress = false
	prepare_energy_release_attack()
	emit_signal("shoot")
	finish_energy_release_attack()
	play_fire_feedback()
	notify_main_weapon_fired()
	register_shot_heat()
	if uses_ammo_system() and current_ammo <= 0:
		request_reload()

func _on_shoot() -> void:
	is_on_cooldown = true
	_try_emit_idle_fire_trigger()
	var idle_empowered_shot: bool = _consume_idle_empowered_shot()
	var cooldown: float = maxf(get_runtime_attack_cooldown(), 0.05)
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()

	projectile_direction = get_aim_forward()
	if projectile_direction == Vector2.ZERO:
		return
	var runtime_damage: int = get_runtime_damage()
	var damage_multiplier: float = branch_runtime.get_branch_projectile_damage_multiplier()
	damage_multiplier *= _consume_branch_heat_spend_multiplier()
	if idle_empowered_shot:
		damage_multiplier *= maxf(idle_fire_direct_damage_multiplier, 0.05)
	var impact_damage: int = maxi(1, int(round(float(runtime_damage) * damage_multiplier)))
	var damage_type: StringName = branch_runtime.get_branch_damage_type_override(Attack.TYPE_PHYSICAL)
	var origin: Vector2 = get_muzzle_global_position()
	var impact_position: Vector2 = _resolve_ground_impact_position(origin, projectile_direction)
	var impact: Node = DELAYED_GROUND_IMPACT.new().setup(
		self, origin, impact_position, ground_impact_delay_sec,
		get_effective_area_radius(ground_impact_radius), impact_damage,
		damage_type, idle_empowered_shot
	) as Node
	apply_energy_release_marker(impact)
	apply_heat_snapshot_marker(impact)
	get_projectile_spawn_parent().add_child(impact)

func _resolve_ground_impact_position(origin: Vector2, direction: Vector2) -> Vector2:
	var normalized_direction: Vector2 = direction.normalized()
	var aim_position: Vector2 = get_mouse_target() as Vector2
	var aimed_distance: float = origin.distance_to(aim_position)
	var distance: float = clampf(aimed_distance, maxf(ground_impact_min_distance, 1.0), attack_range)
	var target_position: Vector2 = origin + normalized_direction * distance
	if ground_target_blocker_mask <= 0 or not is_inside_tree():
		return target_position
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, target_position, ground_target_blocker_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return target_position
	var collision_position: Vector2 = result.get("position", target_position)
	return collision_position - normalized_direction * 4.0

func activate_weapon_skill_effect(_context: SkillActionContext) -> bool:
	if not is_inside_tree() or not is_attack_phase_allowed():
		return false
	var origin := get_muzzle_global_position()
	var direction := get_aim_forward()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var barrage_center := _resolve_ground_impact_position(origin, direction)
	var lateral := direction.orthogonal()
	var runtime_damage := get_runtime_damage()
	var spawn_parent := get_projectile_spawn_parent()
	for index in range(WALKING_BARRAGE_DAMAGE_RATIOS.size()):
		var impact_position := barrage_center
		impact_position += direction * WALKING_BARRAGE_DISTANCE_OFFSETS[index]
		impact_position += lateral * WALKING_BARRAGE_LATERAL_OFFSETS[index]
		impact_position = _resolve_skill_impact_position(origin, impact_position)
		var impact_damage := maxi(1, int(round(
			float(runtime_damage) * WALKING_BARRAGE_DAMAGE_RATIOS[index]
		)))
		var impact_delay := WALKING_BARRAGE_FIRST_IMPACT_SEC + WALKING_BARRAGE_IMPACT_INTERVAL_SEC * index
		var impact := DELAYED_GROUND_IMPACT.new().setup(
			self, origin, impact_position, impact_delay,
			get_effective_area_radius(WALKING_BARRAGE_RADIUS), impact_damage,
			Attack.TYPE_PHYSICAL, false
		) as Node
		spawn_parent.add_child(impact)
	return true

func _resolve_skill_impact_position(origin: Vector2, desired_position: Vector2) -> Vector2:
	if ground_target_blocker_mask <= 0 or not is_inside_tree():
		return desired_position
	var query := PhysicsRayQueryParameters2D.create(origin, desired_position, ground_target_blocker_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return desired_position
	var direction := origin.direction_to(desired_position)
	return (result.get("position", desired_position) as Vector2) - direction * 4.0

func _consume_branch_heat_spend_multiplier() -> float:
	var multiplier := 1.0
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior == null or not is_instance_valid(behavior):
			continue
		if behavior.has_method("consume_heat_spend_multiplier"):
			multiplier *= maxf(float(behavior.call("consume_heat_spend_multiplier")), 0.05)
	return maxf(multiplier, 0.05)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	branch_runtime.notify_branch_target_hit(target)

func on_projectile_hit_damage_dealt(projectile: Node, target: Node, hit_damage_type: StringName, final_damage: int) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if target == null or not is_instance_valid(target) or final_damage <= 0:
		return
	if bool(projectile.get_meta(ENERGY_RELEASE_ATTACK_META, false)):
		for behavior in branch_runtime.get_branch_behaviors():
			if behavior.has_method("apply_zero_release_impact"):
				behavior.call("apply_zero_release_impact", target, projectile, final_damage)
	if not bool(projectile.get_meta("cannon_idle_empowered", false)):
		return
	_apply_idle_fire_breach(target)

func on_cannon_ground_impact_damage_dealt(
	_attack_node: Node,
	target: Node,
	_hit_damage_type: StringName,
	final_damage: int,
	idle_empowered: bool
) -> void:
	if target == null or not is_instance_valid(target) or final_damage <= 0:
		return
	if idle_empowered:
		_apply_idle_fire_breach(target)

func on_cannon_ground_impact_complete(
	attack_node: Node,
	impact_position: Vector2,
	base_impact_damage: int,
	strongest_final_damage: int,
	_applied_count: int
) -> void:
	if attack_node == null or not is_instance_valid(attack_node):
		return
	if not bool(attack_node.get_meta(ENERGY_RELEASE_ATTACK_META, false)):
		return
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior != null and is_instance_valid(behavior) and behavior.has_method("apply_zero_release_ground_impact"):
			behavior.call(
				"apply_zero_release_ground_impact", impact_position, attack_node,
				maxi(strongest_final_damage, base_impact_damage)
			)

func _on_cooldown_timer_timeout() -> void:
	is_on_cooldown = false
	_windup_in_progress = false

func _try_emit_idle_fire_trigger() -> bool:
	if not is_support_trigger_ready():
		return false
	if not consume_support_trigger():
		return false
	_idle_fire_empowered_shots_remaining = maxi(1, idle_fire_empowered_shots)
	emit_passive_trigger(&"cannon_idle_fire_triggered", {
		"duration": WeaponTriggerRuntimeType.SUPPORT_CHARGE_DURATION_SEC,
		"trigger": "support_charge",
		"refresh": "support",
		"empowered_shots": maxi(1, idle_fire_empowered_shots),
		"direct_damage_multiplier": maxf(idle_fire_direct_damage_multiplier, 0.05),
		"breach_multiplier": maxf(idle_fire_breach_multiplier, 1.0),
		"breach_duration": maxf(idle_fire_breach_duration_sec, 0.1),
	}, PASSIVE_SCOPE_BODY)
	return true

func _consume_idle_empowered_shot() -> bool:
	if _idle_fire_empowered_shots_remaining <= 0:
		return false
	_idle_fire_empowered_shots_remaining -= 1
	return true

func _apply_idle_fire_breach(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("apply_damage_taken_multiplier_status"):
		return
	target.call(
		"apply_damage_taken_multiplier_status",
		IDLE_FIRE_BREACH_STATUS_ID,
		maxf(idle_fire_breach_multiplier, 1.0),
		maxf(idle_fire_breach_duration_sec, 0.1)
	)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)

func get_passive_status() -> Dictionary:
	if has_weapon_trait(WeaponTrait.ENERGY):
		return get_energy_full_fire_status()
	var progress := get_support_trigger_progress()
	var state := "ready_pending_action" if is_support_trigger_ready() else "charging"
	return with_passive_charge_status({
		"id": "cannon_idle_fire_triggered",
		"display_name": "Breach Shot",
		"state": state,
		"progress": progress,
		"current": progress * WeaponTriggerRuntimeType.SUPPORT_CHARGE_DURATION_SEC,
		"required": WeaponTriggerRuntimeType.SUPPORT_CHARGE_DURATION_SEC,
		"ready": state == "ready_pending_action",
		"condition_visible": true,
		"condition_progress": progress,
		"trigger_hint": "support_charge",
		"refresh_hint": "support",
		"empowered_shots": maxi(1, idle_fire_empowered_shots),
		"direct_damage_multiplier": maxf(idle_fire_direct_damage_multiplier, 0.05),
		"breach_multiplier": maxf(idle_fire_breach_multiplier, 1.0),
		"breach_duration": maxf(idle_fire_breach_duration_sec, 0.1),
	})

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_idle_fire_empowered_shots_remaining = 0

func _get_level_data(lv: String) -> Dictionary:
	return get_weapon_level_data(lv, weapon_data)
