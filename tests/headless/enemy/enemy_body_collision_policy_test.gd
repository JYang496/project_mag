extends Node

const RollingBallScene := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")
const EliteRollingBallScene := preload("res://Npc/enemy/scenes/enemy_rolling_ball_elite.tscn")

var _failed := false
var _target: Node2D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_target = Node2D.new()
	_target.global_position = Vector2(1000.0, 0.0)
	add_child(_target)
	PlayerData.player = _target
	var normal := RollingBallScene.instantiate() as BaseEnemy
	add_child(normal)
	_check_policy(normal, "normal at spawn")
	await get_tree().create_timer(0.25).timeout
	_check_policy(normal, "normal after EnableCollisionTimer")

	normal.knockback.amount = 20.0
	_check_policy(normal, "normal during knockback")
	normal.knockback.amount = 0.0
	_check_policy(normal, "normal after knockback")

	var elite := EliteRollingBallScene.instantiate() as EnemyEliteRollingBall
	add_child(elite)
	_check_policy(elite, "elite at spawn")
	elite._start_dash_prepare()
	_check_policy(elite, "elite preparing dash")
	elite._begin_dash()
	_check_policy(elite, "elite during dash")
	elite._finish_dash()
	_check_policy(elite, "elite after dash")
	await get_tree().create_timer(0.25).timeout
	_check_policy(elite, "elite after EnableCollisionTimer")

	if _failed:
		PlayerData.player = null
		push_error("FAIL: enemy body collision policy regression")
		get_tree().quit(1)
		return
	PlayerData.player = null
	print("PASS: enemy CharacterBody mask 3 remains disabled while terrain mask 6 enables across spawn, knockback, and elite dash states")
	get_tree().quit(0)

func _check_policy(enemy: BaseEnemy, label: String) -> void:
	if enemy.get_collision_mask_value(3):
		_fail("%s enabled enemy CharacterBody mask 3" % label)
	if enemy.enable_collision_timer.is_stopped() and not enemy.get_collision_mask_value(6):
		_fail("%s did not enable terrain mask 6 after collision timer" % label)

func _fail(message: String) -> void:
	_failed = true
	push_error("FAIL: %s" % message)
