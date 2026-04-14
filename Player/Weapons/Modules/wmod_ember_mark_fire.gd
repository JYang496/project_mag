extends Module
# Builds ember marks on hit, then triggers a small fire burst when the mark threshold is reached.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Ember Mark"

@export var mark_threshold_lv1: int = 4
@export var mark_threshold_lv2: int = 3
@export var mark_threshold_lv3: int = 3
@export var burst_ratio_lv1: float = 0.30
@export var burst_ratio_lv2: float = 0.42
@export var burst_ratio_lv3: float = 0.55
@export var burst_radius: float = 90.0

var _mark_stacks: Dictionary = {}

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()
	_mark_stacks.clear()

func apply_on_hit(source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	if not (target is Node2D):
		return
	var target_id: int = target.get_instance_id()
	var next_stacks: int = int(_mark_stacks.get(target_id, 0)) + 1
	var threshold: int = _get_mark_threshold()
	if next_stacks < threshold:
		_mark_stacks[target_id] = next_stacks
		return
	_mark_stacks[target_id] = 0
	_trigger_burst(source_weapon, target as Node2D)

func _trigger_burst(source_weapon: Weapon, center_target: Node2D) -> void:
	if center_target == null or not is_instance_valid(center_target):
		return
	var tree := center_target.get_tree()
	if tree == null:
		return
	var base_damage: int = UTILS.get_runtime_weapon_damage(source_weapon)
	var burst_damage: int = max(1, int(round(float(base_damage) * _get_burst_ratio())))
	var owner_player: Node = DamageManager.resolve_source_player(source_weapon)
	var nearby := UTILS.get_nearby_enemies(tree, center_target.global_position, maxf(burst_radius, 8.0))
	for enemy in nearby:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var damage_data := DamageData.new().setup(
			burst_damage,
			Attack.TYPE_FIRE,
			{"amount": 0, "angle": Vector2.ZERO},
			source_weapon,
			owner_player
		)
		DamageManager.apply_to_target(enemy, damage_data)

func _get_mark_threshold() -> int:
	match module_level:
		3:
			return max(1, mark_threshold_lv3)
		2:
			return max(1, mark_threshold_lv2)
		_:
			return max(1, mark_threshold_lv1)

func _get_burst_ratio() -> float:
	match module_level:
		3:
			return maxf(0.0, burst_ratio_lv3)
		2:
			return maxf(0.0, burst_ratio_lv2)
		_:
			return maxf(0.0, burst_ratio_lv1)
