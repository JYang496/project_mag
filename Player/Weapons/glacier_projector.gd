extends Ranger

const FROST_CONTACT_WINDOW_SEC: float = 0.35
const GLACIER_SPRAY_VFX_SCENE: PackedScene = preload("res://Player/Weapons/Effects/glacier_spray_vfx.tscn")

@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Glacier Projector"

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 15.0
@export_range(40.0, 1200.0, 1.0) var base_range: float = 200.0
@export var cold_snap_damage_ratio: float = 0.35
@export var cold_snap_recharge_sec: float = 6.0
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
	sync_stats()
	notify_branch_level_applied(level)
	_sync_detect_radius()

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(get_effective_cooldown(attack_cooldown), 0.02)
	cooldown_timer.start()
	_emit_glacier_burst()

func supports_projectiles() -> bool:
	return false

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	for behavior in get_branch_behaviors():
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
		{"amount": 0, "angle": Vector2.ZERO}
	)
	DamageManager.apply_to_target(target, damage_data)
	on_hit_target_with_damage_type(target, Attack.TYPE_FREEZE)

func on_hit_target_with_damage_type(target: Node, damage_type: StringName) -> void:
	super.on_hit_target_with_damage_type(target, damage_type)
	_try_trigger_main_freeze_hit(target, damage_type)

func _try_trigger_main_freeze_hit(target: Node, damage_type: StringName) -> void:
	if not is_main_weapon():
		return
	if Attack.normalize_damage_type(damage_type) != Attack.TYPE_FREEZE:
		return
	if not is_offhand_skill_ready():
		return
	_trigger_cold_snap(target)

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
		owner_player
	)
	DamageManager.apply_to_target(target, damage_data)
	_try_emit_cold_snap_trigger(target)

func _try_emit_cold_snap_trigger(target: Node) -> void:
	if not is_main_weapon():
		return
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
	for behavior in get_branch_behaviors():
		if behavior == null or not is_instance_valid(behavior):
			continue
		if not behavior.has_method("get_glacier_cold_snap_ammo_refund"):
			continue
		total_refund += maxi(int(behavior.call("get_glacier_cold_snap_ammo_refund")), 0)
	if total_refund <= 0:
		return 0
	var ammo_before := current_ammo
	current_ammo = mini(maxi(current_ammo + total_refund, 0), max(0, magazine_capacity))
	return maxi(current_ammo - ammo_before, 0)

func get_passive_status() -> Dictionary:
	var recharge_sec := maxf(cold_snap_recharge_sec, 0.0)
	var cooldown_remaining := maxf(_cold_snap_recharge_remaining_sec, 0.0)
	var state := "ready"
	if not is_main_weapon():
		state = "inactive"
	elif not is_passive_ready():
		state = "cooldown"
	return {
		"id": "glacier_cold_snap_triggered",
		"display_name": "Cold Snap",
		"state": state,
		"ready": state == "ready",
		"trigger_hint": "freeze_hit",
		"refresh_hint": "time_or_reload",
		"cooldown_remaining": cooldown_remaining,
		"cooldown_duration": recharge_sec,
		"progress": 1.0 if recharge_sec <= 0.0 else 1.0 - clampf(cooldown_remaining / recharge_sec, 0.0, 1.0),
	}

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
	return maxf(level_range * maxf(get_branch_attack_range_multiplier(), 0.1), 1.0)

func _get_effective_cone_half_angle_deg() -> float:
	var angle_multiplier: float = 1.0
	for behavior in get_branch_behaviors():
		angle_multiplier *= maxf(behavior.get_cone_half_angle_multiplier(), 0.1)
	return maxf(cone_half_angle_deg * maxf(angle_multiplier, 0.1), 1.0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_cold_snap_recharge(delta)
	_update_glacier_vfx_follow()
	if debug_mode:
		queue_redraw()

func refresh_passive_on_reload() -> void:
	super.refresh_passive_on_reload()
	_cold_snap_recharge_remaining_sec = 0.0

func _update_cold_snap_recharge(delta: float) -> void:
	if is_passive_ready():
		_cold_snap_recharge_remaining_sec = 0.0
		return
	_cold_snap_recharge_remaining_sec = maxf(_cold_snap_recharge_remaining_sec - maxf(delta, 0.0), 0.0)
	if _cold_snap_recharge_remaining_sec <= 0.0:
		_offhand_skill_ready = true

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
