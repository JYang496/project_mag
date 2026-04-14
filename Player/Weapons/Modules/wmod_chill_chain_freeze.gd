extends Module
# Spreads a short slow debuff from the hit target to one nearby enemy.

const UTILS := preload("res://Player/Weapons/Modules/wmod_runtime_utils.gd")

var ITEM_NAME := "Chill Chain"

@export var spread_radius: float = 150.0
@export var slow_multiplier_lv1: float = 0.88
@export var slow_multiplier_lv2: float = 0.82
@export var slow_multiplier_lv3: float = 0.76
@export var slow_duration_lv1: float = 1.2
@export var slow_duration_lv2: float = 1.5
@export var slow_duration_lv3: float = 1.8

func _enter_tree() -> void:
	super._enter_tree()
	register_as_on_hit_plugin()

func _ready() -> void:
	register_as_on_hit_plugin()

func _exit_tree() -> void:
	unregister_as_on_hit_plugin()

func apply_on_hit(_source_weapon: Weapon, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("enemies"):
		return
	if not (target is Node2D):
		return
	var center := target as Node2D
	var tree := center.get_tree()
	if tree == null:
		return
	var nearby := UTILS.get_nearby_enemies(tree, center.global_position, maxf(spread_radius, 8.0))
	var best_target: Node = null
	var best_dist: float = INF
	for enemy in nearby:
		if enemy == null or not is_instance_valid(enemy) or enemy == target:
			continue
		var dist := enemy.global_position.distance_to(center.global_position)
		if dist >= best_dist:
			continue
		best_dist = dist
		best_target = enemy
	if best_target == null or not is_instance_valid(best_target):
		return
	_apply_slow(best_target)

func _apply_slow(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var payload := {
		"multiplier": _get_slow_multiplier(),
		"duration": _get_slow_duration(),
	}
	if target.has_method("apply_status_payload"):
		target.call("apply_status_payload", &"slow", payload)
		return
	if target.has_method("apply_slow"):
		target.call("apply_slow", payload["multiplier"], payload["duration"])

func _get_slow_multiplier() -> float:
	match module_level:
		3:
			return clampf(slow_multiplier_lv3, 0.05, 1.0)
		2:
			return clampf(slow_multiplier_lv2, 0.05, 1.0)
		_:
			return clampf(slow_multiplier_lv1, 0.05, 1.0)

func _get_slow_duration() -> float:
	match module_level:
		3:
			return maxf(0.0, slow_duration_lv3)
		2:
			return maxf(0.0, slow_duration_lv2)
		_:
			return maxf(0.0, slow_duration_lv1)
