extends WeaponBranchBehavior
class_name OrbitFrostBranch

@export var knockback_amount: float = 24.0

func get_damage_type_override() -> StringName:
	return Attack.TYPE_FREEZE

func on_target_hit(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var knockback_value: Variant = target.get("knockback")
	if not (knockback_value is Dictionary):
		return
	var target_node: Node2D = target as Node2D
	if target_node == null:
		return
	var origin: Vector2 = weapon.global_position
	if PlayerData.player and is_instance_valid(PlayerData.player):
		origin = PlayerData.player.global_position
	var push_dir: Vector2 = target_node.global_position - origin
	if push_dir == Vector2.ZERO:
		push_dir = Vector2.UP
	push_dir = push_dir.normalized()
	var knockback_data: Dictionary = knockback_value
	knockback_data["amount"] = maxf(knockback_amount, 0.0)
	knockback_data["angle"] = push_dir
	target.set("knockback", knockback_data)
