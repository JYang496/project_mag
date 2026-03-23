extends Ranger

const AREA_EFFECT_SCENE := preload("res://Utility/area_effect/area_effect.tscn")
@onready var detect_area: Area2D = $DetectArea

var ITEM_NAME := "Flamethrower"

@export_range(5.0, 120.0, 1.0) var cone_half_angle_deg: float = 40.0
@export_range(40.0, 1200.0, 1.0) var base_flame_range: float = 280.0
@export_range(12.0, 240.0, 1.0) var burst_radius: float = 56.0
@export_range(0.02, 1.5, 0.01) var burst_duration: float = 0.2
@export var heat_accumulation: float = 10.0
@export var max_heat: float = 120.0
@export var heat_cooldown_rate: float = 26.0

var attack_range: float = 280.0

var weapon_data := {
	"1": {"level": "1", "damage": "8", "reload": "0.30", "range": "260", "cost": "7"},
	"2": {"level": "2", "damage": "10", "reload": "0.28", "range": "270", "cost": "7"},
	"3": {"level": "3", "damage": "12", "reload": "0.26", "range": "285", "cost": "7"},
	"4": {"level": "4", "damage": "14", "reload": "0.24", "range": "300", "cost": "7"},
	"5": {"level": "5", "damage": "17", "reload": "0.22", "range": "320", "cost": "7"},
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
	if detect_area == null or not is_instance_valid(detect_area):
		return
	var forward := global_position.direction_to(get_mouse_target()).normalized()
	if forward == Vector2.ZERO:
		return
	var hit_positions := _collect_targets_in_cone(forward)
	for hit_position in hit_positions:
		_spawn_fire_burst(hit_position)

func _collect_targets_in_cone(forward: Vector2) -> Array[Vector2]:
	var output: Array[Vector2] = []
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
		output.append(target.global_position)
	return output

func _spawn_fire_burst(position: Vector2) -> void:
	var burst := AREA_EFFECT_SCENE.instantiate() as AreaEffect
	if burst == null:
		return
	burst.global_position = position
	burst.source_node = self
	burst.duration = burst_duration
	burst.radius = burst_radius
	burst.target_group = AreaEffect.TargetGroup.ENEMIES
	burst.apply_once_per_target = true
	burst.one_shot_damage = max(1, damage)
	burst.tick_damage = 0
	burst.damage_type = Attack.TYPE_FIRE
	get_projectile_spawn_parent().call_deferred("add_child", burst)

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
	circle.radius = maxf(attack_range + burst_radius, 32.0)
