extends Ranger

const CONE_SPRAY_VFX_SCENE: PackedScene = preload("res://Player/Weapons/Effects/cone_spray_vfx.tscn")

@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Flamethrower"

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 40.0
@export_range(40.0, 1200.0, 1.0) var base_flame_range: float = 280.0
@export var heat_accumulation: float = 5.0
@export var max_heat: float = 80.0
@export var heat_cooldown_rate: float = 5.0
@export var heat_prepared_duration_sec: float = 10.0
@export var heat_prepared_damage_mul: float = 1.05
@export var heat_prepared_flat_damage_bonus: int = 1
@export var heat_prepared_icd_sec: float = 0.25

## Debug mode: 显示攻击范围扇形
@export var debug_mode: bool = false

var attack_range: float = 280.0
## 已攻击过的目标ID（每轮射击重置）
var _attacked_target_ids: Dictionary = {}
var _heat_prepared_ready_at_msec: int = 0
var _heat_prepared_reload_ready: bool = true
var _heat_prepared_accumulated_heat: float = 0.0
var _flame_vfx: Node
var _primary_fire_held: bool = false

var weapon_data := {
	"1": {"damage": "8", "fire_interval_sec": "0.30", "ammo": "20", "range": "260"},
	"2": {"damage": "10", "fire_interval_sec": "0.30", "ammo": "20", "range": "270"},
	"3": {"damage": "12", "fire_interval_sec": "0.30", "ammo": "20", "range": "285"},
	"4": {"damage": "14", "fire_interval_sec": "0.30", "ammo": "20", "range": "300"},
	"5": {"damage": "17", "fire_interval_sec": "0.25", "ammo": "20", "range": "320"},
	"6": {"damage": "20", "fire_interval_sec": "0.25", "ammo": "20", "range": "340"},
	"7": {"damage": "23", "fire_interval_sec": "0.25", "ammo": "20", "range": "365"},
	"8": {"damage": "26", "fire_interval_sec": "0.25", "ammo": "20", "range": "390"},
	"9": {"damage": "29", "fire_interval_sec": "0.25", "ammo": "20", "range": "415"}
}

func _ready() -> void:
	super._ready()
	_apply_fuse_sprite()
	_sync_detect_radius()
	_ensure_flame_vfx()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = get_weapon_level_data(lv, weapon_data)
	level = int(get_weapon_level_key(lv, weapon_data))
	base_damage = int(level_data["damage"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	attack_range = float(level_data.get("range", base_flame_range))
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()
	branch_runtime.notify_branch_level_applied(level)
	_sync_detect_radius()

func _on_shoot() -> void:
	is_on_cooldown = true
	var cooldown: float = get_effective_cooldown(attack_cooldown)
	cooldown *= branch_runtime.get_branch_cooldown_multiplier()
	cooldown_timer.wait_time = maxf(cooldown, 0.02)
	cooldown_timer.start()
	_emit_flame_burst()

func supports_projectiles() -> bool:
	return false

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	for behavior in branch_runtime.get_branch_behaviors():
		if behavior.disables_primary_fire():
			_primary_fire_held = false
			_stop_flame_vfx()
			return
	if not can_run_active_behavior():
		_primary_fire_held = false
		_stop_flame_vfx()
		return
	if not pressed:
		_primary_fire_held = false
		_stop_flame_vfx()
		return
	_primary_fire_held = true
	request_primary_fire()
	if not _can_maintain_held_flame_vfx():
		_stop_flame_vfx()
		return
	_refresh_held_flame_vfx()

func _emit_flame_burst() -> void:
	# 每轮射击开始时清空已攻击目标列表
	_attacked_target_ids.clear()

	if detect_area == null or not is_instance_valid(detect_area):
		return
	var forward := global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
	_refresh_flame_vfx(forward)
	var targets := _collect_targets_in_cone(forward)
	for target in targets:
		_apply_fire_damage(target)

func _apply_fire_damage(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("damaged"):
		return
	if _attacked_target_ids.has(target.get_instance_id()):
		return
	_attacked_target_ids[target.get_instance_id()] = true

	var runtime_damage: int = get_runtime_shot_damage()
	runtime_damage = max(1, int(round(float(runtime_damage) * branch_runtime.get_branch_damage_multiplier())))
	var knock_back := {
		"amount": 0,
		"angle": Vector2.ZERO
	}
	var damage_data := DamageManager.build_damage_data(
		self,
		runtime_damage,
		Attack.TYPE_FIRE,
		knock_back
	)
	DamageManager.apply_to_target(target, damage_data)

	# 调用 on_hit_target 触发武器的命中效果
	on_hit_target_with_damage_type(target, Attack.TYPE_FIRE)

func _collect_targets_in_cone(forward: Vector2) -> Array[Node]:
	var output: Array[Node] = []
	var touched_ids: Dictionary = {}
	var max_angle_rad := deg_to_rad(_get_effective_cone_half_angle_deg())
	var effective_range: float = _get_effective_attack_range()
	for area in detect_area.get_overlapping_areas():
		if not area is HurtBox:
			continue
		var hurt_box := area as HurtBox
		if not hurt_box.get_collision_layer_value(3):
			continue
		var target := hurt_box.get_owner() as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var target_id := target.get_instance_id()
		if touched_ids.has(target_id):
			continue
		var to_target := target.global_position - global_position
		var distance := to_target.length()
		if distance > effective_range:
			continue
		var dir := to_target.normalized()
		if absf(forward.angle_to(dir)) > max_angle_rad:
			continue
		touched_ids[target_id] = true
		output.append(target)
	return output

func _sync_detect_radius() -> void:
	if detect_area == null or not is_instance_valid(detect_area):
		return
	var shape_node := detect_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = maxf(_get_effective_attack_range(), 32.0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_flame_vfx_follow()
	if debug_mode:
		queue_redraw()

func _process_main_weapon_effect(_delta: float) -> void:
	pass

func _process_offhand_weapon_effect(_delta: float) -> void:
	pass

func _on_enter_main_weapon_role() -> void:
	pass

func register_shot_heat(multiplier: float = 1.0) -> void:
	var heat_before := get_heat_value()
	super.register_shot_heat(multiplier)
	if not is_main_weapon():
		return
	if not _heat_prepared_reload_ready:
		return
	var heat_after := get_heat_value()
	var added_heat := maxf(heat_after - heat_before, 0.0)
	if added_heat <= 0.0:
		return
	_heat_prepared_accumulated_heat += added_heat

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_heat_prepared_reload_ready = true
	_heat_prepared_ready_at_msec = 0
	_heat_prepared_accumulated_heat = 0.0

func get_passive_status() -> Dictionary:
	var required_heat := maxf(heat_max_value, 1.0)
	var current_heat := maxf(_heat_prepared_accumulated_heat, 0.0)
	var progress := clampf(current_heat / required_heat, 0.0, 1.0)
	var state := "charging"
	if not is_main_weapon():
		state = "inactive"
	elif not _heat_prepared_reload_ready:
		state = "waiting_refresh"
	elif current_heat >= required_heat:
		state = "ready_pending_action"
	return {
		"id": "flamethrower_heat_prepared",
		"display_name": "Heat Prepared",
		"state": state,
		"progress": progress,
		"current": current_heat,
		"required": required_heat,
		"ready": state == "ready_pending_action",
		"trigger_hint": "reload_started",
		"refresh_hint": "reload_finished",
	}

func _draw() -> void:
	if not debug_mode:
		return
	_draw_attack_range()

func _draw_attack_range() -> void:
	# _draw() 是在节点坐标系中绘制，武器旋转时内容会跟着旋转
	# 武器默认朝上(UP)，所以需要向左旋转90度(-PI/2)来对齐
	var half_angle_rad := deg_to_rad(_get_effective_cone_half_angle_deg())
	var offset_angle := -PI / 2.0  # 向左旋转90度
	var start_angle := offset_angle - half_angle_rad
	var end_angle := offset_angle + half_angle_rad
	var effective_range: float = _get_effective_attack_range()

	# 扇形填充颜色
	var fill_color := Color(1.0, 0.4, 0.0, 0.15)
	# 扇形轮廓颜色
	var outline_color := Color(1.0, 0.4, 0.0, 0.6)

	# 绘制扇形填充
	draw_arc(Vector2.ZERO, effective_range, start_angle, end_angle, 32, fill_color, -1.0)
	# 绘制扇形轮廓
	draw_arc(Vector2.ZERO, effective_range, start_angle, end_angle, 32, outline_color, 2.0)
	# 绘制中心半径线
	draw_line(Vector2.ZERO, Vector2.UP * effective_range, outline_color, 2.0)
	# 绘制边界半径线
	draw_line(Vector2.ZERO, Vector2.UP.rotated(-half_angle_rad) * effective_range, outline_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(half_angle_rad) * effective_range, outline_color, 1.0)

func _get_effective_attack_range() -> float:
	var range_multiplier: float = branch_runtime.get_branch_attack_range_multiplier()
	return maxf(attack_range * maxf(range_multiplier, 0.1), 1.0)

func _get_effective_cone_half_angle_deg() -> float:
	var angle_multiplier: float = 1.0
	for behavior in branch_runtime.get_branch_behaviors():
		angle_multiplier *= maxf(behavior.get_cone_half_angle_multiplier(), 0.1)
	return maxf(cone_half_angle_deg * maxf(angle_multiplier, 0.1), 1.0)

func _ensure_flame_vfx() -> void:
	if _flame_vfx != null and is_instance_valid(_flame_vfx):
		return
	if CONE_SPRAY_VFX_SCENE == null:
		return
	var instance: Node = CONE_SPRAY_VFX_SCENE.instantiate()
	if instance == null:
		return
	_flame_vfx = instance
	_flame_vfx.name = "FlameSprayVfx"
	add_child(_flame_vfx)

func _refresh_flame_vfx(forward: Vector2) -> void:
	_ensure_flame_vfx()
	if _flame_vfx == null or not is_instance_valid(_flame_vfx):
		return
	if _flame_vfx.has_method("start_or_refresh"):
		_flame_vfx.call(
			"start_or_refresh",
			global_position,
			forward,
			_get_effective_attack_range(),
			_get_effective_cone_half_angle_deg()
		)

func _refresh_held_flame_vfx() -> void:
	if not _primary_fire_held:
		return
	if not _can_maintain_held_flame_vfx():
		_stop_flame_vfx()
		return
	if _flame_vfx == null or not is_instance_valid(_flame_vfx):
		return
	if not _flame_vfx.has_method("is_visible_or_fading"):
		return
	if not bool(_flame_vfx.call("is_visible_or_fading")):
		return
	var forward := global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
	_refresh_flame_vfx(forward)

func _update_flame_vfx_follow() -> void:
	if _flame_vfx == null or not is_instance_valid(_flame_vfx):
		return
	if not _flame_vfx.has_method("is_visible_or_fading"):
		return
	if not bool(_flame_vfx.call("is_visible_or_fading")):
		return
	var forward := global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
	if _flame_vfx.has_method("update_aim"):
		_flame_vfx.call(
			"update_aim",
			global_position,
			forward,
			_get_effective_attack_range(),
			_get_effective_cone_half_angle_deg()
		)

func _can_maintain_held_flame_vfx() -> bool:
	if not is_attack_phase_allowed():
		return false
	if not can_fire_with_heat():
		return false
	if not can_fire_with_ammo():
		return false
	return true

func _stop_flame_vfx() -> void:
	if _flame_vfx == null or not is_instance_valid(_flame_vfx):
		return
	if _flame_vfx.has_method("stop"):
		_flame_vfx.call("stop")

func _try_apply_heat_prepared() -> void:
	if not is_main_weapon():
		_heat_prepared_accumulated_heat = 0.0
		return
	if not _heat_prepared_reload_ready:
		_heat_prepared_accumulated_heat = 0.0
		return
	var required_heat := maxf(heat_max_value, 1.0)
	if _heat_prepared_accumulated_heat < required_heat:
		_heat_prepared_accumulated_heat = 0.0
		return
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec < _heat_prepared_ready_at_msec:
		return
	_heat_prepared_ready_at_msec = now_msec + int(maxf(heat_prepared_icd_sec, 0.0) * 1000.0)
	_heat_prepared_reload_ready = false
	if player.has_method("apply_heat_prepared"):
		player.call(
			"apply_heat_prepared",
			maxf(heat_prepared_duration_sec, 0.05),
			maxf(heat_prepared_damage_mul, 0.05),
			maxi(heat_prepared_flat_damage_bonus, 0)
		)
	emit_passive_trigger(&"flamethrower_heat_prepared", {
		"trigger": "reload_started_after_accumulated_self_heat",
		"damage_type": Attack.TYPE_FIRE,
		"accumulated_heat": _heat_prepared_accumulated_heat,
		"required_heat": required_heat,
		"duration": maxf(heat_prepared_duration_sec, 0.05),
		"damage_multiplier": maxf(heat_prepared_damage_mul, 0.05),
		"flat_damage_bonus": maxi(heat_prepared_flat_damage_bonus, 0),
		"refresh": "reload",
	}, PASSIVE_SCOPE_GLOBAL)

func _on_passive_event(event_name: StringName, detail: Dictionary) -> void:
	super._on_passive_event(event_name, detail)
	if detail.get("source_weapon", null) != self:
		return
	if event_name == &"on_reload_started":
		_try_apply_heat_prepared()
		_heat_prepared_accumulated_heat = 0.0
		_heat_prepared_reload_ready = false
		return
	if event_name == &"on_reload_finished":
		_heat_prepared_reload_ready = true
