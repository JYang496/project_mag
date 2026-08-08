extends Node

const WHEEL_CART_SCENE := preload("res://Npc/enemy/scenes/enemy_wheel_cart.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false


func _ready() -> void:
	var enemy := WHEEL_CART_SCENE.instantiate() as BaseEnemy
	add_child(enemy)
	await get_tree().process_frame

	var hurt_box := enemy.get_node_or_null("HurtBox") as HurtBox
	_expect(enemy.damage == 2, "wheel cart contact damage must remain half-rounded-up at 2")
	_expect(enemy.hp == 15, "wheel cart base HP must remain 15")
	_expect(is_equal_approx(float(enemy.get("max_speed_multiplier")), 2.0), "wheel cart maximum speed must remain 64 from its 32 base speed")
	_expect(enemy.spawn_alive_cap == 3, "wheel cart must cap simultaneous pressure at three")
	_expect(enemy.spawn_batch_cap == 2, "wheel cart must cap one spawn batch at two")
	_expect(hurt_box != null, "wheel cart must retain its contact HurtBox")
	if hurt_box != null:
		_expect(hurt_box.get_collision_layer_value(3), "wheel cart HurtBox must remain on the enemy layer")
	_expect(not enemy.get_collision_mask_value(1), "wheel cart body must pass through the player layer")

	enemy.set_physics_process(false)
	enemy.knockback.amount = 20.0
	enemy.call("_physics_process", 1.0 / 60.0)
	_expect(float(enemy.knockback.amount) < 20.0, "wheel cart normal movement must decay persistent knockback")

	var neighbors: Array[Node2D] = []
	for index in range(12):
		var neighbor := Node2D.new()
		neighbor.global_position = Vector2(24.0 + float(index % 4) * 6.0, -6.0 + float(index / 4) * 6.0)
		add_child(neighbor)
		EnemyRegistry.register_enemy(neighbor)
		neighbors.append(neighbor)
	enemy.global_position = Vector2.ZERO
	EnemyRegistry.update_enemy_position(enemy)
	enemy.movement_runtime.separation_time_left = 0.0
	var aligned_push: Vector2 = enemy.movement_runtime.call("_get_cached_separation", Vector2(96.0, 0.0), 1.0 / 60.0)
	var separation_metrics := enemy.movement_runtime.call("get_separation_debug_metrics") as Dictionary
	_expect(int(separation_metrics.get("neighbor_count", 0)) == 12, "dense wheel cart separation must sample the bounded neighbor cap")
	_expect(aligned_push.length() > enemy.separation_speed, "coherent dense separation must partially stack above the fixed legacy push")
	_expect(aligned_push.length() <= 96.0 * 0.90 + 0.01, "non-compressed separation must respect the normal relative-speed cap")

	for index in range(neighbors.size()):
		neighbors[index].global_position = Vector2(8.0 + float(index % 4) * 4.0, -3.0 + float(index / 4) * 3.0)
		EnemyRegistry.update_enemy_position(neighbors[index])
	enemy.movement_runtime.separation_time_left = 0.0
	var emergency_push: Vector2 = enemy.movement_runtime.call("_get_cached_separation", Vector2(96.0, 0.0), 1.0 / 60.0)
	_expect(emergency_push.length() > aligned_push.length(), "severe compression must unlock the stronger emergency separation rate")
	_expect(emergency_push.length() <= 96.0 * 1.25 + 0.01, "emergency separation must remain bounded")

	for neighbor_index in range(1, neighbors.size()):
		EnemyRegistry.unregister_enemy(neighbors[neighbor_index])
		neighbors[neighbor_index].queue_free()
	neighbors.resize(1)
	neighbors[0].global_position = Vector2(47.0, 0.0)
	EnemyRegistry.update_enemy_position(neighbors[0])
	enemy.movement_runtime.separation_time_left = 0.0
	var sparse_outer_push: Vector2 = enemy.movement_runtime.call("_get_cached_separation", Vector2(96.0, 0.0), 1.0 / 60.0)
	_expect(sparse_outer_push.length() > 0.0 and sparse_outer_push.length() < 10.0, "a sparse outer-radius neighbor must keep only a light clustering push")
	for neighbor in neighbors:
		EnemyRegistry.unregister_enemy(neighbor)
		neighbor.queue_free()

	print(
		"FAIL wheel cart contact configuration"
		if _failed
		else "PASS wheel cart contact configuration"
	)
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
