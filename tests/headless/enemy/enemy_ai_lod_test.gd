extends Node

const EnemyScene := preload("res://Npc/enemy/scenes/base_enemy.tscn")

var _failed := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var previous_player = PlayerData.player
	var player := Node2D.new()
	player.global_position = Vector2(5000.0, 5000.0)
	add_child(player)
	PlayerData.player = player
	var enemy := EnemyScene.instantiate() as BaseEnemy
	add_child(enemy)
	var near_ticks := _simulate_one_second(enemy, player.global_position)
	var mid_ticks := _simulate_one_second(enemy, player.global_position + Vector2(1200.0, 0.0))
	var far_ticks := _simulate_one_second(enemy, player.global_position + Vector2(2600.0, 0.0))
	_expect(near_ticks == 60, "near enemy AI must update at physics rate: %d" % near_ticks)
	_expect(mid_ticks >= 29 and mid_ticks <= 30, "mid enemy AI must update near 30 Hz: %d" % mid_ticks)
	_expect(far_ticks >= 11 and far_ticks <= 12, "far enemy AI must update near 12 Hz: %d" % far_ticks)
	enemy.apply_slow(0.5, 0.01)
	await get_tree().create_timer(0.02).timeout
	_expect(is_equal_approx(enemy.slow_multiplier, 1.0), "timestamp slow did not expire without per-frame status decrement")
	PlayerData.player = previous_player
	if _failed:
		push_error("FAIL: enemy AI distance LOD")
		get_tree().quit(1)
		return
	print("PASS: enemy AI uses 60/30/12 Hz distance tiers and timestamp status expiry")
	get_tree().quit(0)

func _simulate_one_second(enemy: BaseEnemy, position: Vector2) -> int:
	enemy.global_position = position
	enemy.reset_ai_lod_debug_metrics()
	for _frame in 60:
		enemy.consume_ai_update_delta(1.0 / 60.0)
	return int(enemy.get_ai_lod_debug_metrics().get("logic_ticks", -1))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)
