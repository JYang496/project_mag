extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")
const BASE_WEAPON_SCENE := preload("res://Player/Weapons/weapon.tscn")

const EXPECTED_SPEEDS := {
	"pistol": 720.0, "machine_gun": 540.0, "dash_blade": 540.0,
	"shotgun": 360.0, "laser": 360.0, "orbit": 360.0,
	"plasma_lance": 300.0, "spear_launcher": 300.0,
	"chainsaw_launcher": 240.0, "sniper": 240.0,
	"cannon": 180.0, "rocket_launcher": 180.0, "charged_blaster": 180.0,
	"flamethrower": 180.0, "glacier_projector": 180.0,
}

var _failed := false

func _ready() -> void:
	var weapon := BASE_WEAPON_SCENE.instantiate() as Weapon
	add_child(weapon)
	weapon.global_position = Vector2.ZERO
	weapon.turn_speed_degrees_per_second = 180.0
	weapon.rotation = deg_to_rad(90.0)
	var initial_rotation := weapon.rotation
	weapon.turn_toward_world_position(Vector2.LEFT * 100.0, 0.25)
	_expect(is_equal_approx(absf(angle_difference(initial_rotation, weapon.rotation)), deg_to_rad(45.0)), "180 deg/sec must limit a quarter-second turn to 45 degrees")
	weapon.turn_toward_world_position(Vector2.LEFT * 100.0, 0.75)
	_expect(is_zero_approx(angle_difference(weapon.rotation, deg_to_rad(-90.0))), "limited aim must eventually reach the target")

	weapon.rotation = deg_to_rad(-179.0) + deg_to_rad(90.0)
	weapon.turn_toward_world_position(Vector2.RIGHT.rotated(deg_to_rad(179.0)) * 100.0, 0.02)
	_expect(absf(angle_difference(weapon.get_aim_forward().angle(), deg_to_rad(179.0))) < deg_to_rad(2.1), "aim must cross the angle seam by the shortest path")
	var unchanged_rotation := weapon.rotation
	weapon.turn_toward_world_position(Vector2.ZERO, 1.0)
	_expect(is_equal_approx(weapon.rotation, unchanged_rotation), "a coincident target must preserve the current aim")

	for weapon_name in EXPECTED_SPEEDS:
		var scene := load("res://Player/Weapons/Instances/%s.tscn" % weapon_name) as PackedScene
		var instance := scene.instantiate() as Weapon
		_expect(is_equal_approx(instance.turn_speed_degrees_per_second, float(EXPECTED_SPEEDS[weapon_name])), "%s must expose its configured turn speed" % weapon_name)
		instance.free()

	print("FAIL weapon turn speed" if _failed else "PASS weapon turn speed")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
