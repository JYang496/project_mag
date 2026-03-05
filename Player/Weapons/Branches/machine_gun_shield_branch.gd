extends WeaponBranchBehavior
class_name MachineGunShieldBranch

@export var shield_scene: PackedScene = preload("res://Player/Weapons/Branches/machine_gun_front_shield.tscn")

var _shield_node: Area2D

func on_weapon_ready() -> void:
	_spawn_or_attach_shield()

func on_level_applied(_level: int) -> void:
	_spawn_or_attach_shield()

func on_removed() -> void:
	if _shield_node and is_instance_valid(_shield_node):
		_shield_node.queue_free()
	_shield_node = null

func _spawn_or_attach_shield() -> void:
	if weapon == null or not is_instance_valid(weapon):
		return
	if _shield_node and is_instance_valid(_shield_node):
		return
	if shield_scene == null:
		return
	_shield_node = shield_scene.instantiate() as Area2D
	if _shield_node == null:
		return
	weapon.add_child(_shield_node)
	if _shield_node.has_method("setup"):
		_shield_node.call("setup", weapon)
