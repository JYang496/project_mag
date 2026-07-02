extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail("player scene did not instantiate")
		return
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.global_position = Vector2(8.0, 3.0)
	player.velocity = Vector2.ZERO
	player.move_accel = 5000.0
	var destination := Vector2(48.0, 3.0)
	player.start_auto_nav(destination)
	if not player.is_auto_nav_active():
		_fail("public start_auto_nav did not activate navigation")
		return
	for _frame in range(120):
		if not player.is_auto_nav_active():
			break
		await get_tree().physics_frame
	if player.is_auto_nav_active():
		_fail("navigation did not complete within 120 physics frames")
		return
	if player.global_position.distance_to(destination) > 0.0001:
		_fail("arrival did not snap CharacterBody2D to destination")
		return
	if player.velocity != Vector2.ZERO:
		_fail("arrival did not clear CharacterBody2D velocity")
		return
	if player.is_auto_nav_active():
		_fail("arrival did not complete public auto navigation state")
		return
	if not player.movement_enabled or player.moveto_dest != Vector2.ZERO:
		_fail("arrival did not restore Player-owned movement flags")
		return
	player.queue_free()
	await get_tree().process_frame
	print("PASS: player auto navigation")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("FAIL: player auto navigation: " + message)
	get_tree().quit(1)
