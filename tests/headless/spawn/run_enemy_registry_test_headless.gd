extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := root.get_node_or_null("/root/EnemyRegistry")
	if registry == null:
		push_error("FAIL: missing EnemyRegistry autoload")
		quit(1)
		return
	var a := _spawn_dummy(Vector2.ZERO)
	var b := _spawn_dummy(Vector2(50.0, 0.0))
	var c := _spawn_dummy(Vector2(300.0, 0.0))
	await process_frame
	if int(registry.call("get_enemy_count")) != 3:
		push_error("FAIL: expected 3 registered enemies, got %d" % int(registry.call("get_enemy_count")))
		quit(1)
		return
	var nearby: Array = registry.call("get_enemies_in_radius", Vector2.ZERO, 75.0)
	if nearby.size() != 2 or not nearby.has(a) or not nearby.has(b):
		push_error("FAIL: radius query returned unexpected candidates size=%d" % nearby.size())
		quit(1)
		return
	var nearby_excluded: Array = registry.call("get_enemies_in_radius", Vector2.ZERO, 75.0, a)
	if nearby_excluded.size() != 1 or nearby_excluded[0] != b:
		push_error("FAIL: radius query exclusion failed")
		quit(1)
		return
	var rect_candidates: Array = registry.call("get_enemies_in_rect", Rect2(Vector2(-10.0, -10.0), Vector2(80.0, 20.0)))
	if rect_candidates.size() != 2 or not rect_candidates.has(a) or not rect_candidates.has(b):
		push_error("FAIL: rect query returned unexpected candidates size=%d" % rect_candidates.size())
		quit(1)
		return
	b.queue_free()
	await process_frame
	await process_frame
	var after_free: Array = registry.call("get_enemies_in_radius", Vector2.ZERO, 75.0)
	if after_free.size() != 1 or after_free[0] != a:
		push_error("FAIL: freed enemy remained in registry")
		quit(1)
		return
	c.queue_free()
	a.queue_free()
	await process_frame
	if int(registry.call("get_enemy_count")) != 0:
		push_error("FAIL: expected empty registry after cleanup, got %d" % int(registry.call("get_enemy_count")))
		quit(1)
		return
	print("PASS: EnemyRegistry registration, radius query, rect query, exclusion, and cleanup")
	quit(0)

func _spawn_dummy(pos: Vector2) -> Node2D:
	var dummy := Node2D.new()
	dummy.add_to_group("enemies")
	root.add_child(dummy)
	dummy.global_position = pos
	var registry := root.get_node_or_null("/root/EnemyRegistry")
	if registry != null:
		registry.call("register_enemy", dummy)
	return dummy
