extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		push_error("AutoFuseTest: failed to instantiate player.")
		get_tree().quit(1)
		return
	get_tree().root.add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	if PlayerData.player_weapon_list.is_empty():
		push_error("AutoFuseTest: player has no initial weapon.")
		get_tree().quit(2)
		return
	var weapon := PlayerData.player_weapon_list[0] as Weapon
	if weapon == null:
		push_error("AutoFuseTest: initial weapon is invalid.")
		get_tree().quit(3)
		return
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	var expected_max_level := 9
	if int(weapon.max_level) < expected_max_level:
		push_error("AutoFuseTest: weapon max level is still capped by fuse. max_level=%d" % int(weapon.max_level))
		get_tree().quit(4)
		return
	weapon.set_level(expected_max_level)
	var starting_level := int(weapon.level)
	if starting_level != expected_max_level:
		push_error("AutoFuseTest: fuse 1 weapon could not level to its data max. level=%d" % starting_level)
		get_tree().quit(5)
		return
	var starting_gold := int(PlayerData.player_gold)

	var first_result := player.try_auto_fuse_weapon_obtain(weapon_id)
	if str(first_result.get("result", "")) != "fused" or int(weapon.fuse) != 2:
		push_error("AutoFuseTest: equipped duplicate did not fuse to 2.")
		get_tree().quit(6)
		return
	if int(weapon.level) != starting_level:
		push_error("AutoFuseTest: duplicate fuse changed weapon level.")
		get_tree().quit(7)
		return

	player.try_auto_fuse_weapon_obtain(weapon_id)
	if int(weapon.fuse) != 3:
		push_error("AutoFuseTest: second equipped duplicate did not fuse to 3.")
		get_tree().quit(8)
		return
	if int(weapon.level) != starting_level:
		push_error("AutoFuseTest: second duplicate fuse changed weapon level.")
		get_tree().quit(9)
		return
	var gold_result := player.try_auto_fuse_weapon_obtain(weapon_id)
	if str(gold_result.get("result", "")) != "converted_to_gold" or int(PlayerData.player_gold) <= starting_gold:
		push_error("AutoFuseTest: max-fuse duplicate did not convert to gold.")
		get_tree().quit(10)
		return

	PlayerData.player_weapon_list.erase(weapon)
	var unequipped_prediction := player.predict_auto_fuse_weapon_obtain(weapon_id)
	if str(unequipped_prediction.get("result", "")) != "not_applicable":
		push_error("AutoFuseTest: an unequipped weapon was treated as an auto-fuse subject.")
		get_tree().quit(11)
		return

	print("AutoFuseTest: PASS")
	get_tree().quit(0)
