extends Node

func _ready() -> void:
	var original_weapons: Array = PlayerData.player_weapon_list
	var original_max := PlayerData.max_weapon_num
	PlayerData.player_weapon_list = []
	PlayerData.max_weapon_num = 2
	assert(InventoryData.has_open_weapon_slot())
	PlayerData.player_weapon_list = [null, null]
	assert(not InventoryData.has_open_weapon_slot())
	PlayerData.player_weapon_list = original_weapons
	PlayerData.max_weapon_num = original_max
	print("PASS: weapon rewards distinguish open and full weapon bars")
	get_tree().quit()
