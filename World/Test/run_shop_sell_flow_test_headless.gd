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
	ui.update_shop()

	var panel := ui.get_node("GUI/ShoppingRootv2/Panel")
	var sell_button := panel.get_node("ShopSellButton")
	var confirm_button := panel.get_node("ShopConfirmButton")
	var cancel_button := panel.get_node("ShopCancelButton")
	var refresh_button := panel.get_node("ShopRefreshButton")
	var back_button := panel.get_node("BackToMerchantMenu")
	var shop := panel.get_node("Shop")
	var first_slot := panel.get_node("Equipped/EquipmentSlotShop") as EquipmentSlotShop
	var sell_slot := panel.get_node("Equipped/EquipmentSlotShop2") as EquipmentSlotShop
	var sell_summary := panel.get_node("ShopSellSummary") as PanelContainer
	var title := panel.get_node("Title") as Label
	var starting_gold := int(PlayerData.player_gold)

	sell_button.call("_on_button_up")
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

	if PlayerData.player_weapon_list.size() != 1 or PlayerData.player_weapon_list.has(weapon_to_sell):
		_fail(10, "ShopSellFlowTest: selected equipped weapon was not removed.")
		return
	if int(PlayerData.player_gold) <= starting_gold:
		_fail(11, "ShopSellFlowTest: selling weapon did not add gold.")
		return
	if InventoryData.temporary_modules.size() != 1 \
			or InventoryData.temporary_modules[0] != module_instance:
		_fail(12, "ShopSellFlowTest: sold weapon module did not move to temporary storage.")
		return
	if not InventoryData.ready_to_sell_list.is_empty():
		_fail(13, "ShopSellFlowTest: ready-to-sell list was not cleared.")
		return
	if sell_button.visible or not confirm_button.visible or not cancel_button.visible \
			or back_button.visible or refresh_button.visible or shop.visible or not sell_slot.sell_mode \
			or not sell_summary.visible or not confirm_button.disabled:
		_fail(14, "ShopSellFlowTest: confirm did not keep an empty sell summary visible.")
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
