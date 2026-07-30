extends Node

const ChainsawLauncherScene := preload("res://Player/Weapons/Instances/chainsaw_launcher.tscn")
const CellScene := preload("res://Board/Cells/cell.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

class SlowTarget:
	extends Node
	var slowed := false
	var slow_application_count := 0
	var slow_multiplier := 1.0
	var slow_duration_sec := 0.0
	var vulnerability_application_count := 0
	var vulnerability_multiplier := 1.0
	var vulnerability_duration_sec := 0.0

	func is_slowed() -> bool:
		return slowed

	func apply_slow(multiplier: float, duration_sec: float) -> void:
		slowed = true
		slow_application_count += 1
		slow_multiplier = multiplier
		slow_duration_sec = duration_sec

	func apply_damage_taken_multiplier_status(_status_id: StringName, multiplier: float, duration_sec: float) -> void:
		vulnerability_application_count += 1
		vulnerability_multiplier = multiplier
		vulnerability_duration_sec = duration_sec

	func reset_effects() -> void:
		slowed = false
		slow_application_count = 0
		slow_multiplier = 1.0
		slow_duration_sec = 0.0
		vulnerability_application_count = 0
		vulnerability_multiplier = 1.0
		vulnerability_duration_sec = 0.0

func _ready() -> void:
	var board := BoardCellGenerator.new()
	board.cell_scene = CellScene
	board.grid_size = Vector2i.ONE
	board.auto_assign_enemy_on_battle = false
	add_child(board)
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
		elif not split_projectile.boundary_bounce_enabled \
				or split_projectile.boundary_bounce_rect != live_projectile.boundary_bounce_rect:
			push_error("chainsaw split projectile must remain bounded to the source cell")
			failed = true
		failed = _validate_wall_contact_vulnerability_chain(launcher, live_projectile) or failed
	if failed:
		print("FAIL chainsaw projectile lifecycle")
	else:
		print("PASS chainsaw projectile lifecycle")
	await TEST_TEARDOWN.finish(self, 1 if failed else 0)

func _validate_wall_contact_vulnerability_chain(launcher: Weapon, projectile: Projectile) -> bool:
	var target := SlowTarget.new()
	add_child(target)
	var failed := false
	var initial_expire_time := projectile.expire_time
	projectile.on_hit_target_with_damage_type(target, Attack.TYPE_PHYSICAL)
	failed = _check(
		target.slow_application_count == 0 and target.vulnerability_application_count == 0,
		"chainsaw must not apply slow or vulnerability before a projectile touches its cell boundary"
	) or failed

	var trigger_detail := {}
	launcher.passive_triggered.connect(
		func(event_name: StringName, detail: Dictionary) -> void:
			if event_name == &"chainsaw_wall_contact_triggered":
				trigger_detail.assign(detail),
		CONNECT_ONE_SHOT
	)
	projectile.set_physics_process(false)
	var bounce_rect := projectile.boundary_bounce_rect
	failed = _check(
		projectile.boundary_bounce_enabled and bounce_rect.size.x > 0.0 and bounce_rect.size.y > 0.0,
		"chainsaw projectile must lock to its spawn cell bounds"
	) or failed
	projectile.global_position = Vector2(bounce_rect.end.x - 1.0, bounce_rect.get_center().y)
	projectile.base_displacement = Vector2(200.0, 0.0)
	projectile.call("_physics_process", 0.02)
	var active_status: Dictionary = launcher.call("get_passive_status")
	failed = _check(
		projectile.base_displacement.x < 0.0 and bounce_rect.has_point(projectile.global_position),
		"chainsaw projectile must reflect inward at the cell boundary"
	) or failed
	failed = _check(
		is_equal_approx(projectile.lifetime_bonus_applied_sec, 1.0)
			and is_equal_approx(projectile.expire_time, initial_expire_time + 1.0),
		"first chainsaw boundary bounce must add 1 second of projectile lifetime"
	) or failed
	failed = _check(
		str(active_status.get("state", "")) == "active",
		"chainsaw wall contact must expose the armed vulnerability state"
	) or failed
	failed = _check(
		str(trigger_detail.get("state_after_trigger", "")) == "active",
		"chainsaw wall-contact event must report the armed state"
	) or failed
	projectile.on_hit_target_with_damage_type(target, Attack.TYPE_PHYSICAL)
	failed = _check(
		target.slow_application_count == 1 and target.vulnerability_application_count == 1,
		"armed chainsaw must apply both slow and vulnerability after a cell-boundary bounce"
	) or failed
	failed = _check(
		is_equal_approx(target.slow_multiplier, 0.7)
			and is_equal_approx(target.slow_duration_sec, 3.0)
			and is_equal_approx(target.vulnerability_multiplier, 1.15)
			and is_equal_approx(target.vulnerability_duration_sec, 6.0),
		"chainsaw bounce effects must preserve slow and vulnerability values"
	) or failed

	projectile.global_position = Vector2(bounce_rect.position.x + 1.0, bounce_rect.get_center().y)
	projectile.base_displacement = Vector2(-200.0, 0.0)
	projectile.call("_physics_process", 0.02)
	failed = _check(
		is_equal_approx(projectile.lifetime_bonus_applied_sec, 2.0)
			and is_equal_approx(projectile.expire_time, initial_expire_time + 2.0),
		"second chainsaw boundary bounce must raise total lifetime bonus to 2 seconds"
	) or failed
	projectile.global_position = Vector2(bounce_rect.end.x - 1.0, bounce_rect.get_center().y)
	projectile.base_displacement = Vector2(200.0, 0.0)
	projectile.call("_physics_process", 0.02)
	failed = _check(
		is_equal_approx(projectile.lifetime_bonus_applied_sec, 2.0)
			and is_equal_approx(projectile.expire_time, initial_expire_time + 2.0)
			and bounce_rect.has_point(projectile.global_position),
		"chainsaw projectile lifetime bonus must remain capped at 2 seconds"
	) or failed

	launcher.call("_refresh_offhand_skill_on_reload")
	target.reset_effects()
	projectile.on_hit_target_with_damage_type(target, Attack.TYPE_PHYSICAL)
	failed = _check(
		target.slow_application_count == 0 and target.vulnerability_application_count == 0,
		"chainsaw reload must disarm cell-bounce slow and vulnerability"
	) or failed
	target.queue_free()
	return failed

func _check(condition: bool, message: String) -> bool:
	if condition:
		return false
	push_error(message)
	return true
