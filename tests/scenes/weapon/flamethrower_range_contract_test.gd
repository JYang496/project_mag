extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const FLAMETHROWER_SCENE := preload("res://Player/Weapons/Instances/flamethrower.tscn")

var _failed := false


func _ready() -> void:
	var weapon := FLAMETHROWER_SCENE.instantiate() as Weapon
	add_child(weapon)
	await get_tree().process_frame

	weapon.set_level(1)
	_expect(is_equal_approx(float(weapon.get("attack_range")), 180.0), "level 1 Flamethrower range must be 180")
	_expect(is_equal_approx(float(weapon.call("_get_effective_attack_range")), 180.0), "level 1 effective range must match its configured range")
	_expect(is_equal_approx(_detect_radius(weapon), 180.0), "the detection radius must follow the level 1 hit range")

	weapon.set_level(9)
	_expect(is_equal_approx(float(weapon.get("attack_range")), 260.0), "level 9 Flamethrower range must be 260")
	_expect(is_equal_approx(float(weapon.call("_get_effective_attack_range")), 260.0), "level 9 effective range must match the 256px flame texture scale")
	_expect(is_equal_approx(_detect_radius(weapon), 260.0), "the detection radius must follow the level 9 hit range")
	var flame_vfx := weapon.get_node("FlameSprayVfx") as ConeSprayVfx
	flame_vfx.start_or_refresh(Vector2.ZERO, Vector2.RIGHT, 260.0, 40.0)
	var hybrid_visual := flame_vfx.get_hybrid_ground_cone_visual()
	_expect(hybrid_visual.get("texture") is Texture2D, "the hybrid flame cone must expose its current animation frame texture")
	var flame_texture := hybrid_visual.get("texture") as Texture2D
	_expect(flame_texture != null and flame_texture.get_size() == Vector2(256.0, 80.0), "the hybrid flame cone must use a 256x80 authored frame")
	var renderer := ConnectedEffectRenderer.new()
	var flame_material := renderer.get_cone_material(flame_texture)
	_expect(bool(flame_material.get_shader_parameter("use_flame_texture")), "the 2.5D cone material must enable its animation texture path")
	_expect(flame_material.get_shader_parameter("flame_texture") == flame_texture, "the 2.5D cone material must bind the current animation frame")

	weapon.fuse = 2
	_expect(weapon.branch_runtime.add_branch("long_cone_flame"), "the long-cone branch must attach for its range contract")
	_expect(is_equal_approx(float(weapon.call("_get_effective_attack_range")), 377.0), "the long-cone branch must cap level 9 reach at 377")
	_expect(is_equal_approx(_detect_radius(weapon), 377.0), "the detection radius must include the long-cone multiplier")

	print("FAIL flamethrower range contract" if _failed else "PASS flamethrower range contract")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _detect_radius(weapon: Weapon) -> float:
	var shape_node := weapon.get_node("DetectArea/CollisionShape2D") as CollisionShape2D
	var circle := shape_node.shape as CircleShape2D
	return circle.radius


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
