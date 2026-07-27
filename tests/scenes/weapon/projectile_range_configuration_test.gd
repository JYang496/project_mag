extends Node

const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

func _ready() -> void:
	var failed := false
	var base_weapon := preload("res://Player/Weapons/weapon.tscn").instantiate() as Weapon
	failed = _check(
		is_equal_approx(
			base_weapon.get_effective_projectile_lifetime(),
			Weapon.DEFAULT_PROJECTILE_LIFETIME_SEC
		),
		"an unspecified projectile range must use the visible default lifetime"
	) or failed
	base_weapon.free()

	var expectations := {
		"chainsaw_launcher.tscn": {
			"mode": Weapon.RangeMode.FIXED_LIFETIME,
			"lifetime": 2.5,
		},
		"pistol.tscn": {
			"mode": Weapon.RangeMode.FIXED_DISTANCE,
			"distance": 800.0,
		},
		"rocket_launcher.tscn": {
			"mode": Weapon.RangeMode.FIXED_DISTANCE,
			"distance": 800.0,
		},
		"shotgun.tscn": {
			"mode": Weapon.RangeMode.FIXED_LIFETIME,
			"lifetime": 0.3,
		},
		"spear_launcher.tscn": {
			"mode": Weapon.RangeMode.FIXED_DISTANCE,
			"distance": 800.0,
		},
	}
	for file_name: String in expectations:
		var packed := load(
			"res://Player/Weapons/Instances/%s" % file_name
		) as PackedScene
		var instance := packed.instantiate() as Weapon
		var expected: Dictionary = expectations[file_name]
		failed = _check(
			instance.range_mode == expected["mode"],
			"%s must serialize its projectile range mode" % file_name
		) or failed
		if expected.has("lifetime"):
			failed = _check(
				is_equal_approx(
					instance.projectile_lifetime_sec,
					float(expected["lifetime"])
				),
				"%s must serialize a positive projectile lifetime" % file_name
			) or failed
		if expected.has("distance"):
			failed = _check(
				is_equal_approx(
					instance.configured_attack_range,
					float(expected["distance"])
				),
				"%s must serialize a positive projectile distance" % file_name
			) or failed
		instance.free()
	print(
		"FAIL projectile range configuration"
		if failed
		else "PASS projectile range configuration"
	)
	await TEST_TEARDOWN.finish(self, 1 if failed else 0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
