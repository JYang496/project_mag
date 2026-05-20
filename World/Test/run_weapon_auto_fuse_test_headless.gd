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
	var starting_level := int(weapon.level)
	var starting_gold := int(PlayerData.player_gold)

	var first_result := player.try_auto_fuse_weapon_obtain(weapon_id)
	if str(first_result.get("result", "")) != "fused" or int(weapon.fuse) != 2:
		push_error("AutoFuseTest: equipped duplicate did not fuse to 2.")
		get_tree().quit(4)
		return
	if int(weapon.level) != starting_level:
		push_error("AutoFuseTest: duplicate fuse changed weapon level.")
		get_tree().quit(5)
		return

	player.try_auto_fuse_weapon_obtain(weapon_id)
	if int(weapon.fuse) != 3:
		push_error("AutoFuseTest: second equipped duplicate did not fuse to 3.")
		get_tree().quit(6)
		return
	var gold_result := player.try_auto_fuse_weapon_obtain(weapon_id)
	if str(gold_result.get("result", "")) != "converted_to_gold" or int(PlayerData.player_gold) <= starting_gold:
		push_error("AutoFuseTest: max-fuse duplicate did not convert to gold.")
		get_tree().quit(7)
		return

	PlayerData.player_weapon_list.erase(weapon)
	var inventory_prediction := player.predict_auto_fuse_weapon_obtain(weapon_id)
	if str(inventory_prediction.get("result", "")) != "not_applicable":
		push_error("AutoFuseTest: inventory-only duplicate was treated as auto-fuse subject.")
		get_tree().quit(8)
		return

	print("AutoFuseTest: PASS")
	get_tree().quit(0)
