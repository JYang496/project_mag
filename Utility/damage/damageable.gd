extends Node
class_name Damageable

# Optional relay target. If null, parent/owner is used.
@export var damage_target: Node


func apply_damage_data(data: DamageData) -> bool:
	if data == null:
		return false
	var target := damage_target
	if target == null:
		target = get_parent()
	if target == null:
		target = get_owner()
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("damaged"):
		return false
	target.damaged(data.to_attack())
	return true
