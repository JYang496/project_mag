extends Node

var _failed := false
var _created: Array[Node2D] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	print("EnemyRegistry spatial hash test: start")
	_clear_registry()
	var fixed_positions := [
		Vector2.ZERO, Vector2(128.0, 0.0), Vector2(127.999, -0.001),
		Vector2(-0.001, -0.001), Vector2(-128.0, -128.0), Vector2(-128.001, 64.0),
		Vector2(300.0, 300.0), Vector2(-350.0, 210.0),
	]
	for position in fixed_positions:
		_create_enemy(position)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51A71A1
	for index in range(160):
		_create_enemy(Vector2(rng.randf_range(-2200.0, 2200.0), rng.randf_range(-2200.0, 2200.0)))

	_compare_radius(Vector2.ZERO, 0.0, null, "zero radius")
	_compare_radius(Vector2(-128.0, -128.0), 0.01, _created[4], "negative boundary excluded")
	_compare_radius(Vector2(-40.0, 75.0), 390.0, _created[3], "deterministic radius")
	_compare_rect(Rect2(Vector2(-128.0, -128.0), Vector2(256.0, 256.0)), null, "cell boundary rect")
	_compare_rect(Rect2(Vector2(-450.0, -240.0), Vector2(900.0, 480.0)), _created[0], "wide rect excluded")
	for index in range(60):
		var origin := Vector2(rng.randf_range(-1800.0, 1800.0), rng.randf_range(-1800.0, 1800.0))
		_compare_radius(origin, rng.randf_range(0.0, 430.0), _created[index] if index % 3 == 0 else null, "random radius %d" % index)
		var rect_size := Vector2(rng.randf_range(0.0, 700.0), rng.randf_range(0.0, 700.0))
		_compare_rect(Rect2(origin, rect_size), _created[index] if index % 4 == 0 else null, "random rect %d" % index)
	print("EnemyRegistry spatial hash test: equivalence complete")

	var moving := _created[0]
	moving.global_position = Vector2(129.0, -257.0)
	EnemyRegistry.update_enemy_position(moving)
	_compare_radius(moving.global_position, 0.0, null, "multi-cell movement")
	moving.global_position = Vector2(5000.0, -5000.0)
	EnemyRegistry.update_enemy_position(moving)
	_compare_rect(Rect2(Vector2(4999.0, -5001.0), Vector2(2.0, 2.0)), null, "teleport")

	_test_candidate_locality()
	print("EnemyRegistry spatial hash test: locality complete")
	_test_separation_and_capacity()
	print("EnemyRegistry spatial hash test: separation and capacity complete")
	var freed: Node2D = _created.pop_back() as Node2D
	var freed_id: int = freed.get_instance_id()
	freed.queue_free()
	await get_tree().process_frame
	if _ids(EnemyRegistry.get_enemies()).has(freed_id):
		_fail("queue_free enemy remained registered")
	_assert_index_consistency("after queue_free")

	_cleanup_created()
	await get_tree().process_frame
	_assert_index_consistency("after clear")
	if EnemyRegistry.get_enemy_count() != 0:
		_fail("registry did not clear")
	if _failed:
		push_error("FAIL: EnemyRegistry spatial hash regression")
		get_tree().quit(1)
		return
	print("PASS: EnemyRegistry spatial hash matches query semantics, provides bounded separation, caps bucket occupancy, and tracks movement and cleanup")
	get_tree().quit(0)

func _test_candidate_locality() -> void:
	_cleanup_created()
	for y in range(3):
		for x in range(4):
			_create_enemy(Vector2(8.0 + x * 12.0, 8.0 + y * 12.0))
	EnemyRegistry.reset_query_metrics()
	EnemyRegistry.get_enemies_in_radius(Vector2(24.0, 24.0), 70.0)
	var local_checks := int(EnemyRegistry.get_query_metrics().get("candidate_checks", -1))
	for index in range(240):
		_create_enemy(Vector2(5000.0 + index * 160.0, 5000.0 + float(index % 5) * 160.0))
	EnemyRegistry.reset_query_metrics()
	EnemyRegistry.get_enemies_in_radius(Vector2(24.0, 24.0), 70.0)
	var global_checks := int(EnemyRegistry.get_query_metrics().get("candidate_checks", -1))
	if local_checks != 12 or global_checks != local_checks:
		_fail("candidate checks scaled with global count: local=%d after_far=%d" % [local_checks, global_checks])

func _test_separation_and_capacity() -> void:
	_cleanup_created()
	var requester := _create_enemy(Vector2(32.0, 32.0))
	_create_enemy(Vector2(42.0, 32.0))
	_create_enemy(Vector2(32.0, 42.0))
	var separation := EnemyRegistry.get_separation_vector(requester, 48.0, 12)
	if separation.x >= 0.0 or separation.y >= 0.0 or separation.length() > 1.0001:
		_fail("unexpected separation vector: %s" % separation)
	_cleanup_created()
	var capacity := int(EnemyRegistry.get_spatial_debug_snapshot().get("bucket_capacity", -1))
	for index in range(capacity + 9):
		_create_enemy(Vector2(16.0 + float(index % 3), 16.0))
	var snapshot := EnemyRegistry.get_spatial_debug_snapshot()
	if int(snapshot.get("max_bucket_occupancy", capacity + 1)) > capacity:
		_fail("bucket capacity exceeded: %s" % snapshot)
	if int(snapshot.get("enemy_count", -1)) != capacity + 9:
		_fail("capacity relocation lost enemies: %s" % snapshot)

func _compare_radius(origin: Vector2, radius: float, excluded: Node, label: String) -> void:
	var expected: Array[int] = []
	var radius_sq := maxf(radius, 0.0) ** 2
	for enemy in EnemyRegistry.get_enemies():
		if enemy == excluded:
			continue
		if enemy.global_position.distance_squared_to(origin) <= radius_sq:
			expected.append(enemy.get_instance_id())
	var actual := _ids(EnemyRegistry.get_enemies_in_radius(origin, radius, excluded))
	_assert_same_ids(expected, actual, label)

func _compare_rect(rect: Rect2, excluded: Node, label: String) -> void:
	var expected: Array[int] = []
	for enemy in EnemyRegistry.get_enemies():
		if enemy != excluded and rect.has_point(enemy.global_position):
			expected.append(enemy.get_instance_id())
	var actual := _ids(EnemyRegistry.get_enemies_in_rect(rect, excluded))
	_assert_same_ids(expected, actual, label)

func _assert_same_ids(expected: Array[int], actual: Array[int], label: String) -> void:
	if expected != actual:
		_fail("%s mismatch expected=%s actual=%s" % [label, expected, actual])

func _ids(enemies: Array) -> Array[int]:
	var result: Array[int] = []
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			result.append(enemy.get_instance_id())
	return result

func _create_enemy(world_position: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.global_position = world_position
	add_child(enemy)
	EnemyRegistry.register_enemy(enemy)
	_created.append(enemy)
	return enemy

func _clear_registry() -> void:
	for enemy in EnemyRegistry.get_enemies():
		EnemyRegistry.unregister_enemy(enemy)

func _cleanup_created() -> void:
	for enemy in _created:
		if enemy != null and is_instance_valid(enemy):
			EnemyRegistry.unregister_enemy(enemy)
			enemy.queue_free()
	_created.clear()

func _assert_index_consistency(label: String) -> void:
	var snapshot := EnemyRegistry.get_spatial_debug_snapshot()
	var enemy_count := int(snapshot.get("enemy_count", -1))
	if (
		enemy_count != int(snapshot.get("indexed_enemy_count", -2))
		or enemy_count != int(snapshot.get("bucket_entry_count", -3))
	):
		_fail("%s inconsistent snapshot: %s" % [label, snapshot])
	if enemy_count == 0 and int(snapshot.get("bucket_count", -1)) != 0:
		_fail("%s retained spatial state after full cleanup: %s" % [label, snapshot])

func _fail(message: String) -> void:
	_failed = true
	push_error("FAIL: %s" % message)
