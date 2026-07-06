extends Node

const BomberScene := preload("res://Npc/enemy/scenes/enemy_bomber.tscn")
const RESULT_PATH := "user://bomber_fuse_warning_probe_result.txt"

class ProbePlayer:
	extends CharacterBody2D

	func _init() -> void:
		add_to_group("player")
		collision_layer = 17
		collision_mask = 32

func _ready() -> void:
	_clear_result()
	_run_probe.call_deferred()

func _run_probe() -> void:
	var player := ProbePlayer.new()
	player.name = "ProbePlayer"
	player.global_position = Vector2.ZERO
	get_tree().root.add_child(player)

	var player_data := get_tree().root.get_node_or_null("/root/PlayerData")
	if player_data == null:
		_fail("PlayerData autoload missing")
		return
	player_data.player = player

	var bomber := BomberScene.instantiate() as EnemyBomber
	bomber.global_position = Vector2(8.0, 0.0)
	bomber.trigger_radius = 32.0
	bomber.fuse_time = 1.0
	get_tree().root.add_child(bomber)

	for _frame in range(6):
		await get_tree().physics_frame

	var overlay := bomber.get_node_or_null("WarningFlashOverlay") as Sprite2D
	if overlay == null:
		_fail("bomber fuse did not create WarningFlashOverlay")
		return
	if not overlay.visible:
		_fail("bomber fuse warning overlay is not visible")
		return
	if overlay.modulate.r < 0.9 or overlay.modulate.g > 0.25 or overlay.modulate.b > 0.25:
		_fail("bomber fuse warning overlay is not clearly red")
		return

	_pass("PASS: bomber fuse warning overlay is visible and red")
	get_tree().quit(0)

func _pass(message: String) -> void:
	print(message)
	_write_result(message)

func _fail(message: String) -> void:
	var formatted := "FAIL: %s" % message
	push_error(formatted)
	_write_result(formatted)
	get_tree().quit(1)

func _clear_result() -> void:
	if FileAccess.file_exists(RESULT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULT_PATH))

func _write_result(message: String) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(message)
