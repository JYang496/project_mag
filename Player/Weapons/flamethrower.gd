extends Ranger

@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Flamethrower"

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 40.0
@export_range(40.0, 1200.0, 1.0) var base_flame_range: float = 280.0
@export var heat_accumulation: float = 10.0
@export var max_heat: float = 120.0
@export var heat_cooldown_rate: float = 26.0
@export var offhand_main_damage_bonus_flat: int = 1

## Debug mode: 显示攻击范围扇形
@export var debug_mode: bool = false

var attack_range: float = 280.0
## 已攻击过的目标ID（每轮射击重置）
var _attacked_target_ids: Dictionary = {}
var _offhand_bonus_target: Weapon = null

var weapon_data := {
	"1": {"level": "1", "damage": "8", "fire_interval_sec": "0.30", "ammo": "120", "range": "260", "cost": "11"},
	"2": {"level": "2", "damage": "10", "fire_interval_sec": "0.28", "ammo": "130", "range": "270", "cost": "11"},
	"3": {"level": "3", "damage": "12", "fire_interval_sec": "0.26", "ammo": "140", "range": "285", "cost": "11"},
	"4": {"level": "4", "damage": "14", "fire_interval_sec": "0.24", "ammo": "150", "range": "300", "cost": "11"},
	"5": {"level": "5", "damage": "17", "fire_interval_sec": "0.22", "ammo": "160", "range": "320", "cost": "11"},
	"6": {"level": "6", "damage": "20", "fire_interval_sec": "0.20", "ammo": "170", "range": "340", "cost": "11"},
	"7": {"level": "7", "damage": "23", "fire_interval_sec": "0.18", "ammo": "180", "range": "365", "cost": "11"},
}

func _ready() -> void:
	super._ready()
	_apply_fuse_sprite()
	_sync_detect_radius()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = weapon_data.get(lv, weapon_data["1"])
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])

	base_attack_cooldown = float(level_data["fire_interval_sec"])
	apply_level_ammo(level_data)
	attack_range = float(level_data.get("range", base_flame_range))
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()
	if branch_behavior and is_instance_valid(branch_behavior):
		branch_behavior.on_level_applied(level)
	_sync_detect_radius()

func _on_shoot() -> void:
	is_on_cooldown = true
	var cooldown: float = get_effective_cooldown(attack_cooldown)
	if branch_behavior and is_instance_valid(branch_behavior):
		cooldown *= branch_behavior.get_cooldown_multiplier()
	cooldown_timer.wait_time = maxf(cooldown, 0.02)
	cooldown_timer.start()
	_emit_flame_burst()

func supports_projectiles() -> bool:
	return false

func handle_primary_input(pressed: bool, _just_pressed: bool, _just_released: bool, _delta: float) -> void:
	if branch_behavior and is_instance_valid(branch_behavior) and branch_behavior.disables_primary_fire():
		return
	if not can_run_active_behavior():
		return
	if not pressed:
		return
	request_primary_fire()

func _emit_flame_burst() -> void:
	# 每轮射击开始时清空已攻击目标列表
	_attacked_target_ids.clear()

	if detect_area == null or not is_instance_valid(detect_area):
		return
	var forward := global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
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
	if branch_behavior and is_instance_valid(branch_behavior):
		var damage_multiplier := branch_behavior.get_damage_multiplier()
		runtime_damage = max(1, int(round(float(runtime_damage) * maxf(damage_multiplier, 0.05))))
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
	on_hit_target(target)

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
	if debug_mode:
		queue_redraw()

func _process_main_weapon_effect(_delta: float) -> void:
	_clear_offhand_main_weapon_damage_bonus()

func _process_offhand_weapon_effect(_delta: float) -> void:
	_update_offhand_main_weapon_damage_bonus()

func _on_enter_main_weapon_role() -> void:
	_clear_offhand_main_weapon_damage_bonus()

func _on_tree_exiting() -> void:
	_clear_offhand_main_weapon_damage_bonus()

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
	var range_multiplier: float = 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		range_multiplier = branch_behavior.get_attack_range_multiplier()
	return maxf(attack_range * maxf(range_multiplier, 0.1), 1.0)

func _get_effective_cone_half_angle_deg() -> float:
	var angle_multiplier: float = 1.0
	if branch_behavior and is_instance_valid(branch_behavior):
		angle_multiplier = branch_behavior.get_cone_half_angle_multiplier()
	return maxf(cone_half_angle_deg * maxf(angle_multiplier, 0.1), 1.0)

func _update_offhand_main_weapon_damage_bonus() -> void:
	var main_weapon := _resolve_main_weapon_for_offhand_bonus()
	if main_weapon == null:
		_clear_offhand_main_weapon_damage_bonus()
		return
	if _offhand_bonus_target != main_weapon:
		_clear_offhand_main_weapon_damage_bonus()
		_offhand_bonus_target = main_weapon
	_apply_offhand_main_weapon_damage_bonus(main_weapon)

func _resolve_main_weapon_for_offhand_bonus() -> Weapon:
	if PlayerData.player_weapon_list.is_empty():
		return null
	PlayerData.sanitize_main_weapon_index()
	var idx := PlayerData.main_weapon_index
	if idx < 0 or idx >= PlayerData.player_weapon_list.size():
		return null
	var weapon_variant: Variant = PlayerData.player_weapon_list[idx]
	var weapon := weapon_variant as Weapon
	if weapon == null or not is_instance_valid(weapon) or weapon == self:
		return null
	return weapon

func _apply_offhand_main_weapon_damage_bonus(target_weapon: Weapon) -> void:
	if target_weapon == null or not is_instance_valid(target_weapon):
		return
	if not target_weapon.has_method("apply_external_damage_mul") or not target_weapon.has_method("remove_external_damage_mul"):
		return
	var source_id: StringName = _get_offhand_bonus_source_id()
	var runtime_damage: int = _resolve_weapon_runtime_damage(target_weapon)
	var bonus_flat: int = max(1, offhand_main_damage_bonus_flat)
	var bonus_mul: float = float(runtime_damage + bonus_flat) / float(runtime_damage)
	target_weapon.call("remove_external_damage_mul", source_id)
	target_weapon.call("apply_external_damage_mul", source_id, bonus_mul)
	passive_triggered.emit(&"offhand_flamethrower_damage_bonus", {
		"bonus_flat": bonus_flat,
		"target_weapon": target_weapon,
	})

func _clear_offhand_main_weapon_damage_bonus() -> void:
	if _offhand_bonus_target != null and is_instance_valid(_offhand_bonus_target) and _offhand_bonus_target.has_method("remove_external_damage_mul"):
		_offhand_bonus_target.call("remove_external_damage_mul", _get_offhand_bonus_source_id())
	_offhand_bonus_target = null

func _get_offhand_bonus_source_id() -> StringName:
	return StringName("offhand_flamethrower_damage_bonus_%s" % str(get_instance_id()))

func _resolve_weapon_runtime_damage(target_weapon: Weapon) -> int:
	if target_weapon == null or not is_instance_valid(target_weapon):
		return 1
	if target_weapon.has_method("get_runtime_shot_damage"):
		return max(1, int(target_weapon.call("get_runtime_shot_damage")))
	if target_weapon.has_method("get_runtime_damage_value"):
		var base_damage_value := 1.0
		if target_weapon.get("base_damage") != null:
			base_damage_value = maxf(1.0, float(target_weapon.get("base_damage")))
		elif target_weapon.get("damage") != null:
			base_damage_value = maxf(1.0, float(target_weapon.get("damage")))
		return max(1, int(target_weapon.call("get_runtime_damage_value", base_damage_value)))
	if target_weapon.get("damage") != null:
		return max(1, int(target_weapon.get("damage")))
	return 1
