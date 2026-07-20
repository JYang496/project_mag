extends Node

const PlayerScene := preload("res://Player/Mechas/scenes/Player.tscn")
const EnemyScene := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")

var _failed := false

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var previous_phase: String = PhaseManager.current_state()
	var previous_player = PlayerData.player
	var previous_hp := PlayerData.player_hp
	var player := PlayerScene.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	PlayerData.player = player
	PlayerData.player_hp = 5
	PhaseManager.phase = PhaseManager.BATTLE
	var enemy := EnemyScene.instantiate() as BaseEnemy
	enemy.damage = 2
	enemy.global_position = player.global_position
	add_child(enemy)
	enemy.set_physics_process(false)
	var stronger_enemy := EnemyScene.instantiate() as BaseEnemy
	stronger_enemy.damage = 4
	stronger_enemy.global_position = player.global_position
	add_child(stronger_enemy)
	stronger_enemy.set_physics_process(false)
	var nearby_but_not_overlapping := EnemyScene.instantiate() as BaseEnemy
	nearby_but_not_overlapping.damage = 99
	nearby_but_not_overlapping.global_position = player.global_position + Vector2(29.0, 0.0)
	add_child(nearby_but_not_overlapping)
	nearby_but_not_overlapping.set_physics_process(false)
	_expect(enemy.get_node_or_null("HitBoxDot") == null, "enemy still owns a per-instance contact Area2D")
	_expect(stronger_enemy.get_node_or_null("HitBoxDot") == null, "second enemy still owns a per-instance contact Area2D")
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.call("_process_centralized_enemy_contact_damage", 0.21)
	_expect(PlayerData.player_hp == 1, "HurtBox contact batch did not select exactly one strongest overlapping enemy hit")
	player.call("_process_centralized_enemy_contact_damage", 0.21)
	_expect(PlayerData.player_hp == 1, "contact damage bypassed the player's invulnerability deadline")
	var packed := PackedScene.new()
	var template := Node2D.new()
	packed.pack(template)
	template.free()
	var first := ObjectPool.acquire(packed)
	add_child(first)
	var first_id := first.get_instance_id()
	ObjectPool.release(first)
	var second := ObjectPool.acquire(packed)
	_expect(second.get_instance_id() == first_id, "ObjectPool did not reuse a released short-lived node")
	ObjectPool.release(second)
	# Simulate legacy code freeing an object after it has already entered the pool.
	# acquire() must discard the stale Variant without attempting to cast it.
	second.free()
	var replacement := ObjectPool.acquire(packed)
	_expect(replacement != null and is_instance_valid(replacement), "ObjectPool did not recover from a freed cached object")
	ObjectPool.release(replacement)
	PhaseManager.phase = previous_phase
	PlayerData.player = previous_player
	PlayerData.player_hp = previous_hp
	if _failed:
		push_error("FAIL: centralized contact and object pool")
		get_tree().quit(1)
		return
	print("PASS: centralized enemy contact and reusable object pool")
	get_tree().quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)
