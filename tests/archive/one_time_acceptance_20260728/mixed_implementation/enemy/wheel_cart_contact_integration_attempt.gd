# Archived 2026-07-28: duplicated centralized player-contact integration already covered elsewhere.
extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const WHEEL_CART_SCENE := preload("res://Npc/enemy/scenes/enemy_wheel_cart.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

var _failed := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var previous_phase: String = PhaseManager.current_state()
	var previous_player = PlayerData.player
	var previous_hp := PlayerData.player_hp

	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	PlayerData.player = player
	PlayerData.player_hp = 10
	PhaseManager.phase = PhaseManager.BATTLE

	var enemy := WHEEL_CART_SCENE.instantiate() as BaseEnemy
	enemy.global_position = player.global_position
	add_child(enemy)
	enemy.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_expect(not enemy.get_collision_mask_value(1), "wheel cart body must pass through the player layer")
	player.call("_process_centralized_enemy_contact_damage", 0.21)
	_expect(PlayerData.player_hp == 6, "wheel cart overlap must apply its configured contact damage")

	var feedback_controller := player.get_node_or_null("DamageFeedbackController")
	if feedback_controller != null and feedback_controller.has_method("shutdown"):
		feedback_controller.call("shutdown")
	if TimeImpactController.has_method("cancel_active_impact"):
		TimeImpactController.cancel_active_impact(true)
	PhaseManager.phase = previous_phase
	PlayerData.player = previous_player
	PlayerData.player_hp = previous_hp

	print(
		"FAIL wheel cart contact damage"
		if _failed
		else "PASS wheel cart contact damage"
	)
	await TEST_TEARDOWN.finish(self, 1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("FAIL: %s" % message)
