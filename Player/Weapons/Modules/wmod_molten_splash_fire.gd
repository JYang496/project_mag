extends Module
# Splashes molten droplets in a short line behind the hit target.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Molten Splash"

@export var splash_ratio_lv1: float = 0.25
@export var splash_ratio_lv2: float = 0.36
@export var splash_ratio_lv3: float = 0.46
@export var splash_length_lv1: float = 105.0
@export var splash_length_lv2: float = 132.0
@export var splash_length_lv3: float = 156.0
@export var splash_half_width: float = 24.0

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	if not (target is Node2D):
		return
	var target2d := target as Node2D
	var source_pos := target2d.global_position - Vector2.RIGHT
	if source_weapon != null and is_instance_valid(source_weapon) and source_weapon is Node2D:
		source_pos = (source_weapon as Node2D).global_position
	var dir_to_target: Vector2 = (target2d.global_position - source_pos).normalized()
	if dir_to_target == Vector2.ZERO:
		dir_to_target = Vector2.RIGHT
	var line_start: Vector2 = target2d.global_position
	var line_end: Vector2 = line_start + dir_to_target * _get_splash_length()
	var tree := target2d.get_tree()
	if tree == null:
		return
	var search_radius := maxf(_get_splash_length() + splash_half_width, 8.0)
	var nearby := UTILS.get_nearby_enemies(tree, target2d.global_position, search_radius)
	var owner_player: Node = DamageManager.resolve_source_player(source_weapon)
	var damage_amount: int = max(1, int(round(float(UTILS.get_runtime_weapon_damage(source_weapon)) * _get_splash_ratio())))
	for enemy in nearby:
		if enemy == null or not is_instance_valid(enemy) or enemy == target:
			continue
		if _distance_point_to_segment(enemy.global_position, line_start, line_end) > maxf(splash_half_width, 1.0):
			continue
		var damage_data := DamageData.new().setup(
			damage_amount,
			Attack.TYPE_FIRE,
			{"amount": 0, "angle": Vector2.ZERO},
			source_weapon,
			owner_player
		)
		DamageManager.apply_to_target(enemy, damage_data)

func _distance_point_to_segment(point: Vector2, from_pos: Vector2, to_pos: Vector2) -> float:
	var segment := to_pos - from_pos
	var len_sq := segment.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(from_pos)
	var t := clampf((point - from_pos).dot(segment) / len_sq, 0.0, 1.0)
	var projection := from_pos + segment * t
	return point.distance_to(projection)

func _get_splash_ratio() -> float:
	match module_level:
		3:
			return maxf(0.0, splash_ratio_lv3)
		2:
			return maxf(0.0, splash_ratio_lv2)
		_:
			return maxf(0.0, splash_ratio_lv1)

func _get_splash_length() -> float:
	match module_level:
		3:
			return maxf(8.0, splash_length_lv3)
		2:
			return maxf(8.0, splash_length_lv2)
		_:
			return maxf(8.0, splash_length_lv1)
