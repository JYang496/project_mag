extends Ranger

@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Flamethrower"

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 40.0
@export_range(40.0, 1200.0, 1.0) var base_flame_range: float = 280.0
@export var heat_accumulation: float = 10.0
@export var max_heat: float = 120.0
@export var heat_cooldown_rate: float = 26.0

## Debug mode: 显示攻击范围扇形
@export var debug_mode: bool = true

var attack_range: float = 280.0
## 已攻击过的目标ID（每轮射击重置）
var _attacked_target_ids: Dictionary = {}

var weapon_data := {
	"1": {"level": "1", "damage": "8", "reload": "0.30", "range": "260", "cost": "7"},
	"2": {"level": "2", "damage": "10", "reload": "0.28", "range": "270", "cost": "7"},
	"3": {"level": "3", "damage": "12", "reload": "0.26", "range": "285", "cost": "7"},
	"4": {"level": "4", "damage": "14", "reload": "0.24", "range": "300", "cost": "7"},
	"5": {"level": "5", "damage": "17", "reload": "0.22", "range": "320", "cost": "7"},
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
	base_attack_cooldown = float(level_data["reload"])
	attack_range = float(level_data.get("range", base_flame_range))
	heat_per_shot = heat_accumulation
	heat_max_value = max_heat
	heat_cool_rate = heat_cooldown_rate
	configure_heat(heat_per_shot, heat_max_value, heat_cool_rate)
	sync_stats()
	_sync_detect_radius()

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(attack_cooldown, 0.02)
	cooldown_timer.start()
	_emit_flame_burst()

func supports_projectiles() -> bool:
	return false

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

	var runtime_damage := get_runtime_shot_damage()
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
	var max_angle_rad := deg_to_rad(cone_half_angle_deg)
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
		if distance > attack_range:
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
	circle.radius = maxf(attack_range, 32.0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if debug_mode:
		queue_redraw()

func _draw() -> void:
	if not debug_mode:
		return
	_draw_attack_range()

func _draw_attack_range() -> void:
	# _draw() 是在节点坐标系中绘制，武器旋转时内容会跟着旋转
	# 武器默认朝上(UP)，所以需要向左旋转90度(-PI/2)来对齐
	var half_angle_rad := deg_to_rad(cone_half_angle_deg)
	var offset_angle := -PI / 2.0  # 向左旋转90度
	var start_angle := offset_angle - half_angle_rad
	var end_angle := offset_angle + half_angle_rad

	# 扇形填充颜色
	var fill_color := Color(1.0, 0.4, 0.0, 0.15)
	# 扇形轮廓颜色
	var outline_color := Color(1.0, 0.4, 0.0, 0.6)

	# 绘制扇形填充
	draw_arc(Vector2.ZERO, attack_range, start_angle, end_angle, 32, fill_color, -1.0)
	# 绘制扇形轮廓
	draw_arc(Vector2.ZERO, attack_range, start_angle, end_angle, 32, outline_color, 2.0)
	# 绘制中心半径线
	draw_line(Vector2.ZERO, Vector2.UP * attack_range, outline_color, 2.0)
	# 绘制边界半径线
	draw_line(Vector2.ZERO, Vector2.UP.rotated(-half_angle_rad) * attack_range, outline_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(half_angle_rad) * attack_range, outline_color, 1.0)
