extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const DASH_SCENE := preload("res://Player/Skills/dash.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.BATTLE
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail("player scene did not instantiate")
		return
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.set_physics_process(false)
	player.global_position = Vector2(40.0, 20.0)
	player.velocity = Vector2.RIGHT * 100.0
	player.movement_enabled = true
	var dash := DASH_SCENE.instantiate()
	if dash == null:
		_fail("dash scene did not instantiate")
		return
	player.add_child(dash)
	await get_tree().process_frame
	await get_tree().process_frame
	dash.set("energy_cost", 0.0)
	dash.set("cooldown", 0.0)
	dash.set("dash_distance", 30.0)
	dash.set("dash_duration", 0.05)
	var expected_position := player.global_position + Vector2.RIGHT * 30.0
	dash.call("activate_skill")
	if player.movement_enabled:
		_fail("dash did not temporarily disable Player-owned movement")
		return
	await get_tree().create_timer(0.12).timeout
	if player.global_position.distance_to(expected_position) > 0.5:
		_fail(
			"dash position changed: expected=%s actual=%s"
			% [str(expected_position), str(player.global_position)]
		)
		return
	if not player.movement_enabled:
		_fail("dash did not restore Player-owned movement state")
		return
	player.queue_free()
	await get_tree().process_frame
	print("PASS: player dash movement integration")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("FAIL: player dash movement integration: " + message)
	get_tree().quit(1)
