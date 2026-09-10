extends Ranger

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const PERSISTENT_GROUND_AREA := preload("res://Player/Weapons/Geometry/persistent_ground_area.gd")
const WEAPON_SKILL_AREA := preload("res://Player/Weapons/Effects/weapon_skill_area.gd")

var ITEM_NAME := "Glacier Projector"
@export var cold_per_burst: float = -3.0
@export var heat_neutralize_rate: float = 7.0
@export_range(40.0, 1200.0, 1.0) var base_range: float = 260.0
@export_range(8.0, 240.0, 1.0) var trail_width: float = 44.0
@export_range(4.0, 96.0, 1.0) var trail_segment_spacing: float = 18.0
@export var trail_duration_sec: float = 1.6
@export var trail_scan_interval_sec: float = 0.12
@export var per_target_damage_cooldown_sec: float = 0.18
@export_range(1, 32, 1) var max_active_trails: int = 8
@export var cold_snap_freeze_duration_sec: float = 1.0
@export var boss_slow_duration_sec: float = 1.0
@export_range(0.05, 1.0, 0.05) var boss_slow_multiplier: float = 0.50
@export var debug_mode: bool = false

var _active_trails: Array[Node] = []
var _target_next_damage_msec: Dictionary = {}

var weapon_data: Dictionary = {
	"1": {"damage": "2", "fire_interval_sec": "0.2", "ammo": "20"},
	"2": {"damage": "2", "fire_interval_sec": "0.2", "ammo": "20"},
	"3": {"damage": "2", "fire_interval_sec": "0.2", "ammo": "20"},
	"4": {"damage": "4", "fire_interval_sec": "0.19", "ammo": "30"},
	"5": {"damage": "4", "fire_interval_sec": "0.19", "ammo": "30"},
	"6": {"damage": "4", "fire_interval_sec": "0.18", "ammo": "35"},
	"7": {"damage": "6", "fire_interval_sec": "0.18", "ammo": "35"},
	"8": {"damage": "6", "fire_interval_sec": "0.17", "ammo": "40"},
	"9": {"damage": "6", "fire_interval_sec": "0.17", "ammo": "40"}
}

func activate_weapon_skill_effect(_context: SkillActionContext) -> bool:
	var player := PlayerData.player as Node2D
	if player == null or not is_instance_valid(player):
		return false
	var domain := WEAPON_SKILL_AREA.new().setup(
		WEAPON_SKILL_AREA.Mode.WHITE_FROST_DOMAIN, self, player.global_position, 6.0, 210.0, 0.25
	)
	domain.follow_player = false
	get_projectile_spawn_parent().add_child(domain)
	return true

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

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(get_runtime_attack_cooldown(), 0.02)
	cooldown_timer.start()
	_spawn_ice_trail()

func _spawn_ice_trail() -> void:
	var forward: Vector2 = get_aim_forward()
	if forward == Vector2.ZERO:
		return
	_prune_active_trails()
	while _active_trails.size() >= maxi(max_active_trails, 1):
		var oldest: Node = _active_trails.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()
	var cold_snap_active: bool = consume_support_trigger()
	var trail: Node = PERSISTENT_GROUND_AREA.new().setup(
		self,
		get_muzzle_global_position(),
		forward,
		_get_effective_attack_range(),
		_get_effective_trail_width(),
		trail_segment_spacing,
		trail_duration_sec,
		trail_scan_interval_sec,
		cold_snap_active
	) as Node
	trail.tree_exited.connect(_prune_active_trails)
	_active_trails.append(trail)
	get_projectile_spawn_parent().add_child(trail)
	if cold_snap_active:
		_emit_cold_snap_attack_trigger([])

func apply_glacier_trail_tick(target: Node, apply_cold_snap: bool = false) -> bool:
	if target == null or not is_instance_valid(target) or not target.has_method("damaged"):
		return false
	var now: int = Time.get_ticks_msec()
	var target_id: int = target.get_instance_id()
	_prune_target_damage_ledger(now)
	if now < int(_target_next_damage_msec.get(target_id, 0)):
		return false
	_target_next_damage_msec[target_id] = now + int(maxf(per_target_damage_cooldown_sec, 0.02) * 1000.0)
	var damage_data: DamageData = DamageManager.build_damage_data(
		self, get_runtime_damage(), Attack.TYPE_FREEZE,
		{"amount": 0, "angle": Vector2.ZERO},
		DamageData.SOURCE_PLAYER_WEAPON, DamageDeliveryType.AREA
	)
	damage_data.dedupe_token = StringName("glacier_trail_%d_%d_%d" % [get_instance_id(), target_id, now])
	damage_data.dedupe_window_sec = maxf(per_target_damage_cooldown_sec, 0.02)
	var applied: bool = DamageManager.apply_to_target(target, damage_data)
	if not applied:
		return false
	on_hit_target_with_damage_type(target, Attack.TYPE_FREEZE)
	add_weapon_skill_unlock_progress(1.0)
	if apply_cold_snap:
		_apply_cold_snap_control(target)
	return true

func _prune_target_damage_ledger(now_msec: int) -> void:
	if _target_next_damage_msec.size() <= 256:
		return
	for target_id in _target_next_damage_msec.keys():
		if int(_target_next_damage_msec[target_id]) <= now_msec:
			_target_next_damage_msec.erase(target_id)

func supports_projectiles() -> bool:
	return false

func uses_continuous_automatic_fire() -> bool:
	return true

func get_automatic_fire_target_grace_sec() -> float:
	return 0.3

func request_automatic_fire() -> bool:
	return request_primary_fire()

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.disables_primary_fire():
			return
	if pressed and can_run_active_behavior():
		request_primary_fire()

func stop_automatic_fire() -> void:
	pass

func _apply_cold_snap_control(target: Node) -> void:
	var duration := maxf(cold_snap_freeze_duration_sec, 0.05)
	if _is_boss_target(target):
		duration = maxf(boss_slow_duration_sec, 0.05)
		var boss_multiplier := clampf(boss_slow_multiplier, 0.05, 1.0)
		_apply_control_status(target, boss_multiplier, duration)
		emit_passive_trigger(&"glacier_target_frozen", {
			"target": target, "duration": duration,
			"movement_multiplier": boss_multiplier, "boss_reduced": true,
		}, PASSIVE_SCOPE_GLOBAL)
		return
	_apply_freeze_status(target, duration)
	emit_passive_trigger(&"glacier_target_frozen", {
		"target": target, "duration": duration,
		"movement_multiplier": 0.0, "boss_reduced": false,
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
		"refresh": "support",
		"recharge_sec": WeaponTriggerRuntimeType.SUPPORT_CHARGE_DURATION_SEC,
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
		if behavior != null and is_instance_valid(behavior) and behavior.has_method("get_glacier_cold_snap_ammo_refund"):
			total_refund += maxi(int(behavior.call("get_glacier_cold_snap_ammo_refund")), 0)
	if total_refund <= 0:
		return 0
	var ammo_before := current_ammo
	current_ammo = mini(maxi(current_ammo + total_refund, 0), get_effective_magazine_capacity())
	return maxi(current_ammo - ammo_before, 0)

func get_passive_status() -> Dictionary:
	var recharge_sec := WeaponTriggerRuntimeType.SUPPORT_CHARGE_DURATION_SEC
	var progress := get_support_trigger_progress()
	var state := "ready" if is_support_trigger_ready() else "charging"
	return with_passive_charge_status({
		"id": "glacier_cold_snap_triggered",
		"display_name": "Cold Snap",
		"state": "armed" if state == "ready" else state,
		"ready": state == "ready",
		"trigger_hint": "next_attack",
		"refresh_hint": "support",
		"cooldown_remaining": recharge_sec * (1.0 - progress),
		"cooldown_duration": recharge_sec,
		"progress": progress,
	})

func _get_effective_attack_range() -> float:
	var level_range := float(get_weapon_level_data(level, weapon_data).get("range", base_range))
	return maxf(level_range * maxf(branch_runtime.get_branch_attack_range_multiplier(), 0.1), 1.0)

func _get_effective_trail_width() -> float:
	var multiplier := 1.0
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior != null and is_instance_valid(behavior) and behavior.has_method("get_glacier_trail_width_multiplier"):
			multiplier *= maxf(float(behavior.call("get_glacier_trail_width_multiplier")), 0.1)
	return get_effective_area_radius(trail_width * multiplier)

func _prune_active_trails() -> void:
	var retained: Array[Node] = []
	for trail in _active_trails:
		if trail != null and is_instance_valid(trail) and not trail.is_queued_for_deletion():
			retained.append(trail)
	_active_trails = retained

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	for trail in _active_trails:
		if trail != null and is_instance_valid(trail):
			trail.queue_free()
	_active_trails.clear()
	_target_next_damage_msec.clear()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if debug_mode:
		queue_redraw()

func _draw() -> void:
	if not debug_mode:
		return
	var width := _get_effective_trail_width()
	var length := _get_effective_attack_range()
	draw_rect(Rect2(Vector2(-width * 0.5, -length), Vector2(width, length)), Color(PALETTE.FREEZE, 0.14), true)
	draw_rect(Rect2(Vector2(-width * 0.5, -length), Vector2(width, length)), Color(PALETTE.PLAYER_PRIMARY, 0.58), false, 2.0)
