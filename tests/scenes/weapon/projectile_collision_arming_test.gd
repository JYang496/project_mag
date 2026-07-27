extends Node

const RocketLauncherScene := preload("res://Player/Weapons/Instances/rocket_launcher.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

func _ready() -> void:
	var failed := false
	var rocket_launcher := RocketLauncherScene.instantiate()
	rocket_launcher.position = Vector2(240.0, 120.0)
	add_child(rocket_launcher)
	await get_tree().process_frame
	rocket_launcher.call("set_level", 1)
	rocket_launcher.set("speed", 1)
	var muzzle_position: Vector2 = rocket_launcher.call("get_muzzle_global_position")
	var projectile := rocket_launcher.call(
		"_fire_single_rocket",
		Vector2.RIGHT,
		1.0
	) as Projectile
	if projectile != null and not projectile.is_inside_tree():
		await projectile.tree_entered
	if projectile != null and not projectile.is_node_ready():
		await projectile.ready
	failed = _check(
		projectile != null and is_instance_valid(projectile) and projectile.is_inside_tree(),
		"rocket launcher must spawn a projectile"
	) or failed
	if projectile != null:
		failed = _check(
			projectile.global_position.distance_to(muzzle_position) < 12.0,
			"rocket projectile must spawn from the logical muzzle"
		) or failed
		failed = _check(
			projectile.collision_arming_delay_sec > 0.0,
			"rocket projectile must configure a collision arming delay"
		) or failed
		failed = _check(
			projectile.expire_time > projectile.collision_arming_delay_sec,
			"rocket lifetime must outlast its collision arming delay"
		) or failed
		failed = _check(
			projectile.hitbox_ins != null and not projectile.hitbox_ins.monitoring,
			"rocket hitbox must start disarmed before its first movement frame"
		) or failed
		await get_tree().create_timer(
			projectile.collision_arming_delay_sec + 0.03
		).timeout
		failed = _check(
			projectile.hitbox_ins != null and projectile.hitbox_ins.monitoring,
			"rocket hitbox must arm after its short safety delay"
		) or failed
	print(
		"FAIL projectile collision arming"
		if failed
		else "PASS projectile collision arming"
	)
	await TEST_TEARDOWN.finish(self, 1 if failed else 0)

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
