extends Node

const SpikeScene := preload("res://Npc/enemy/scenes/enemy_spike_turret.tscn")

var _player: Node2D
var _turret: EnemySpikeTurret

func _ready() -> void:
	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.wait_time = 5.0
	timeout.timeout.connect(func() -> void:
		_fail("probe timed out")
	)
	add_child(timeout)
	timeout.start()
	call_deferred("_run")

func _run() -> void:
	_player = Node2D.new()
	_player.name = "SpikeProbePlayer"
	get_tree().root.add_child(_player)
	PlayerData.player = _player

	_turret = SpikeScene.instantiate() as EnemySpikeTurret
	if _turret == null:
		_fail("failed to instantiate spike turret")
		return
	get_tree().root.add_child(_turret)
	_turret.global_position = Vector2(100.0, 100.0)
	_turret.attack_range = 100.0
	_turret.detect_range = 300.0
	_turret.stationary_enter_range_ratio = 0.8
	_turret.lock_duration = 0.1
	_turret.cooldown_duration = 0.2
	_turret.movement_speed = 20.0
	await get_tree().physics_frame

	_player.global_position = Vector2(250.0, 100.0)
	await _physics_ticks(2)
	if bool(_turret.get("_is_stationary_mode")):
		_fail("turret entered stationary mode before player reached 0.8 attack range")
		return
	if _turret.velocity.x <= 0.0:
		_fail("turret did not chase toward the player while outside stationary range")
		return

	_player.global_position = _turret.global_position + Vector2(80.0, 0.0)
	await _physics_ticks(2)
	if not bool(_turret.get("_is_stationary_mode")):
		_fail("turret did not enter stationary mode at 0.8 attack range")
		return
	if _turret.velocity.length() > 0.01:
		_fail("turret kept moving after entering stationary mode")
		return
	if not bool(_turret.get("_is_locking")):
		_fail("turret did not begin a shot while stationary and in range")
		return

	var projectile_count_before := _count_spike_projectiles()
	_player.global_position = _turret.global_position + Vector2(140.0, 0.0)
	await _physics_ticks(8)
	var projectile_count_after := _count_spike_projectiles()
	if projectile_count_after <= projectile_count_before:
		_fail("turret canceled an in-progress shot after player left attack range")
		return

	await _physics_ticks(2)
	if bool(_turret.get("_is_stationary_mode")):
		_fail("turret stayed stationary after shot completed and player left attack range")
		return
	if _turret.velocity.x <= 0.0:
		_fail("turret did not resume chasing after player left attack range")
		return

	print("PASS: spike turret chases, anchors at 0.8 range, fires only while anchored, and resumes chase after shot completion")
	_cleanup()
	get_tree().quit(0)

func _physics_ticks(count: int) -> void:
	for _i in range(maxi(count, 1)):
		await get_tree().physics_frame
		await get_tree().process_frame

func _count_spike_projectiles() -> int:
	var total := 0
	for child in get_tree().root.get_children():
		if child is EnemySpikeProjectile:
			total += 1
	return total

func _fail(message: String) -> void:
	push_error("FAIL: %s" % message)
	_cleanup()
	get_tree().quit(1)

func _cleanup() -> void:
	PlayerData.player = null
	if _turret != null and is_instance_valid(_turret):
		_turret.queue_free()
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
