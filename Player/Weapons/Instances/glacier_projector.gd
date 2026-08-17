extends Ranger

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const GLACIER_SPRAY_VFX_SCENE: PackedScene = preload("res://Player/Weapons/Effects/glacier_spray_vfx.tscn")

@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Glacier Projector"
@export var cold_per_burst: float = -3.0
@export var heat_neutralize_rate: float = 7.0

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 15.0
@export_range(40.0, 1200.0, 1.0) var base_range: float = 200.0
@export var cold_snap_recharge_sec: float = 6.0
@export var cold_snap_freeze_duration_sec: float = 1.0
@export var boss_slow_duration_sec: float = 1.0
@export_range(0.05, 1.0, 0.05) var boss_slow_multiplier: float = 0.50
@export var debug_mode: bool = false

var _attacked_target_ids: Dictionary = {}
var _cold_snap_recharge_remaining_sec: float = 0.0
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
	configure_heat(cold_per_burst, Heat.MAX_HEAT, heat_neutralize_rate)
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
	var forward: Vector2 = get_aim_forward()
	if forward == Vector2.ZERO:
		return
	_refresh_glacier_vfx(forward)
	var targets: Array[Node] = _collect_targets_in_cone(forward)
	var cold_snap_active := _consume_cold_snap_for_next_attack()
	for target in targets:
		_apply_freeze_damage(target, cold_snap_active)
	if cold_snap_active:
		_emit_cold_snap_attack_trigger(targets)

func _apply_freeze_damage(target: Node, cold_snap_active: bool = false) -> void:
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
	if cold_snap_active:
		_apply_cold_snap_control(target)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	super.on_hit_target_with_damage_type(target, damage_type)

func _consume_cold_snap_for_next_attack() -> bool:
	if not is_passive_ready():
		return false
	consume_passive_charge()
	_cold_snap_recharge_remaining_sec = maxf(cold_snap_recharge_sec, 0.0)
	return true

func _apply_cold_snap_control(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var duration := maxf(cold_snap_freeze_duration_sec, 0.05)
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

func _emit_cold_snap_attack_trigger(targets: Array[Node]) -> void:
	var ammo_refunded := _refund_ammo_from_cold_snap_branches()
	emit_passive_trigger(&"glacier_cold_snap_triggered", {
		"trigger": "next_attack_fired",
		"targets": targets,
		"target_count": targets.size(),
		"trigger_damage_type": Attack.TYPE_FREEZE,
		"refresh": "auto_or_reload",
		"recharge_sec": maxf(cold_snap_recharge_sec, 0.0),
		"freeze_duration": maxf(cold_snap_freeze_duration_sec, 0.05),
		"boss_slow_multiplier": clampf(boss_slow_multiplier, 0.05, 1.0),
		"boss_slow_duration": maxf(boss_slow_duration_sec, 0.05),
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
		"state": "armed" if state == "ready" else state,
		"ready": state == "ready",
		"trigger_hint": "next_attack",
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
	_update_glacier_vfx_follow()
	if debug_mode:
		queue_redraw()

func refresh_passive_on_reload() -> void:
	super.refresh_passive_on_reload()
	_cold_snap_recharge_remaining_sec = 0.0

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_cold_snap_recharge_remaining_sec = 0.0
	passive_controller.force_ready()

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
	var forward := get_aim_forward()
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
	var forward := get_aim_forward()
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
	var fill_color := Color(PALETTE.FREEZE, 0.14)
	var outline_color := Color(PALETTE.PLAYER_PRIMARY, 0.58)
	draw_arc(Vector2.ZERO, effective_range, start_angle, end_angle, 32, fill_color, -1.0)
	draw_arc(Vector2.ZERO, effective_range, start_angle, end_angle, 32, outline_color, 2.0)
	draw_line(Vector2.ZERO, Vector2.UP * effective_range, outline_color, 2.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(-half_angle_rad) * effective_range, outline_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(half_angle_rad) * effective_range, outline_color, 1.0)
