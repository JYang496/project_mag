extends Node

const PlayerScene := preload("res://Player/Mechas/scenes/Player.tscn")
const EnemyScene := preload("res://Npc/enemy/scenes/enemy_rolling_ball.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false
var _last_player_damage_feedback: Dictionary = {}

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
	if not PlayerData.player_damage_received.is_connected(_on_player_damage_received):
		PlayerData.player_damage_received.connect(_on_player_damage_received)
	PhaseManager.phase = PhaseManager.BATTLE
	var spawning_enemy := EnemyScene.instantiate() as BaseEnemy
	spawning_enemy.damage = 5
	spawning_enemy.global_position = player.global_position
	spawning_enemy.prepare_spawn_sequence(0.12)
	add_child(spawning_enemy)
	var spawn_position := spawning_enemy.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var spawning_hurt_box := spawning_enemy.get_node("HurtBox") as HurtBox
	_expect(spawning_enemy.is_spawn_phase_active(), "enemy spawn phase ended before its telegraph duration")
	_expect(not spawning_enemy.can_process(), "spawning enemy combat processing was not disabled")
	_expect(spawning_enemy.global_position.is_equal_approx(spawn_position), "spawning enemy moved before activation")
	_expect(spawning_hurt_box.collision_layer == 0 and not spawning_hurt_box.monitorable, "spawning enemy HurtBox remained available for contact or weapon hits")
	player.call("_process_centralized_enemy_contact_damage", 0.21)
	_expect(PlayerData.player_hp == 5, "spawning enemy dealt contact damage before activation")
	await spawning_enemy.spawn_phase_completed
	_expect(not spawning_enemy.is_spawn_phase_active(), "enemy did not leave spawn phase after reconstruction")
	_expect(spawning_enemy.can_process(), "enemy combat processing was not restored after spawn")
	_expect(spawning_hurt_box.collision_layer == 4 and spawning_hurt_box.monitorable, "enemy HurtBox was not restored after spawn")
	spawning_enemy.queue_free()
	await get_tree().process_frame
	PlayerData.player_hp = 5
	var enemy := EnemyScene.instantiate() as BaseEnemy
	enemy.damage = 2
	enemy.global_position = player.global_position
	add_child(enemy)
	enemy.set_physics_process(false)
	var stronger_enemy := EnemyScene.instantiate() as BaseEnemy
	stronger_enemy.damage = 4
	stronger_enemy.global_position = player.global_position + Vector2(5.0, 0.0)
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
	_expect(not _last_player_damage_feedback.is_empty(), "applied player damage did not emit unified feedback data")
	_expect(int(_last_player_damage_feedback.get("final_damage", 0)) == 4, "feedback did not report the resolved strongest damage")
	_expect((_last_player_damage_feedback.get("direction", Vector2.ZERO) as Vector2).x > 0.0, "feedback did not preserve the attack's screen direction")
	var feedback_controller := player.get_node_or_null("DamageFeedbackController")
	_expect(feedback_controller != null, "player damage feedback controller was not installed")
	if feedback_controller != null:
		feedback_controller.call("_process", 0.02)
		_expect(bool(feedback_controller.call("is_invulnerability_feedback_active")), "hurt cooldown did not activate invulnerability feedback")
		var screen_layer := feedback_controller.get_node_or_null("PlayerDamageScreenLayer") as CanvasLayer
		var vignette := screen_layer.get_node_or_null("DamageVignette") if screen_layer != null else null
		_expect(vignette != null and float(vignette.call("get_feedback_strength")) > 0.0, "player hit did not activate the screen-edge vignette")
		var damage_audio := feedback_controller.get_node_or_null("PlayerDamageAudio") as AudioStreamPlayer
		_expect(damage_audio != null and damage_audio.stream != null, "player hit did not prepare its impact audio")
		_expect(screen_layer != null and screen_layer.get_node_or_null("DamageImpactRing") != null, "player hit did not spawn the character impact ring")
		_expect(screen_layer != null and screen_layer.get_node_or_null("PlayerDamageNumber") != null, "player hit did not spawn the negative world-space damage number")
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
	if feedback_controller != null and feedback_controller.has_method("shutdown"):
		feedback_controller.call("shutdown")
	if TimeImpactController.has_method("cancel_active_impact"):
		TimeImpactController.cancel_active_impact(true)
	if PlayerData.player_damage_received.is_connected(_on_player_damage_received):
		PlayerData.player_damage_received.disconnect(_on_player_damage_received)
	PlayerData.player = previous_player
	PlayerData.player_hp = previous_hp
	if _failed:
		push_error("FAIL: centralized contact and object pool")
	else:
		print("PASS: centralized enemy contact and reusable object pool")
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FAIL: " + message)

func _on_player_damage_received(feedback: Dictionary) -> void:
	_last_player_damage_feedback = feedback.duplicate(true)
