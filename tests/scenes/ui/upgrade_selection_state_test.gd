extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_TEARDOWN := preload("res://tests/infrastructure/test_teardown.gd")

class RestAreaAvailabilityStub:
	extends Node
	func is_module_management_available() -> bool:
		return true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
	PlayerData.player_gold = 999

	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	var rest_area_stub := RestAreaAvailabilityStub.new()
	rest_area_stub.add_to_group("rest_area")
	add_child(rest_area_stub)
	await get_tree().process_frame
	await get_tree().process_frame

	var ui := UI_SCENE.instantiate() as UI
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	ui.ensure_upgrade_management()
	await get_tree().process_frame
	if ui.get_management_item_mode() != &"weapon":
		_fail("Management item mode did not default to weapon for a fresh run.")
		return
	ui.upgrade_management_controller.apply_mode(&"module")
	if ui.get_management_item_mode() != &"module":
		_fail("Upgrade module tab did not update the shared management item mode.")
		return
	ui.ensure_purchase_management()
	ui.purchase_management_controller.ensure_module_shop()
	ui.purchase_management_controller.apply_purchase_mode(ui.get_management_item_mode())
	ui.ensure_warehouse_management()
	ui.module_warehouse_controller.open_tab(ui.get_management_item_mode())
	if ui.purchase_management_controller.purchase_mode != &"module" \
			or ui.module_warehouse_controller.active_tab != &"module":
		_fail("Purchase and warehouse did not open with the shared module state.")
		return

	ui.upgrade_management_controller.apply_mode(&"weapon")
	if ui.get_management_item_mode() != &"weapon":
		_fail("Weapon tab did not restore the shared management item mode.")
		return
	ui.upgrade_management_controller.update_upg()
	var items: Array[Dictionary] = ui.upgrade_management_view.build_items(&"weapon")
	if items.is_empty():
		_fail("UpgradeSelectionStateProbe: no weapon item was available.")
		return
	var weapon := items[0].get("weapon", null) as Weapon
	if weapon == null or not is_instance_valid(weapon):
		_fail("UpgradeSelectionStateProbe: first upgrade row had no valid weapon.")
		return
	var display_model = items[0].get("display_model", null)
	if display_model == null or display_model.current_stats.is_empty():
		_fail("UpgradeSelectionStateProbe: weapon row had no unified display model.")
		return
	if int(weapon.level) < int(weapon.max_level) and display_model.upgrade_deltas.is_empty():
		_fail("UpgradeSelectionStateProbe: upgradeable weapon had no before/after presentation data.")
		return
	var previous_level := int(weapon.level)
	ui.upgrade_management_view.call("_on_item_selected", items[0])
	if ui._upgrade_selected_item.is_empty():
		_fail("UpgradeSelectionStateProbe: selection did not sync back to UI owner state.")
		return
	await get_tree().process_frame
	var detail_body := ui.upgrade_management_view.upgrade_detail_body as VBoxContainer
	var upgrade_summary := detail_body.get_node_or_null("UpgradeChangePanel") as PanelContainer
	var overview_grid := detail_body.get_node_or_null("WeaponOverviewGrid") as GridContainer
	if upgrade_summary == null or detail_body.get_child(0) != upgrade_summary:
		_fail("UpgradeSelectionStateProbe: this-upgrade summary was not the first detail section.")
		return
	if overview_grid == null or overview_grid.columns != 2 or overview_grid.get_child_count() != 4:
		_fail("UpgradeSelectionStateProbe: weapon metadata was not arranged in a compact two-column overview.")
		return
	if upgrade_summary.size.x < detail_body.size.x - 1.0:
		_fail("UpgradeSelectionStateProbe: this-upgrade summary did not fill the available detail width.")
		return
	if ui.upgrade_management_view.upgrade_detail_scroll.scroll_vertical != 0:
		_fail("UpgradeSelectionStateProbe: refreshed weapon details did not return to the upgrade summary.")
		return
	ui.upgrade_management_controller.on_action_pressed()
	if int(weapon.level) != previous_level + 1:
		_fail("UpgradeSelectionStateProbe: selected weapon was not upgraded.")
		return
	var refreshed_selection: Dictionary = ui._upgrade_selected_item
	var refreshed_model = refreshed_selection.get("display_model", null)
	if int(refreshed_selection.get("level", -1)) != int(weapon.level) \
			or refreshed_model == null \
			or int(refreshed_model.level) != int(weapon.level):
		_fail("UpgradeSelectionStateProbe: selected weapon details retained the pre-upgrade snapshot.")
		return
	var refreshed_overview := detail_body.get_node_or_null("WeaponOverviewGrid") as GridContainer
	var level_card := refreshed_overview.get_child(0) as VBoxContainer if refreshed_overview else null
	var level_value := level_card.get_child(1) as Label if level_card and level_card.get_child_count() > 1 else null
	if level_value == null or level_value.text != "Lv.%d/%d" % [int(weapon.level), int(weapon.max_level)]:
		_fail("UpgradeSelectionStateProbe: right-side current level did not refresh after upgrading.")
		return
	var upgraded_level := int(weapon.level)
	var gold_after_rest_upgrade := PlayerData.player_gold
	PhaseManager.phase = PhaseManager.PROTOCOL_SELECTION
	ui.upgrade_management_controller.on_action_pressed()
	if int(weapon.level) != upgraded_level or PlayerData.player_gold != gold_after_rest_upgrade:
		_fail("UpgradeSelectionStateProbe: upgrades must be rejected outside the rest phase.")
		return

	print("PASS: upgrade selection survives controller action sync")
	await TEST_TEARDOWN.finish(self, 0, _reset_runtime_state)

func _fail(message: String) -> void:
	push_error(message)
	print("FAIL: ", message)
	await TEST_TEARDOWN.finish(self, 1, _reset_runtime_state)

func _reset_runtime_state() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.reset_runtime_state()
