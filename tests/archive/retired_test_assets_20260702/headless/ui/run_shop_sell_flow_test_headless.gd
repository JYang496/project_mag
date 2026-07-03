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

	var protected_weapon := PlayerData.player_weapon_list[1] as Weapon
	var module_instance := TEST_MODULE_SCENE.instantiate() as Module
	var equip_result := InventoryData.equip_module_to_weapon(module_instance, protected_weapon, null, true)
	if not equip_result.get("ok", false):
		_fail(3, "ShopSellFlowTest: failed to equip module fixture.")
		return

	var ui := UI_SCENE.instantiate() as UI
	if ui == null:
		_fail(4, "ShopSellFlowTest: failed to instantiate UI.")
		return
	get_tree().root.add_child(ui)
	await get_tree().process_frame

	var view := ui.purchase_management_view as PurchaseManagementView
	if view == null:
		_fail(5, "ShopSellFlowTest: purchase management view is missing.")
		return
	for legacy_node_name in [
		"Equipped",
		"ShopSellButton",
		"ShopCancelButton",
		"ShopConfirmButton",
		"ShopSellSummary",
	]:
		if view.get_node_or_null(legacy_node_name) != null:
			_fail(6, "ShopSellFlowTest: purchase shell still exposes %s." % legacy_node_name)
			return
	if ui.purchase_management_controller.has_method("set_sell_mode"):
		_fail(7, "ShopSellFlowTest: purchase controller still exposes the legacy sell mode.")
		return
	if ui.shop_purchase_button == null or not ui.shop_purchase_button.visible \
			or ui.shop_refresh_button == null or not ui.shop_refresh_button.visible \
			or ui.shop_back_button == null or not ui.shop_back_button.visible:
		_fail(8, "ShopSellFlowTest: purchase shell is missing a supported merchant action.")
		return
	if ui.shop_purchase_button.text != LocalizationManager.tr_key("ui.shop.buy", "购买"):
		_fail(9, "ShopSellFlowTest: merchant action is not labeled as a purchase.")
		return

	var starting_gold := int(PlayerData.player_gold)
	var sell_result := InventoryData.sell_equipped_weapon(protected_weapon)
	if sell_result.get("ok", false):
		_fail(10, "ShopSellFlowTest: warehouse-managed equipped weapon was sold.")
		return
	if not PlayerData.player_weapon_list.has(protected_weapon) \
			or int(PlayerData.player_gold) != starting_gold:
		_fail(11, "ShopSellFlowTest: rejected weapon sale mutated player inventory or gold.")
		return
	if not InventoryData.temporary_modules.is_empty() \
			or module_instance.get_parent() != protected_weapon.modules:
		_fail(12, "ShopSellFlowTest: rejected weapon sale moved an equipped module.")
		return

	InventoryData.reset_runtime_state()
	print("ShopSellFlowTest: PASS")
	get_tree().quit(0)

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
