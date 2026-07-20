extends Area2D
class_name HurtBox

var hurtbox_owner: Node

@onready var collision = $CollisionShape2D

func _ready() -> void:
	hurtbox_owner = _resolve_damage_target()

func get_damage_target() -> Node:
	var target := hurtbox_owner
	if target == null or not is_instance_valid(target):
		target = _resolve_damage_target()
		hurtbox_owner = target
	return target

func submit_damage_batch(candidates: Array) -> DamageResult:
	var result := DamageResult.new()
	var target := get_damage_target()
	if target == null or not is_instance_valid(target):
		return result
	var selected: DamageData = _select_damage_candidate(candidates, target)
	if selected == null:
		return result
	var damage_manager := get_node_or_null("/root/DamageManager")
	if damage_manager == null:
		return result
	return damage_manager.apply_to_hurt_box_result(self, selected)

func _select_damage_candidate(candidates: Array, target: Node) -> DamageData:
	var selected: DamageData
	var selected_damage := -1
	var selected_distance_squared := INF
	var selected_source_id := 0x7FFFFFFFFFFFFFFF
	for candidate_value in candidates:
		var candidate := candidate_value as DamageData
		if candidate == null:
			continue
		var source := candidate.source_node
		if source == null or not is_instance_valid(source):
			continue
		var distance_squared := INF
		if source is Node2D and target is Node2D:
			distance_squared = (source as Node2D).global_position.distance_squared_to((target as Node2D).global_position)
		var source_id := source.get_instance_id()
		var candidate_damage := maxi(candidate.amount, 0)
		if candidate_damage < selected_damage:
			continue
		if candidate_damage == selected_damage and distance_squared > selected_distance_squared:
			continue
		if candidate_damage == selected_damage and is_equal_approx(distance_squared, selected_distance_squared) and source_id >= selected_source_id:
			continue
		selected = candidate
		selected_damage = candidate_damage
		selected_distance_squared = distance_squared
		selected_source_id = source_id
	return selected

func _resolve_damage_target() -> Node:
	var target := get_owner()
	if target != null and is_instance_valid(target):
		return target
	target = get_parent()
	if target != null and is_instance_valid(target):
		return target
	return null

func _on_area_entered(_area):
	pass
