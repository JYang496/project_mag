extends Node

const ChainsawLauncherScene := preload("res://Player/Weapons/Instances/chainsaw_launcher.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

func _ready() -> void:
	var launcher := ChainsawLauncherScene.instantiate() as Weapon
	launcher.position = Vector2(320.0, 120.0)
	launcher.set_meta("_benchmark_mouse_target", Vector2(640.0, 120.0))
	add_child(launcher)
	await get_tree().process_frame
	launcher.call("_on_shoot")
	await get_tree().create_timer(0.05).timeout
	var live_projectile: Projectile
	for child in get_children():
		if child is Projectile and (child as Projectile).source_weapon == launcher:
			live_projectile = child as Projectile
			break
	var failed := live_projectile == null or not is_instance_valid(live_projectile)
	if failed:
		push_error("chainsaw projectile must remain alive after spawning")
	else:
		var split_projectile := launcher.call("_spawn_split_projectile_from", live_projectile) as Projectile
		await get_tree().process_frame
		if split_projectile == null or not is_instance_valid(split_projectile):
			push_error("chainsaw split projectile must spawn")
			failed = true
		elif split_projectile.source_weapon != launcher:
			push_error("chainsaw split projectile must preserve source weapon attribution")
			failed = true
		elif split_projectile.wall_collision_mask != live_projectile.wall_collision_mask:
			push_error("chainsaw split projectile must preserve wall collision behavior")
			failed = true
	if failed:
		print("FAIL chainsaw projectile lifecycle")
	else:
		print("PASS chainsaw projectile lifecycle")
	await TEST_TEARDOWN.finish(self, 1 if failed else 0)
