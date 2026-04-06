extends Ranger

const FROST_CONTACT_WINDOW_SEC: float = 0.35

@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Glacier Projector"

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 38.0
@export_range(40.0, 1200.0, 1.0) var base_range: float = 280.0
@export var cold_snap_damage_ratio: float = 0.35
@export var cold_snap_contact_threshold_sec: float = 1.2
@export var cold_snap_icd_sec: float = 1.2
@export var debug_mode: bool = true

var attack_range: float = 280.0
var _attacked_target_ids: Dictionary = {}
var _target_contact_state: Dictionary = {}

var weapon_data: Dictionary = {
	"1": {"level": "1", "damage": "6", "reload": "0.22", "range": "260", "cost": "10"},
	"2": {"level": "2", "damage": "7", "reload": "0.21", "range": "275", "cost": "10"},
	"3": {"level": "3", "damage": "8", "reload": "0.20", "range": "290", "cost": "10"},
	"4": {"level": "4", "damage": "10", "reload": "0.19", "range": "310", "cost": "10"},
	"5": {"level": "5", "damage": "12", "reload": "0.18", "range": "330", "cost": "10"},
}

func _ready() -> void:
	super._ready()
	_sync_detect_radius()

func set_level(lv) -> void:
	lv = str(lv)
	var level_data: Dictionary = weapon_data.get(lv, weapon_data["1"])
	level = int(level_data["level"])
	base_damage = int(level_data["damage"])
	base_attack_cooldown = float(level_data["reload"])
	attack_range = float(level_data.get("range", base_range))
	sync_stats()
	_sync_detect_radius()

func _on_shoot() -> void:
	is_on_cooldown = true
	cooldown_timer.wait_time = maxf(attack_cooldown, 0.02)
	cooldown_timer.start()
	_emit_glacier_burst()

func supports_projectiles() -> bool:
	return false

func _emit_glacier_burst() -> void:
	_attacked_target_ids.clear()
	if detect_area == null or not is_instance_valid(detect_area):
		return
	var forward: Vector2 = global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
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
	_on_target_contact(target)
	on_hit_target(target)

func _on_target_contact(target: Node) -> void:
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	var target_id: int = target.get_instance_id()
	var state: Dictionary = _target_contact_state.get(target_id, {
		"accum": 0.0,
		"last_contact": -999.0,
		"last_proc": -999.0,
	})
	var last_contact: float = float(state.get("last_contact", -999.0))
	var accum: float = float(state.get("accum", 0.0))
	if now_sec - last_contact <= FROST_CONTACT_WINDOW_SEC:
		accum += attack_cooldown
	else:
		accum = attack_cooldown
	state["last_contact"] = now_sec
	state["accum"] = accum
	var last_proc: float = float(state.get("last_proc", -999.0))
	if accum >= maxf(cold_snap_contact_threshold_sec, 0.1) and now_sec - last_proc >= maxf(cold_snap_icd_sec, 0.1):
		state["last_proc"] = now_sec
		state["accum"] = 0.0
		_trigger_cold_snap(target)
	_target_contact_state[target_id] = state

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

func _collect_targets_in_cone(forward: Vector2) -> Array[Node]:
	var output: Array[Node] = []
	var touched_ids: Dictionary = {}
	var max_angle_rad: float = deg_to_rad(cone_half_angle_deg)
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
		if distance > attack_range:
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
	var half_angle_rad: float = deg_to_rad(cone_half_angle_deg)
	var offset_angle: float = -PI / 2.0
	var start_angle: float = offset_angle - half_angle_rad
	var end_angle: float = offset_angle + half_angle_rad
	var fill_color := Color(0.35, 0.85, 1.0, 0.15)
	var outline_color := Color(0.35, 0.85, 1.0, 0.7)
	draw_arc(Vector2.ZERO, attack_range, start_angle, end_angle, 32, fill_color, -1.0)
	draw_arc(Vector2.ZERO, attack_range, start_angle, end_angle, 32, outline_color, 2.0)
	draw_line(Vector2.ZERO, Vector2.UP * attack_range, outline_color, 2.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(-half_angle_rad) * attack_range, outline_color, 1.0)
	draw_line(Vector2.ZERO, Vector2.UP.rotated(half_angle_rad) * attack_range, outline_color, 1.0)
