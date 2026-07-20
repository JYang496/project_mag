extends Node

const RollingBallScene := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")
const ShieldCoreScene := preload("res://Npc/enemy/scenes/enemy_shield_core.tscn")
const ENEMY_COUNT := 96

var _failed := false
var _enemies: Array[BaseEnemy] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for index in ENEMY_COUNT:
		var enemy := RollingBallScene.instantiate() as BaseEnemy
		enemy.global_position = Vector2(index * 12.0, 0.0)
		add_child(enemy)
		enemy.set_physics_process(false)
		_enemies.append(enemy)
	await get_tree().physics_frame
	var snapshot := EnemyRegistry.get_spatial_debug_snapshot()
	_expect(int(snapshot.get("enemy_count", -1)) == ENEMY_COUNT, "registry count mismatch")
	_expect(not bool(snapshot.get("has_frame_processing", true)), "registry must not process every frame")
	var target: BaseEnemy = _enemies.back()
	var source := Node2D.new()
	add_child(source)
	target.add_speed_bonus_source(source, 1.25)
	target.add_slow_field_source(source, 0.5)
	target.set_support_damage_reduction(source, 0.7)
	_expect(is_equal_approx(target.get_current_movement_speed(), target.movement_speed * 1.25 * 0.5), "event modifiers did not compose")
	_expect(is_equal_approx(target.get_support_damage_taken_multiplier(), 0.7), "damage modifier did not apply")
	target.remove_speed_bonus_source(source)
	target.remove_slow_field_source(source)
	target.clear_support_damage_reduction(source)
	_expect(is_equal_approx(target.get_current_movement_speed(), target.movement_speed), "event modifiers did not clear")
	var shield := ShieldCoreScene.instantiate() as BaseEnemy
	shield.global_position = target.global_position
	add_child(shield)
	shield.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(is_equal_approx(target.get_support_damage_taken_multiplier(), 0.65), "shield Area2D did not apply its event modifier")
	shield.queue_free()
	await get_tree().physics_frame
	_expect(is_equal_approx(target.get_support_damage_taken_multiplier(), 1.0), "shield cleanup left a stale event modifier")
	for enemy in _enemies:
		enemy.queue_free()
	source.queue_free()
	if _failed:
		push_error("FAIL: passive enemy registry and event modifiers")
		get_tree().quit(1)
		return
	print("PASS: enemy registry is passive and enemy modifiers are event driven")
	get_tree().quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)
