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
	get_tree().root.add_child(player)
	await get_tree().process_frame
	var module_instance := TEST_MODULE_SCENE.instantiate() as Module
	InventoryData.obtain_module(module_instance)

	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	ui.update_upg()
	ui.update_modules()

	for path in [
		"GUI/ShoppingRootv2/Panel/ShopInstruction",
		"GUI/UpgradeRootv2/Panel/UpgradeInstruction",
		"GUI/ModuleRoot/Panel/ModuleInstruction",
	]:
		var instruction := ui.get_node_or_null(path) as Label
		if instruction == null or instruction.text.is_empty():
			_fail(1, "ManagementUIPolishTest: missing management instruction at %s." % path)
			return

	for path in [
		"GUI/ShoppingRootv2/Panel/ShopSellButton",
		"GUI/UpgradeRootv2/Panel/UpgradeActionButton",
		"GUI/ModuleRoot/Panel/ModuleEquipButton",
		"GUI/ModuleRoot/Panel/ModuleSellButton",
	]:
		var button := ui.get_node_or_null(path) as Button
		if button == null or button.size.y < 44.0:
			_fail(2, "ManagementUIPolishTest: action button is missing or too small at %s." % path)
			return

	var upgrade_slot := ui.get_node("GUI/UpgradeRootv2/Panel/Equipped/EquipmentSlotUpg") as EquipmentSlotUpgrade
	var click := InputEventAction.new()
	click.action = "CLICK"
	click.pressed = true
	upgrade_slot._on_background_gui_input(click)
	var selected_upgrade_label := upgrade_slot.get_node_or_null("UpgradeSelectedLabel") as Label
	if selected_upgrade_label == null or not selected_upgrade_label.visible:
		_fail(3, "ManagementUIPolishTest: selected upgrade weapon has no persistent marker.")
		return
	var selected_weapon := InventoryData.on_select_upg as Weapon
	var level_before := int(selected_weapon.level)
	PlayerData.player_gold = 999999
	ui.update_upg()
	if ui.upgrade_action_button.disabled:
		_fail(4, "ManagementUIPolishTest: explicit upgrade action did not become available.")
		return
	ui.upgrade_action_button.pressed.emit()
	if int(selected_weapon.level) != level_before + 1:
		_fail(5, "ManagementUIPolishTest: explicit upgrade action did not upgrade the selected weapon.")
		return

	var module_slot := ui.modules.get_child(0) as ModuleSlot
	module_slot._on_background_gui_input(click)
	if ui.selected_temporary_module != module_instance:
		_fail(6, "ManagementUIPolishTest: module click did not select the module.")
		return
	if ui.module_equip_selection_panel != null and ui.module_equip_selection_panel.visible:
		_fail(7, "ManagementUIPolishTest: module click still opened the equip modal immediately.")
		return
	if ui.module_equip_button.disabled or ui.module_sell_button.disabled or not module_slot.selected:
		_fail(8, "ManagementUIPolishTest: module selection did not enable explicit actions.")
		return

	InventoryData.reset_runtime_state()
	print("ManagementUIPolishTest: PASS")
	get_tree().quit(0)

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
