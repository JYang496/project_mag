extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail(1, "ShopSellFlowTest: failed to instantiate player.")
		return
	get_tree().root.add_child(player)
	await get_tree().process_frame
	player.create_weapon("5")
	if PlayerData.player_weapon_list.size() != 2:
		_fail(2, "ShopSellFlowTest: failed to prepare two equipped weapons.")
		return

	var weapon_to_sell := PlayerData.player_weapon_list[1] as Weapon
	var module_instance := TEST_MODULE_SCENE.instantiate() as Module
	var equip_result := InventoryData.equip_module_to_weapon(module_instance, weapon_to_sell, null, true)
	if not equip_result.get("ok", false):
		_fail(3, "ShopSellFlowTest: failed to equip module fixture.")
		return

	var ui := UI_SCENE.instantiate() as UI
	if ui == null:
		_fail(4, "ShopSellFlowTest: failed to instantiate UI.")
		return
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	ui.purchase_management_controller.update_shop()

	var panel := ui.purchase_panel
	if panel == null:
		_fail(16, "ShopSellFlowTest: purchase management panel is missing.")
		return
	var sell_button := ui.shop_sell_button
	var confirm_button := ui.shop_confirm_button
	var cancel_button := ui.shop_cancel_button
	var refresh_button := ui.shop_refresh_button
	var back_button := ui.shop_back_button
	var shop := ui.shop
	var first_slot := ui.equipped_shop.get_node("EquipmentSlotShop") as EquipmentSlotShop
	var sell_slot := ui.equipped_shop.get_node("EquipmentSlotShop2") as EquipmentSlotShop
	var sell_summary := ui.shop_sell_summary_panel
	var title := panel.get_node("Title") as Label
	var starting_gold := int(PlayerData.player_gold)

	ui.purchase_management_controller.set_sell_mode(true)
	if not sell_summary.visible or not confirm_button.visible or back_button.visible or not confirm_button.disabled \
			or title.text != LocalizationManager.tr_key("ui.shop.sell.panel_title", "Sell Weapons"):
		_fail(5, "ShopSellFlowTest: sell mode did not show an unobstructed confirm action.")
		return
	sell_slot.click_sell_equipment()
	var selected_label := sell_slot.background.get_node("SellSelectedLabel") as Label
	if not selected_label.visible or confirm_button.disabled:
		_fail(6, "ShopSellFlowTest: selected weapon did not receive clear sell feedback.")
		return
	if ui.shop_sell_summary_list.get_child_count() != 1 \
			or not str(ui.shop_sell_summary_list.get_child(0).text).contains(
				LocalizationManager.get_weapon_name_from_node(weapon_to_sell)
			):
		_fail(7, "ShopSellFlowTest: sell summary did not list the selected weapon.")
		return
	first_slot.click_sell_equipment()
	if InventoryData.ready_to_sell_list.size() != 1 or first_slot.ready_to_sell:
		_fail(8, "ShopSellFlowTest: sell mode allowed every equipped weapon to be selected.")
		return
	sell_slot.click_sell_equipment()
	if not InventoryData.ready_to_sell_list.is_empty() or not confirm_button.disabled \
			or selected_label.visible:
		_fail(9, "ShopSellFlowTest: deselect did not restore the empty summary state.")
		return
	sell_slot.click_sell_equipment()
	confirm_button.call("_on_button_up")
	await get_tree().process_frame

	if PlayerData.player_weapon_list.size() != 2 or not PlayerData.player_weapon_list.has(weapon_to_sell):
		_fail(10, "ShopSellFlowTest: disabled legacy sell flow removed an equipped weapon.")
		return
	if int(PlayerData.player_gold) != starting_gold:
		_fail(11, "ShopSellFlowTest: disabled legacy sell flow changed gold.")
		return
	if not InventoryData.temporary_modules.is_empty() or module_instance.get_parent() != weapon_to_sell.modules:
		_fail(12, "ShopSellFlowTest: disabled legacy sell flow moved weapon modules.")
		return
	if not InventoryData.ready_to_sell_list.is_empty():
		_fail(13, "ShopSellFlowTest: ready-to-sell list was not cleared.")
		return
	if not sell_button.visible or confirm_button.visible or cancel_button.visible \
			or not back_button.visible or not refresh_button.visible or not shop.visible or sell_slot.sell_mode \
			or sell_summary.visible:
		_fail(14, "ShopSellFlowTest: disabled legacy sell flow did not return to purchase mode.")
		return

	var last_weapon := PlayerData.player_weapon_list[0] as Weapon
	var last_weapon_result := InventoryData.sell_equipped_weapon(last_weapon)
	if last_weapon_result.get("ok", false) or not PlayerData.player_weapon_list.has(last_weapon):
		_fail(15, "ShopSellFlowTest: the last equipped weapon was allowed to be sold.")
		return

	InventoryData.reset_runtime_state()
	print("ShopSellFlowTest: PASS")
	get_tree().quit(0)

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
