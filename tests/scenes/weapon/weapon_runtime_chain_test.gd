extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
var _failed := false


func _ready() -> void:
	_validate_weapon_scenes()
	_validate_projectile_scenes()

	print("FAIL weapon runtime chain" if _failed else "PASS weapon runtime chain")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _validate_weapon_scenes() -> void:
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Instances"):
		if not file_name.ends_with(".tscn"):
			continue
		var scene_path := "res://Player/Weapons/Instances/%s" % file_name
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s must load" % file_name)
		if packed == null:
			continue
		var instance := packed.instantiate()
		_expect(instance is Weapon, "%s root must inherit Weapon" % file_name)
		instance.free()


func _validate_projectile_scenes() -> void:
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Projectiles"):
		if not file_name.ends_with(".tscn"):
			continue
		var scene_path := "res://Player/Weapons/Projectiles/%s" % file_name
		var packed := load(scene_path) as PackedScene
		_expect(packed != null, "%s must load" % file_name)
		if packed == null:
			continue
		var instance := packed.instantiate()
		if instance is Projectile:
			_expect(instance.get_node_or_null("HitboxAnchor") != null, "%s must keep HitboxAnchor" % file_name)
			_expect(
				instance.get_node_or_null("CollisionArmingTimer") != null,
				"%s must keep CollisionArmingTimer" % file_name
			)
		instance.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
