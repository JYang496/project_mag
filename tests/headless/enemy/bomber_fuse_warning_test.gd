extends Node

const BomberScene := preload("res://Npc/enemy/scenes/enemy_bomber.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

class ProbePlayer:
	extends CharacterBody2D

	func _init() -> void:
		add_to_group("player")
		collision_layer = 17
		collision_mask = 32

func _ready() -> void:
	_run_probe.call_deferred()

func _run_probe() -> void:
	var player := ProbePlayer.new()
	player.name = "ProbePlayer"
	player.global_position = Vector2.ZERO
	add_child(player)

	var player_data := get_tree().root.get_node_or_null("/root/PlayerData")
	if player_data == null:
		_fail("PlayerData autoload missing")
		return
	player_data.player = player

	var bomber := BomberScene.instantiate() as EnemyBomber
	bomber.global_position = Vector2(8.0, 0.0)
	bomber.trigger_radius = 32.0
	bomber.fuse_time = 1.0
	add_child(bomber)

	for _frame in range(6):
		await get_tree().physics_frame

	var overlay := bomber.get_node_or_null("Body/WarningFlashOverlay") as Sprite2D
	if overlay == null:
		_fail("bomber fuse did not create WarningFlashOverlay")
		return
	if not overlay.visible:
		_fail("bomber fuse warning overlay is not visible")
		return
	_pass("PASS: bomber fuse exposes visible warning feedback")
	await TEST_TEARDOWN.finish(self, 0, PlayerData.reset_runtime_state)

func _pass(message: String) -> void:
	print(message)

func _fail(message: String) -> void:
	var formatted := "FAIL: %s" % message
	push_error(formatted)
	await TEST_TEARDOWN.finish(self, 1, PlayerData.reset_runtime_state)
