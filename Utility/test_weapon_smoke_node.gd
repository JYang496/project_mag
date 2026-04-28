extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_data := get_node_or_null("/root/PlayerData")
	if player_data == null:
		push_error("SmokeTest: PlayerData autoload missing.")
		get_tree().quit(11)
		return
	var phase_manager := get_node_or_null("/root/PhaseManager")
	var player := PLAYER_SCENE.instantiate()
	if player == null:
		push_error("SmokeTest: failed to instantiate player scene.")
		get_tree().quit(1)
		return
	get_tree().root.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	if player_data.player_weapon_list.is_empty():
		push_error("SmokeTest: player has no weapon after spawn.")
		get_tree().quit(2)
		return

	var weapon: Variant = player_data.player_weapon_list[0]
	if weapon == null or not is_instance_valid(weapon):
		push_error("SmokeTest: weapon instance invalid.")
		get_tree().quit(3)
		return

	if weapon.get("current_ammo") == null:
		push_error("SmokeTest: weapon has no ammo runtime fields.")
		get_tree().quit(4)
		return

	var target := Vector2(640.0, 360.0)
	weapon.set_meta("_benchmark_mouse_target", target)
	player.set_meta("_benchmark_mouse_target", target)

	if phase_manager != null:
		phase_manager.phase = phase_manager.PREPARE
	await get_tree().process_frame
	if weapon.get("is_on_cooldown") != null:
		weapon.set("is_on_cooldown", false)
	var fired_in_prepare := bool(weapon.call("request_primary_fire"))
	var ammo_prepare_after := int(weapon.get("current_ammo"))

	if phase_manager and phase_manager.has_method("enter_battle"):
		phase_manager.enter_battle()
	await get_tree().process_frame
	if weapon.get("is_on_cooldown") != null:
		weapon.set("is_on_cooldown", false)
	var ammo_before := int(weapon.get("current_ammo"))
	var fired := bool(weapon.call("request_primary_fire"))
	await get_tree().process_frame
	var ammo_after := int(weapon.get("current_ammo"))

	weapon.set("current_ammo", 0)
	if weapon.get("is_on_cooldown") != null:
		weapon.set("is_on_cooldown", false)
	var fired_with_empty := bool(weapon.call("request_primary_fire"))
	await get_tree().process_frame
	var reload_started := bool(weapon.get("is_reloading"))

	weapon.set("reload_time_left", 0.0)
	weapon.call("_update_reload_state", 0.1)
	await get_tree().process_frame
	var ammo_reloaded := int(weapon.get("current_ammo"))
	var ammo_max := int(weapon.get("magazine_capacity"))
	var reload_finished := not bool(weapon.get("is_reloading")) and ammo_reloaded >= ammo_max

	print("SmokeTest fired_in_prepare=", fired_in_prepare, " ammo_prepare_after=", ammo_prepare_after)
	print("SmokeTest fired=", fired, " fired_with_empty=", fired_with_empty)
	print("SmokeTest ammo_before=", ammo_before, " ammo_after=", ammo_after, " ammo_reloaded=", ammo_reloaded, " ammo_max=", ammo_max)
	print("SmokeTest reload_started=", reload_started, " reload_finished=", reload_finished)

	if fired_in_prepare:
		push_error("SmokeTest: attack should be blocked during prepare phase.")
		get_tree().quit(9)
		return
	if not fired:
		push_error("SmokeTest: request_primary_fire returned false.")
		get_tree().quit(5)
		return
	if ammo_prepare_after != ammo_before:
		push_error("SmokeTest: ammo changed during blocked prepare phase fire.")
		get_tree().quit(10)
		return
	if ammo_after >= ammo_before:
		push_error("SmokeTest: ammo did not decrease after firing.")
		get_tree().quit(6)
		return
	if not reload_started:
		push_error("SmokeTest: reload did not start on empty fire.")
		get_tree().quit(7)
		return
	if not reload_finished:
		push_error("SmokeTest: reload did not finish back to magazine capacity.")
		get_tree().quit(8)
		return

	print("SmokeTest: PASS")
	get_tree().quit(0)
