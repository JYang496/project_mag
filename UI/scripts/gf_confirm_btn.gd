extends Button

#@onready var ui : UI = get_tree().get_first_node_in_group("ui")

func _on_button_up() -> void:
	InventoryData.clear_on_select()
	if InventoryData.ready_to_fuse_list.size() != 2:
		return
	
	# Mutate first weapon with higher max level
	var fused_item : Weapon = InventoryData.ready_to_fuse_list[0].duplicate()
	var new_fuse: int = clampi(max(InventoryData.ready_to_fuse_list[0].fuse,InventoryData.ready_to_fuse_list[1].fuse)+1, 1, fused_item.FINAL_MAX_FUSE)
	var new_level: int = max(InventoryData.ready_to_fuse_list[0].level,InventoryData.ready_to_fuse_list[1].level)
	fused_item.fuse = new_fuse
	fused_item.level = clampi(new_level, 1, fused_item.max_level)
	for fuse_item : Weapon in InventoryData.ready_to_fuse_list:
		for module in fuse_item.modules.get_children():
			var module_copy = module.duplicate()
			InventoryData.moddule_slots.append(module_copy)
		if InventoryData.inventory_slots.has(fuse_item):
			InventoryData.inventory_slots.erase(fuse_item)
			fuse_item.queue_free()
		elif PlayerData.player_weapon_list.has(fuse_item):
			PlayerData.player_weapon_list.erase(fuse_item)
			fuse_item.queue_free()
	InventoryData.ready_to_fuse_list.clear()
	PlayerData.player.create_weapon(fused_item)
	GlobalVariables.ui.update_gf()
	GlobalVariables.ui.refresh_border()
