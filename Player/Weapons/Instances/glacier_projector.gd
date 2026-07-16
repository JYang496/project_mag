extends Ranger

const FROST_CONTACT_WINDOW_SEC: float = 0.35
const GLACIER_SPRAY_VFX_SCENE: PackedScene = preload("res://Player/Weapons/Effects/glacier_spray_vfx.tscn")

@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Glacier Projector"

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 15.0
@export_range(40.0, 1200.0, 1.0) var base_range: float = 200.0
@export var cold_snap_damage_ratio: float = 0.35
@export var cold_snap_recharge_sec: float = 6.0
@export_group("Chill Control")
@export_range(2, 10, 1) var chill_stacks_to_freeze: int = 5
@export var chill_window_sec: float = 1.2
@export_range(0.01, 0.2, 0.01) var chill_slow_per_stack: float = 0.06
@export var freeze_target_icd_sec: float = 3.0
@export var normal_freeze_duration_sec: float = 0.7
@export var elite_freeze_duration_sec: float = 0.35
@export var boss_slow_duration_sec: float = 0.5
@export_range(0.05, 1.0, 0.05) var boss_slow_multiplier: float = 0.65
@export var cold_snap_radius: float = 110.0
@export_range(1, 4, 1) var cold_snap_chill_stacks: int = 2
@export_group("")
@export var debug_mode: bool = false

var _attacked_target_ids: Dictionary = {}
var _cold_snap_recharge_remaining_sec: float = 0.0
var _chill_states: Dictionary = {}
var _freeze_icd_until_msec: Dictionary = {}
var _glacier_vfx: Node
var _primary_fire_held: bool = false

var weapon_data: Dictionary = {
	"1": {"damage": "2", "fire_interval_sec": "0.2", "ammo": "50"},
	"2": {"damage": "2", "fire_interval_sec": "0.2", "ammo": "50"},
	"3": {"damage": "2", "fire_interval_sec": "0.2", "ammo": "50"},
	"4": {"damage": "4", "fire_interval_sec": "0.19", "ammo": "60"},
	"5": {"damage": "4", "fire_interval_sec": "0.19", "ammo": "60"},
	"6": {"damage": "4", "fire_interval_sec": "0.18", "ammo": "65"},
	"7": {"damage": "6", "fire_interval_sec": "0.18", "ammo": "65"},
	"8": {"damage": "6", "fire_interval_sec": "0.17", "ammo": "70"},
	"9": {"damage": "6", "fire_interval_sec": "0.17", "ammo": "70"}
}

func _ready() -> void:
	super._ready()
	_sync_detect_radius()
	_ensure_glacier_vfx()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = get_weapon_level_data(lv, weapon_data)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)
	_sync_detect_radius()

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(get_effective_cooldown(attack_cooldown), 0.02)
	cooldown_timer.start()
	_emit_glacier_burst()

func supports_projectiles() -> bool:
	return false

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.disables_primary_fire():
			_primary_fire_held = false
			_stop_glacier_vfx()
			return
	if not can_run_active_behavior():
		_primary_fire_held = false
		_stop_glacier_vfx()
		return
	if not pressed:
		_primary_fire_held = false
		_stop_glacier_vfx()
		return
	_primary_fire_held = true
	request_primary_fire()
	if not _can_maintain_held_glacier_vfx():
		_stop_glacier_vfx()
		return
	_refresh_held_glacier_vfx()

func _emit_glacier_burst() -> void:
	_attacked_target_ids.clear()
	if detect_area == null or not is_instance_valid(detect_area):
		return
	var forward: Vector2 = global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
	_refresh_glacier_vfx(forward)
	var targets: Array[Node] = _collect_targets_in_cone(forward)
	for target in targets:
		_apply_freeze_damage(target)

func _apply_freeze_damage(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("damaged"):
		return
	if _attacked_target_ids.has(target.get_instance_id()):
		return
	_attacked_target_ids[target.get_instance_id()] = true

	var runtime_damage: int = get_runtime_shot_damage()
	var damage_data: DamageData = DamageManager.build_damage_data(
		self,
		runtime_damage,
		Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.AREA
	)
	DamageManager.apply_to_target(target, damage_data)
	on_hit_target_with_damage_type(target, Attack.TYPE_FREEZE)
	_apply_chill_hit(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	super.on_hit_target_with_damage_type(target, damage_type)

func _apply_chill_hit(target: Node, added_stacks: int = 1, can_complete_freeze: bool = true) -> void:
	if target == null or not is_instance_valid(target):
		return
	var now_msec := Time.get_ticks_msec()
	var target_id := target.get_instance_id()
	var state: Dictionary = _chill_states.get(target_id, {})
	var expires_msec := int(state.get("expires_msec", 0))
	var stacks := int(state.get("stacks", 0)) if now_msec <= expires_msec else 0
	stacks += maxi(added_stacks, 0)
	var threshold := maxi(chill_stacks_to_freeze, 2)
	if not can_complete_freeze:
		stacks = mini(stacks, threshold - 1)
	_chill_states[target_id] = {
		"stacks": stacks,
		"expires_msec": now_msec + int(maxf(chill_window_sec, 0.1) * 1000.0),
		"target": weakref(target),
	}
	_apply_control_status(target, clampf(1.0 - float(mini(stacks, threshold - 1)) * chill_slow_per_stack, 0.05, 1.0), chill_window_sec)
	if stacks < threshold or not can_complete_freeze:
		return
	var freeze_ready_msec := int(_freeze_icd_until_msec.get(target_id, 0))
	if now_msec < freeze_ready_msec:
		_chill_states[target_id]["stacks"] = threshold - 1
		return
	_chill_states.erase(target_id)
	_freeze_icd_until_msec[target_id] = now_msec + int(maxf(freeze_target_icd_sec, 0.0) * 1000.0)
	_apply_completed_freeze(target)
	if is_offhand_skill_ready():
		_trigger_cold_snap(target)

func _apply_completed_freeze(target: Node) -> void:
	var duration := maxf(normal_freeze_duration_sec, 0.05)
	if _is_boss_target(target):
		duration = maxf(boss_slow_duration_sec, 0.05)
		var boss_multiplier := clampf(boss_slow_multiplier, 0.05, 1.0)
		_apply_control_status(target, boss_multiplier, duration)
		emit_passive_trigger(&"glacier_target_frozen", {
			"target": target,
			"duration": duration,
			"movement_multiplier": boss_multiplier,
			"boss_reduced": true,
		}, PASSIVE_SCOPE_GLOBAL)
		return
	elif _is_elite_target(target):
		duration = maxf(elite_freeze_duration_sec, 0.05)
	_apply_freeze_status(target, duration)
	emit_passive_trigger(&"glacier_target_frozen", {
		"target": target,
		"duration": duration,
		"movement_multiplier": 0.0,
		"boss_reduced": false,
	}, PASSIVE_SCOPE_GLOBAL)

func _apply_freeze_status(target: Node, duration: float) -> void:
	var freeze_duration := maxf(duration, 0.05)
	if target.has_method("apply_status_payload"):
		target.call("apply_status_payload", &"stun", {"duration": freeze_duration})
	elif target.has_method("apply_stun"):
		target.call("apply_stun", freeze_duration)
	else:
		_apply_control_status(target, 0.05, freeze_duration)

func _apply_control_status(target: Node, multiplier: float, duration: float) -> void:
	var payload := {
		"multiplier": clampf(multiplier, 0.05, 1.0),
		"duration": maxf(duration, 0.05),
	}
	if target.has_method("apply_status_payload"):
		target.call("apply_status_payload", &"slow", payload)
	elif target.has_method("apply_slow"):
		target.call("apply_slow", payload["multiplier"], payload["duration"])

func _is_boss_target(target: Node) -> bool:
	if target.is_in_group(&"boss"):
		return true
	if target is BaseEnemy:
		return bool((target as BaseEnemy).is_boss)
	return bool(target.get_meta(&"is_boss", false))

func _is_elite_target(target: Node) -> bool:
	if target is EliteEnemy:
		return true
	if target is BaseEnemy:
		return (target as BaseEnemy).has_spawn_tag(BaseEnemy.SPAWN_TAG_ELITE)
	return target.is_in_group(&"elite") or bool(target.get_meta(&"is_elite", false))

func _trigger_cold_snap(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var snap_damage: int = max(1, int(round(float(get_runtime_shot_damage()) * maxf(cold_snap_damage_ratio, 0.0))))
	var owner_player: Node = DamageManager.resolve_source_player(self)
	var damage_data: DamageData = DamageData.new().setup(
		snap_damage,
		Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		self,
		owner_player,
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.AREA
	)
	DamageManager.apply_to_target(target, damage_data)
	_seed_cold_snap_chill(target)
	_try_emit_cold_snap_trigger(target)

func _seed_cold_snap_chill(frozen_target: Node) -> void:
	if detect_area == null or not is_instance_valid(detect_area):
		return
	if not frozen_target is Node2D:
		return
	var frozen_position := (frozen_target as Node2D).global_position
	var touched_ids: Dictionary = {}
	for area in detect_area.get_overlapping_areas():
		if not area is HurtBox:
			continue
		var nearby := (area as HurtBox).get_damage_target() as Node2D
		if nearby == null or nearby == frozen_target or not is_instance_valid(nearby):
			continue
		var nearby_id := nearby.get_instance_id()
		if touched_ids.has(nearby_id):
			continue
		if nearby.global_position.distance_to(frozen_position) > maxf(cold_snap_radius, 1.0):
			continue
		touched_ids[nearby_id] = true
		_apply_chill_hit(nearby, maxi(cold_snap_chill_stacks, 1), false)

func _try_emit_cold_snap_trigger(target: Node) -> void:
	if not is_offhand_skill_ready():
		return
	notify_offhand_skill_triggered(0.0)
	_cold_snap_recharge_remaining_sec = maxf(cold_snap_recharge_sec, 0.0)
	var ammo_refunded := _refund_ammo_from_cold_snap_branches()
	emit_passive_trigger(&"glacier_cold_snap_triggered", {
		"target": target,
		"cold_snap_damage_ratio": maxf(cold_snap_damage_ratio, 0.0),
		"trigger_damage_type": Attack.TYPE_FREEZE,
		"refresh": "auto_or_reload",
		"recharge_sec": maxf(cold_snap_recharge_sec, 0.0),
		"ammo_refunded": ammo_refunded,
	}, PASSIVE_SCOPE_GLOBAL)

func _refund_ammo_from_cold_snap_branches() -> int:
	if not uses_ammo_system():
		return 0
	var total_refund := 0
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior == null or not is_instance_valid(behavior):
			continue
		if not behavior.has_method("get_glacier_cold_snap_ammo_refund"):
			continue
		total_refund += maxi(int(behavior.call("get_glacier_cold_snap_ammo_refund")), 0)
	if total_refund <= 0:
		return 0
	var ammo_before := current_ammo
	current_ammo = mini(maxi(current_ammo + total_refund, 0), get_effective_magazine_capacity())
	return maxi(current_ammo - ammo_before, 0)

func get_passive_status() -> Dictionary:
	var recharge_sec := maxf(cold_snap_recharge_sec, 0.0)
	var cooldown_remaining := maxf(_cold_snap_recharge_remaining_sec, 0.0)
	var state := "ready"
	if not is_passive_ready():
		state = "cooldown"
	return with_passive_charge_status({
		"id": "glacier_cold_snap_triggered",
		"display_name": "Cold Snap",
		"state": state,
		"ready": state == "ready",
		"trigger_hint": "freeze_hit",
		"refresh_hint": "time_or_reload",
		"cooldown_remaining": cooldown_remaining,
		"cooldown_duration": recharge_sec,
		"progress": 1.0 if recharge_sec <= 0.0 else 1.0 - clampf(cooldown_remaining / recharge_sec, 0.0, 1.0),
	})

func _collect_targets_in_cone(forward: Vector2) -> Array[Node]:
	var output: Array[Node] = []
	var touched_ids: Dictionary = {}
	var effective_range := _get_effective_attack_range()
	var max_angle_rad: float = deg_to_rad(_get_effective_cone_half_angle_deg())
	for area in detect_area.get_overlapping_areas():
		if not area is HurtBox:
			continue
		var hurt_box: HurtBox = area as HurtBox
		if not hurt_box.get_collision_layer_value(3):
			continue
		var target: Node2D = hurt_box.get_owner() as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var target_id: int = target.get_instance_id()
		if touched_ids.has(target_id):
			continue
		var to_target: Vector2 = target.global_position - global_position
		var distance: float = to_target.length()
		if distance > effective_range:
			continue
		var dir: Vector2 = to_target.normalized()
		if absf(forward.angle_to(dir)) > max_angle_rad:
			continue
		touched_ids[target_id] = true
		output.append(target)
	return output

func _sync_detect_radius() -> void:
	if detect_area == null or not is_instance_valid(detect_area):
		return
	var shape_node: CollisionShape2D = detect_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle: CircleShape2D = shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = maxf(_get_effective_attack_range(), 32.0)

func _get_effective_attack_range() -> float:
	var level_range := float(get_weapon_level_data(level, weapon_data).get("range", base_range))
	return maxf(level_range * maxf(branch_runtime.get_branch_attack_range_multiplier(), 0.1), 1.0)

func _get_effective_cone_half_angle_deg() -> float:
	var angle_multiplier: float = 1.0
	for behavior in branch_runtime.get_branch_behaviors():
		angle_multiplier *= maxf(behavior.get_cone_half_angle_multiplier(), 0.1)
	return get_effective_cone_half_angle(cone_half_angle_deg * maxf(angle_multiplier, 0.1))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_cold_snap_recharge(delta)
	_prune_chill_states()
	_update_glacier_vfx_follow()
	if debug_mode:
		queue_redraw()

func _prune_chill_states() -> void:
	var now_msec := Time.get_ticks_msec()
	for target_id in _chill_states.keys():
		var state: Dictionary = _chill_states[target_id]
		var target_ref: WeakRef = state.get("target") as WeakRef
		if now_msec > int(state.get("expires_msec", 0)) or target_ref == null or target_ref.get_ref() == null:
			_chill_states.erase(target_id)
	for target_id in _freeze_icd_until_msec.keys():
		if now_msec >= int(_freeze_icd_until_msec[target_id]):
			_freeze_icd_until_msec.erase(target_id)

func refresh_passive_on_reload() -> void:
	super.refresh_passive_on_reload()
	_cold_snap_recharge_remaining_sec = 0.0

func _update_cold_snap_recharge(delta: float) -> void:
	if is_passive_ready():
		_cold_snap_recharge_remaining_sec = 0.0
		return
	_cold_snap_recharge_remaining_sec = maxf(_cold_snap_recharge_remaining_sec - maxf(delta, 0.0), 0.0)
	if _cold_snap_recharge_remaining_sec <= 0.0:
		passive_controller.force_ready()

func _ensure_glacier_vfx() -> void:
	if _glacier_vfx != null and is_instance_valid(_glacier_vfx):
		return
	if GLACIER_SPRAY_VFX_SCENE == null:
		return
	var instance: Node = GLACIER_SPRAY_VFX_SCENE.instantiate()
	if instance == null:
		return
	_glacier_vfx = instance
	_glacier_vfx.name = "GlacierSprayVfx"
	add_child(_glacier_vfx)

func _refresh_glacier_vfx(forward: Vector2) -> void:
	_ensure_glacier_vfx()
	if _glacier_vfx == null or not is_instance_valid(_glacier_vfx):
		return
	if _glacier_vfx.has_method("start_or_refresh"):
		_glacier_vfx.call(
			"start_or_refresh",
			global_position,
			forward,
			_get_effective_attack_range(),
			_get_effective_cone_half_angle_deg()
		)

func _refresh_held_glacier_vfx() -> void:
	if not _primary_fire_held:
		return
	if not _can_maintain_held_glacier_vfx():
		_stop_glacier_vfx()
		return
	if _glacier_vfx == null or not is_instance_valid(_glacier_vfx):
		return
	if not _glacier_vfx.has_method("is_visible_or_fading"):
		return
	if not bool(_glacier_vfx.call("is_visible_or_fading")):
		return
	var forward := global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
	_refresh_glacier_vfx(forward)

func _update_glacier_vfx_follow() -> void:
	if _glacier_vfx == null or not is_instance_valid(_glacier_vfx):
		return
	if not _glacier_vfx.has_method("is_visible_or_fading"):
		return
	if not bool(_glacier_vfx.call("is_visible_or_fading")):
		return
	var forward := global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
	if _glacier_vfx.has_method("update_aim"):
		_glacier_vfx.call(
			"update_aim",
			global_position,
			forward,
			_get_effective_attack_range(),
			_get_effective_cone_half_angle_deg()
		)

func _can_maintain_held_glacier_vfx() -> bool:
	if not is_attack_phase_allowed():
		return false
	if not can_fire_with_heat():
		return false
	if not can_fire_with_ammo():
		return false
	return true

func _stop_glacier_vfx() -> void:
	if _glacier_vfx == null or not is_instance_valid(_glacier_vfx):
		return
	if _glacier_vfx.has_method("stop"):
		_glacier_vfx.call("stop")

func _draw() -> void:
	if not debug_mode:
		return
	_draw_attack_range()

func _draw_attack_range() -> void:
	var effective_range := _get_effective_attack_range()
	var half_angle_rad: float = deg_to_rad(_get_effective_cone_half_angle_deg())
	var offset_angle: float = -PI / 2.0
	var start_angle: float = offset_angle - half_angle_rad
	var end_angle: float = offset_angle + half_angle_rad
	var fill_color := Color(0.35, 0.85, 1.0, 0.15)
	var outline_color := Color(0.35, 0.85, 1.0, 0.7)
	draw_arc(Vector2.ZERO, effective_range, start_angle, end_angle, 32, fill_color, -1.0)
	draw_arc(Vector2.ZERO, effective_range, start_angle, end_angle, 32, outline_color, 2.0)
	draw_line(Vector2.ZERO, Vector2.UP * effective_range, outline_color, 2.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(-half_angle_rad) * effective_range, outline_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(half_angle_rad) * effective_range, outline_color, 1.0)
