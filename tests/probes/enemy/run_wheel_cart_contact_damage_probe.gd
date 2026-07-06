extends Node

const WheelCartScene := preload("res://Npc/enemy/scenes/enemy_wheel_cart.tscn")
const HurtBoxScene := preload("res://Combat/collision/hurt_box.tscn")
const RESULT_PATH := "user://wheel_cart_contact_damage_probe_result.txt"

class ProbePlayer:
	extends CharacterBody2D

	var received_damage: int = 0

	func _init() -> void:
		add_to_group("player")
		collision_layer = 17
		collision_mask = 32
		var body_shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(19.0, 27.0)
		body_shape.shape = rect
		add_child(body_shape)

	func damaged(attack: Attack) -> void:
		if attack == null:
			return
		received_damage += int(attack.damage)

func _ready() -> void:
	_clear_result()
	_run_probe.call_deferred()

func _run_probe() -> void:
	var player := ProbePlayer.new()
	player.name = "ProbePlayer"
	player.global_position = Vector2.ZERO
	get_tree().root.add_child(player)

	var hurt_box := HurtBoxScene.instantiate() as HurtBox
	hurt_box.collision_layer = 1
	var hurt_shape := hurt_box.get_node("CollisionShape2D") as CollisionShape2D
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Vector2(21.0, 37.0)
	hurt_shape.position = Vector2(1.5, -3.5)
	hurt_shape.shape = hurt_rect
	player.add_child(hurt_box)

	var player_data := get_tree().root.get_node_or_null("/root/PlayerData")
	if player_data == null:
		_fail("PlayerData autoload missing")
		return
	player_data.player = player

	var enemy := WheelCartScene.instantiate() as BaseEnemy
	enemy.global_position = Vector2(80.0, 0.0)
	enemy.movement_speed = 120.0
	enemy.chase_acceleration = 240.0
	enemy.max_speed_multiplier = 1.0
	get_tree().root.add_child(enemy)

	await get_tree().process_frame
	await get_tree().physics_frame

	if enemy.get_collision_mask_value(1):
		_fail("wheel cart still collides with the player body layer")
		return

	for frame in range(90):
		await get_tree().physics_frame
		if player.received_damage > 0:
			_pass("PASS: wheel cart contact dealt %d damage after %d physics frames" % [player.received_damage, frame + 1])
			get_tree().quit(0)
			return

	_fail("wheel cart reached contact window without damaging the player")

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
