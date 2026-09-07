extends Ranger
class_name Sniper

const HITSCAN_LINE := preload("res://Player/Weapons/Geometry/hitscan_line_attack.gd")

var ITEM_NAME := "Sniper"
const NEAR_DISTANCE_THRESHOLD: float = 220.0
const FAR_DAMAGE_MULTIPLIER: float = 1.8
@export var far_hit_trigger_distance: float = 400.0
@export var hitscan_width: float = 5.0
@export_flags_2d_physics var hitscan_world_blocker_mask: int = 32
@export var tracer_duration_sec: float = 0.08

var attack_range: float = 900.0
var _next_shot_max_distance_bonus: bool = false
var _lethal_aim_armed := false

var weapon_data := {
	"1": {"damage": "23", "speed": "1700", "projectile_hits": "5", "fire_interval_sec": "3.0", "ammo": "5"},
	"2": {"damage": "29", "speed": "1700", "projectile_hits": "6", "fire_interval_sec": "2.8", "ammo": "6"},
	"3": {"damage": "36", "speed": "1800", "projectile_hits": "7", "fire_interval_sec": "2.6", "ammo": "7"},
	"4": {"damage": "46", "speed": "1800", "projectile_hits": "8", "fire_interval_sec": "2.4", "ammo": "8"},
	"5": {"damage": "57", "speed": "1900", "projectile_hits": "9", "fire_interval_sec": "2.2", "ammo": "9"},
	"6": {"damage": "70", "speed": "1900", "projectile_hits": "10", "fire_interval_sec": "2.1", "ammo": "10"},
	"7": {"damage": "86", "speed": "2000", "projectile_hits": "11", "fire_interval_sec": "2.0", "ammo": "10"},
	"8": {"damage": "101", "speed": "2100", "projectile_hits": "12", "fire_interval_sec": "1.9", "ammo": "10"},
	"9": {"damage": "116", "speed": "2200", "projectile_hits": "13", "fire_interval_sec": "1.8", "ammo": "10"}
}

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

func _on_shoot() -> void:
	is_on_cooldown = true
	var cooldown := maxf(get_runtime_attack_cooldown(), 0.05)
	var damage_multiplier := branch_runtime.get_branch_projectile_damage_multiplier()
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()

	projectile_direction = get_aim_forward()
	if projectile_direction == Vector2.ZERO:
		return
	var runtime_damage: int = get_runtime_damage()
	var lethal_aim: bool = _lethal_aim_armed
	_lethal_aim_armed = false
	if lethal_aim:
		set_active_skill_visual_armed(false)
	if lethal_aim:
		damage_multiplier *= 3.5
	var shot_damage: int = maxi(1, int(round(float(runtime_damage) * damage_multiplier)))
	var maximum_distance_bonus: bool = consume_support_trigger() or _next_shot_max_distance_bonus
	_next_shot_max_distance_bonus = false
	_fire_hitscan(shot_damage, maximum_distance_bonus, lethal_aim)

func _fire_hitscan(base_shot_damage: int, force_maximum_distance_bonus: bool, lethal_aim: bool) -> void:
	var origin: Vector2 = get_muzzle_global_position()
	var result: Dictionary = HITSCAN_LINE.collect_ordered_targets(
		self, origin, projectile_direction, attack_range, hitscan_width * maxf(size, 0.01), hitscan_world_blocker_mask
	)
	var end_position: Vector2 = result.get("end_position", origin)
	HITSCAN_LINE.spawn_tracer(
		get_projectile_spawn_parent(), origin, end_position,
		hitscan_width * maxf(size, 0.01), tracer_duration_sec
	)
	var ordered_targets: Array = result.get("targets", [])
	var hit_limit: int = ordered_targets.size() if lethal_aim else mini(maxi(projectile_hits, 1), ordered_targets.size())
	var pierce_growth: int = _get_branch_pierce_damage_gain_per_hit()
	var max_growth_stacks: int = _get_branch_max_pierce_damage_stacks()
	for hit_index in range(hit_limit):
		var hit_entry := ordered_targets[hit_index] as Dictionary
		var target := hit_entry.get("target", null) as Node
		if target == null or not is_instance_valid(target):
			continue
		var growth_stacks: int = hit_index if max_growth_stacks <= 0 else mini(hit_index, max_growth_stacks)
		var damage_before_distance: int = maxi(1, base_shot_damage + pierce_growth * growth_stacks)
		var final_base_damage: int = _get_hitscan_distance_scaled_damage(
			target, damage_before_distance, force_maximum_distance_bonus, lethal_aim
		)
		var damage_data: DamageData = DamageManager.build_damage_data(
			self, final_base_damage, Attack.TYPE_PHYSICAL, {},
			DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.PROJECTILE
		)
		damage_data.dedupe_token = StringName("sniper_hitscan_%d_%d_%d" % [get_instance_id(), Time.get_ticks_usec(), target.get_instance_id()])
		damage_data.dedupe_window_sec = 0.02
		var damage_result: DamageResult = DamageManager.apply_to_target_result(target, damage_data)
		if not damage_result.applied:
			continue
		var owner_player := damage_data.source_player as Player
		if owner_player != null and is_instance_valid(owner_player):
			owner_player.apply_bonus_hit_if_needed(target)
		on_hit_target_with_damage_type(target, Attack.TYPE_PHYSICAL)

func _get_hitscan_distance_scaled_damage(
	target: Node,
	base_value: int,
	force_maximum: bool,
	lethal_aim: bool
) -> int:
	if lethal_aim:
		var target_node := target as Node2D
		var distance := global_position.distance_to(target_node.global_position) if target_node != null else 0.0
		var ratio := clampf((distance - NEAR_DISTANCE_THRESHOLD) / maxf(attack_range - NEAR_DISTANCE_THRESHOLD, 1.0), 0.0, 1.0)
		return max(1, int(round(float(maxi(base_value, 1)) * lerpf(1.0, 2.0, ratio))))
	return get_sniper_distance_scaled_damage(target, base_value, force_maximum)

func on_hit_target(target: Node) -> void:
	super.on_hit_target(target)
	_try_unlock_from_far_hit(target)
	branch_runtime.notify_branch_target_hit(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	super.on_hit_target_with_damage_type(target, damage_type)
	_try_unlock_from_far_hit(target)
	branch_runtime.notify_branch_target_hit(target)

func _try_unlock_from_far_hit(target: Node) -> void:
	var target_node := target as Node2D
	if target_node == null or not is_instance_valid(target_node):
		return
	var distance := global_position.distance_to(target_node.global_position)
	set_weapon_skill_unlock_progress(distance)
	if distance + 0.0001 >= far_hit_trigger_distance:
		mark_weapon_skill_ready()

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if event_name != &"on_cross_weapon_hit":
		return
	var target := detail.get("target", null) as Node
	if target == null or not is_instance_valid(target):
		return
	_next_shot_max_distance_bonus = true
	_emit_sniper_crossfire(target)

func _emit_sniper_crossfire(target: Node) -> void:
	var target_node := target as Node2D
	if target_node == null or not is_instance_valid(target_node):
		return
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player):
		return
	var distance := player.global_position.distance_to(target_node.global_position)
	var has_mark := _has_any_mark(target)
	emit_passive_trigger(&"sniper_far_hit_triggered", {
		"target": target,
		"distance": distance,
		"threshold": far_hit_trigger_distance,
		"forced_full_bonus_by_mark": has_mark,
		"trigger": "cross_weapon_hit",
		"refresh": "crossfire",
	}, PASSIVE_SCOPE_GLOBAL)

func get_passive_status() -> Dictionary:
	var progress := get_support_trigger_progress()
	var state := "ready" if is_support_trigger_ready() else "charging"
	return {
		"id": "sniper_far_hit_triggered",
		"display_name": "Far Hit",
		"state": state,
		"progress": progress,
		"ready": state == "ready",
		"condition_type": "support_charge",
		"required": WeaponTriggerRuntimeType.SUPPORT_CHARGE_DURATION_SEC,
		"trigger_hint": "support_charge",
		"refresh_hint": "support",
	}

func get_sniper_distance_scaled_damage(target: Node, base_damage: int, force_maximum: bool = false) -> int:
	var multiplier := FAR_DAMAGE_MULTIPLIER if force_maximum else _get_distance_damage_multiplier(target)
	return max(1, int(round(float(maxi(base_damage, 1)) * multiplier)))

func get_sniper_projectile_distance_scaled_damage(projectile: Node, target: Node, base_damage: int) -> int:
	if projectile != null and bool(projectile.get_meta(&"sniper_lethal_aim", false)):
		var target_node := target as Node2D
		var distance := global_position.distance_to(target_node.global_position) if target_node != null else 0.0
		var ratio := clampf((distance - NEAR_DISTANCE_THRESHOLD) / maxf(attack_range - NEAR_DISTANCE_THRESHOLD, 1.0), 0.0, 1.0)
		return max(1, int(round(float(maxi(base_damage, 1)) * lerpf(1.0, 2.0, ratio))))
	return get_sniper_distance_scaled_damage(target, base_damage, bool(projectile.get_meta(&"sniper_support_empowered", false)) if projectile != null else false)

func activate_weapon_skill_effect(_context: SkillActionContext) -> bool:
	_lethal_aim_armed = true
	set_active_skill_visual_armed(true, Color(1.0, 0.28, 0.28, 1.0))
	return true

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_lethal_aim_armed = false
	set_active_skill_visual_armed(false)

func _get_distance_damage_multiplier(target: Node) -> float:
	var target_node := target as Node2D
	if target_node == null or not is_instance_valid(target_node):
		return 1.0
	var far_distance: float = maxf(attack_range, NEAR_DISTANCE_THRESHOLD + 1.0)
	var distance: float = global_position.distance_to(target_node.global_position)
	var t: float = clampf((distance - NEAR_DISTANCE_THRESHOLD) / maxf(far_distance - NEAR_DISTANCE_THRESHOLD, 1.0), 0.0, 1.0)
	if _has_any_mark(target):
		t = 1.0
	return lerpf(1.0, FAR_DAMAGE_MULTIPLIER, t)

func _has_any_mark(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("has_any_mark"):
		return false
	return bool(target.call("has_any_mark"))

func _get_branch_pierce_damage_gain_per_hit() -> int:
	return branch_runtime.get_branch_pierce_damage_gain_per_hit()

func _get_branch_max_pierce_damage_stacks() -> int:
	return branch_runtime.get_branch_max_pierce_damage_stacks()

func _get_level_data(lv: String) -> Dictionary:
	return get_weapon_level_data(lv, weapon_data)
