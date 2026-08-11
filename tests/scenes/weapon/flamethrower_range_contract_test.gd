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
	_expect(is_equal_approx(weapon.turn_speed_degrees_per_second, 180.0), "Flamethrower must turn at 180 degrees per second")
	weapon.rotation = deg_to_rad(90.0)
	weapon.call("_step_aim_toward", Vector2.RIGHT * 100.0, 0.016)
	_expect((weapon.call("get_flame_aim_direction") as Vector2).is_equal_approx(Vector2.RIGHT), "Flamethrower must preserve an already aligned aim direction")
	weapon.call("_step_aim_toward", Vector2.LEFT * 100.0, 0.25)
	var quarter_turn_direction := weapon.call("get_flame_aim_direction") as Vector2
	_expect(is_equal_approx(absf(Vector2.RIGHT.angle_to(quarter_turn_direction)), PI * 0.25), "Flamethrower must rotate only 45 degrees during the first quarter-second of a 180-degree turn")
	_expect(absf(quarter_turn_direction.angle_to(Vector2.LEFT)) > PI * 0.5, "Flamethrower must not snap to a target directly behind it")
	weapon.call("_step_aim_toward", Vector2.LEFT * 100.0, 0.75)
	_expect(is_zero_approx(absf((weapon.call("get_flame_aim_direction") as Vector2).angle_to(Vector2.LEFT))), "Flamethrower must finish a 180-degree turn after about one second")

	weapon.set_level(9)
	_expect(is_equal_approx(float(weapon.get("attack_range")), 260.0), "level 9 Flamethrower range must be 260")
	_expect(is_equal_approx(float(weapon.call("_get_effective_attack_range")), 260.0), "level 9 effective range must match the 256px flame texture scale")
	_expect(is_equal_approx(_detect_radius(weapon), 260.0), "the detection radius must follow the level 9 hit range")
	var flame_vfx := weapon.get_node("FlameSprayVfx") as ConeSprayVfx
	flame_vfx.start_or_refresh(Vector2.ZERO, Vector2.RIGHT, 260.0, 40.0)
	var hybrid_visual := flame_vfx.get_hybrid_ground_cone_visual()
	var visible_tip := (hybrid_visual.get("origin", Vector2.ZERO) as Vector2) + (hybrid_visual.get("direction", Vector2.RIGHT) as Vector2) * float(hybrid_visual.get("range", 0.0))
	_expect(is_equal_approx(visible_tip.x, 260.0), "the readability layers must end exactly at the unchanged effective hit range")
	_expect(float(hybrid_visual.get("body_opacity", 1.0)) < 0.7, "the flame body layer must remain translucent enough to preserve target silhouettes")
	_expect(float(hybrid_visual.get("range_cue_opacity", 0.0)) > 0.0, "the flame cone must expose a separate low-opacity range cue")
	_expect(float(hybrid_visual.get("core_highlight_strength", 0.0)) > 0.0, "the flame cone must expose a distinct bright core layer")
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
