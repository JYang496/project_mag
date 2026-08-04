extends Ranger

const PALETTE := preload("res://Combat/visual/combat_visual_palette.gd")
const CONE_SPRAY_VFX_SCENE: PackedScene = preload("res://Player/Weapons/Effects/cone_spray_vfx.tscn")

@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Flamethrower"

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 40.0
@export_range(40.0, 1200.0, 1.0) var base_flame_range: float = 180.0
@export var heat_accumulation: float = 5.0
@export var max_heat: float = 80.0
@export var heat_cooldown_rate: float = 5.0
@export_range(0.1, 60.0, 0.1) var fire_duration_required_sec: float = 5.0
@export var heat_prepared_duration_sec: float = 10.0
@export_range(0.0, 2.0, 0.01) var heat_prepared_fire_damage_bonus_per_stack: float = 0.10
@export_range(1, 10, 1) var heat_prepared_max_stacks: int = 2

## Debug mode: 显示攻击范围扇形
@export var debug_mode: bool = false

var attack_range: float = 180.0
## 已攻击过的目标ID（每轮射击重置）
var _attacked_target_ids: Dictionary = {}
var _heat_prepared_firing_elapsed_sec: float = 0.0
var _flame_vfx: Node
var _primary_fire_held: bool = false

var weapon_data := {
	"1": {"damage": "8", "fire_interval_sec": "0.30", "ammo": "20", "range": "180"},
	"2": {"damage": "10", "fire_interval_sec": "0.30", "ammo": "20", "range": "190"},
	"3": {"damage": "12", "fire_interval_sec": "0.30", "ammo": "20", "range": "200"},
	"4": {"damage": "14", "fire_interval_sec": "0.30", "ammo": "20", "range": "210"},
	"5": {"damage": "17", "fire_interval_sec": "0.25", "ammo": "20", "range": "220"},
	"6": {"damage": "20", "fire_interval_sec": "0.25", "ammo": "20", "range": "230"},
	"7": {"damage": "23", "fire_interval_sec": "0.25", "ammo": "20", "range": "240"},
	"8": {"damage": "26", "fire_interval_sec": "0.25", "ammo": "20", "range": "250"},
	"9": {"damage": "29", "fire_interval_sec": "0.25", "ammo": "20", "range": "260"}
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
		knock_back,
		DamageData.SOURCE_PLAYER_WEAPON,
		DamageDeliveryType.AREA
	)
	DamageManager.apply_to_target(target, damage_data)

	# 调用 on_hit_target 触发武器的命中效果
	on_hit_target_with_damage_type(target, Attack.TYPE_FIRE)

func _collect_targets_in_cone(forward: Vector2) -> Array[Node]:
	var output: Array[Node] = []
	var touched_ids: Dictionary = {}
	var max_angle_rad := deg_to_rad(_get_effective_cone_half_angle_deg())
	var effective_range: float = _get_effective_attack_range()
	if EnemyRegistry != null and EnemyRegistry.has_method("get_enemies_in_radius"):
		for enemy in EnemyRegistry.get_enemies_in_radius(global_position, effective_range):
			_append_target_in_cone(enemy, forward, max_angle_rad, effective_range, touched_ids, output)

	# Keep physics overlaps as a compatibility fallback for isolated scenes or
	# an enemy that has not reached the event-driven registry yet.
	for area in detect_area.get_overlapping_areas():
		if not area is HurtBox:
			continue
		var hurt_box := area as HurtBox
		if not hurt_box.get_collision_layer_value(3):
			continue
		var target := hurt_box.get_damage_target() as Node2D
		_append_target_in_cone(target, forward, max_angle_rad, effective_range, touched_ids, output)
	return output

func _append_target_in_cone(
	target: Node2D,
	forward: Vector2,
	max_angle_rad: float,
	effective_range: float,
	touched_ids: Dictionary,
	output: Array[Node]
) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("damaged"):
		return
	var target_id := target.get_instance_id()
	if touched_ids.has(target_id):
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > effective_range:
		return
	var dir := to_target.normalized()
	if dir != Vector2.ZERO and absf(forward.angle_to(dir)) > max_angle_rad:
		return
	touched_ids[target_id] = true
	output.append(target)

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
	_update_heat_prepared_firing_progress(delta)
	_update_flame_vfx_follow()
	if debug_mode:
		queue_redraw()

func _process_main_weapon_effect(_delta: float) -> void:
	pass

func _process_offhand_weapon_effect(_delta: float) -> void:
	pass

func _on_enter_main_weapon_role() -> void:
	pass

func clear_timed_effects_for_prepare() -> void:
	super.clear_timed_effects_for_prepare()
	_heat_prepared_firing_elapsed_sec = 0.0

func get_passive_status() -> Dictionary:
	var required_duration := maxf(fire_duration_required_sec, 0.1)
	var progress := clampf(_heat_prepared_firing_elapsed_sec / required_duration, 0.0, 1.0)
	var stack_count := _get_heat_prepared_stack_count()
	var max_stacks := maxi(heat_prepared_max_stacks, 1)
	var charge_states: Array[String] = []
	for index in range(max_stacks):
		charge_states.append("active" if index < stack_count else "spent")
	return with_passive_charge_status({
		"id": "flamethrower_heat_prepared",
		"display_name": "Heat Prepared",
		"state": "active" if stack_count > 0 else "charging",
		"progress": progress,
		"condition_visible": true,
		"condition_progress": progress,
		"current": _heat_prepared_firing_elapsed_sec,
		"required": required_duration,
		"ready": false,
		"trigger_hint": "cumulative_primary_fire_duration",
		"refresh_hint": "immediate_on_full",
		"charge_current": stack_count,
		"charge_max": max_stacks,
		"charges_current": stack_count,
		"charges_max": max_stacks,
		"charge_states": charge_states,
		"active_stack_count": stack_count,
	})

func _refresh_offhand_skill_on_reload() -> void:
	pass

func _update_heat_prepared_firing_progress(delta: float) -> void:
	if delta <= 0.0 or not _is_actively_firing_flame():
		return
	_accumulate_heat_prepared_firing_duration(delta)

func _accumulate_heat_prepared_firing_duration(delta: float) -> void:
	if delta <= 0.0:
		return
	var required_duration := maxf(fire_duration_required_sec, 0.1)
	_heat_prepared_firing_elapsed_sec += delta
	while _heat_prepared_firing_elapsed_sec + 0.0001 >= required_duration:
		if not _trigger_heat_prepared():
			_heat_prepared_firing_elapsed_sec = required_duration
			return
		_heat_prepared_firing_elapsed_sec = maxf(
			_heat_prepared_firing_elapsed_sec - required_duration,
			0.0
		)

func _is_actively_firing_flame() -> bool:
	return _primary_fire_held \
		and is_main_weapon() \
		and _can_maintain_held_flame_vfx()

func _trigger_heat_prepared() -> bool:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player) or not player.has_method("apply_heat_prepared"):
		return false
	var stack_count := int(player.call(
		"apply_heat_prepared",
		maxf(heat_prepared_duration_sec, 0.05),
		maxf(heat_prepared_fire_damage_bonus_per_stack, 0.0),
		maxi(heat_prepared_max_stacks, 1)
	))
	emit_passive_trigger(&"flamethrower_heat_prepared", {
		"trigger": "cumulative_primary_fire_duration_completed",
		"damage_type": Attack.TYPE_FIRE,
		"required_duration": maxf(fire_duration_required_sec, 0.1),
		"duration": maxf(heat_prepared_duration_sec, 0.05),
		"fire_damage_bonus_per_stack": maxf(heat_prepared_fire_damage_bonus_per_stack, 0.0),
		"stack_count": stack_count,
		"max_stacks": maxi(heat_prepared_max_stacks, 1),
		"refresh": "repeat_trigger",
	}, PASSIVE_SCOPE_GLOBAL)
	return true

func _get_heat_prepared_stack_count() -> int:
	var player: Node = PlayerData.player
	if player == null or not is_instance_valid(player):
		return 0
	if player.has_method("get_heat_prepared_stack_count"):
		return clampi(int(player.call("get_heat_prepared_stack_count")), 0, maxi(heat_prepared_max_stacks, 1))
	if player.has_method("has_heat_prepared") and bool(player.call("has_heat_prepared")):
		return 1
	return 0

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
	var fill_color := Color(PALETTE.FIRE, 0.14)
	# 扇形轮廓颜色
	var outline_color := Color(PALETTE.PLAYER_PRIMARY, 0.42)

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
	return get_effective_cone_half_angle(cone_half_angle_deg * maxf(angle_multiplier, 0.1))

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
