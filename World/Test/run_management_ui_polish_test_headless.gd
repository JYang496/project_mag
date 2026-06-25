extends Node

const PLAYER_SCENE := preload("res://Player/Mechas/scenes/Player.tscn")
const UI_SCENE := preload("res://UI/scenes/UI.tscn")
const TEST_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_damage_up_stat.tscn")
const EQUIPPED_MODULE_SCENE := preload("res://Player/Weapons/Modules/wmod_fast_reload.tscn")
const REUSABLE_PRIMARY_MENU_SCRIPT := preload("res://UI/scripts/management/reusable_primary_menu.gd")

class RestAreaAvailabilityStub:
	extends Node
	func is_module_management_available() -> bool:
		return true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	PlayerData.reset_runtime_state()
	InventoryData.reset_runtime_state()
	PhaseManager.phase = PhaseManager.PREPARE
	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	var rest_area_stub := RestAreaAvailabilityStub.new()
	rest_area_stub.add_to_group("rest_area")
	get_tree().root.add_child(rest_area_stub)
	await get_tree().process_frame
	var module_instance := TEST_MODULE_SCENE.instantiate() as Module
	InventoryData.obtain_module(module_instance)

	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	ui.upgrade_management_controller.update_upg()
	ui.module_warehouse_controller.update_modules()
	ui.purchase_management_controller.apply_purchase_mode(&"weapon")
	if ui.module_shop_list_view != null:
		_fail(28, "ManagementUIPolishTest: module shop was created before first module purchase open.")
		return
	if ui.shop.position != Vector2(25, 104) or ui.shop.size != Vector2(500, 419):
		_fail(29, "ManagementUIPolishTest: first weapon purchase list layout starts from the mode buttons.")
		return
	var warehouse_module_button := ui.warehouse_primary_panel.get_node_or_null("OpenModuleButton") as Button
	if ui.weapon_warehouse_button == null or not is_instance_valid(ui.weapon_warehouse_button):
		_fail(36, "ManagementUIPolishTest: warehouse primary menu is missing the weapon warehouse button.")
		return
	if warehouse_module_button == null:
		_fail(37, "ManagementUIPolishTest: warehouse primary menu is missing the module warehouse button.")
		return
	if not _primary_menu_layout_matches(ui.purchase_primary_panel, [
		ui.purchase_primary_panel.get_node_or_null("OpenBuyButton") as Button,
		ui.purchase_primary_panel.get_node_or_null("OpenSellButton") as Button,
	]):
		_fail(38, "ManagementUIPolishTest: purchase primary menu layout does not match the shared style.")
		return
	if not _primary_menu_layout_matches(ui.upgrade_primary_panel, [
		ui.upgrade_primary_panel.get_node_or_null("OpenUpgradeButton") as Button,
		ui.upgrade_module_button,
	]):
		_fail(53, "ManagementUIPolishTest: upgrade primary menu layout does not match the shared style.")
		return
	if not _primary_menu_layout_matches(ui.warehouse_primary_panel, [
		ui.weapon_warehouse_button,
		warehouse_module_button,
	]):
		_fail(54, "ManagementUIPolishTest: warehouse primary menu layout does not match the shared style.")
		return
	var reusable_menu := REUSABLE_PRIMARY_MENU_SCRIPT.new()
	ui.gui_root.add_child(reusable_menu)
	reusable_menu.configure(
		"Service",
		"Choose an action",
		[
			{"id": &"first", "text": "First"},
			{"id": &"second", "text": "Second"},
		],
		ui.management_ui_style_helper
	)
	if not _primary_menu_layout_matches(reusable_menu.get_panel(), reusable_menu.get_buttons()):
		_fail(55, "ManagementUIPolishTest: reusable primary menu layout does not match the shared style.")
		return
	reusable_menu.queue_free()
	var warehouse_tabs := ui.module_management_view.get_node_or_null("WarehouseTabs") as Control
	if warehouse_tabs == null or warehouse_tabs.visible:
		_fail(39, "ManagementUIPolishTest: secondary warehouse view still shows internal tabs.")
		return

	for path in [
		"GUI/PurchaseRoot/ShoppingRootv2/Panel/ShopInstruction",
		"GUI/UpgradeRoot/UpgradeRootv2/Panel/UpgradeInstruction",
		"GUI/WarehouseRoot/ModuleManagementRoot/Panel/ModuleInstruction",
	]:
		var instruction := ui.get_node_or_null(path) as Label
		if instruction == null:
			_fail(1, "ManagementUIPolishTest: missing management instruction at %s." % path)
			return

	for button in [
		ui.shop_sell_button,
		ui.upgrade_action_button,
		ui.module_equip_button,
		ui.module_sell_button,
	]:
		if button == null or button.size.y < 44.0:
			_fail(2, "ManagementUIPolishTest: action button is missing or too small.")
			return
	for panel in [ui.purchase_panel, ui.upgrade_panel, ui.module_panel]:
		if panel == null or panel.mouse_filter != Control.MOUSE_FILTER_STOP:
			_fail(34, "ManagementUIPolishTest: secondary management panel does not stop mouse input.")
			return
		if not panel.gui_input.is_connected(Callable(ui, "_on_management_panel_gui_input").bind(panel)):
			_fail(35, "ManagementUIPolishTest: secondary management panel does not consume panel clicks.")
			return

	var click := InputEventAction.new()
	click.action = "CLICK"
	click.pressed = true
	var selected_weapon := PlayerData.player_weapon_list[0] as Weapon
	if selected_weapon == null:
		_fail(3, "ManagementUIPolishTest: missing equipped weapon fixture.")
		return
	var stored_weapon := _instantiate_first_unequipped_weapon()
	if stored_weapon == null:
		_fail(9, "ManagementUIPolishTest: failed to create stored weapon fixture.")
		return
	InventoryData.store_weapon(stored_weapon)
	var equipped_module := EQUIPPED_MODULE_SCENE.instantiate() as Module
	selected_weapon.modules.add_child(equipped_module)
	await get_tree().process_frame
	ui.upgrade_management_controller.update_upg()
	var weapon_items: Array[Dictionary] = ui.upgrade_management_controller.build_items(&"weapon")
	var module_items: Array[Dictionary] = ui.upgrade_management_controller.build_items(&"module")
	var first_upgrade_row := ui.upgrade_item_list.get_child(0) as Button
	if first_upgrade_row == null or first_upgrade_row.custom_minimum_size.y < 92.0:
		_fail(16, "ManagementUIPolishTest: upgrade rows are too short for full item content.")
		return
	var row_height := first_upgrade_row.custom_minimum_size.y
	var fifth_visible := ui.upgrade_item_scroll.size.y - (4.0 * row_height + 4.0 * 8.0)
	if fifth_visible <= 0.0 or fifth_visible >= row_height * 0.5:
		_fail(18, "ManagementUIPolishTest: weapon upgrade list does not show 4.x rows per page.")
		return
	var first_row_icon := first_upgrade_row.get_node_or_null("RowMargin/Row/ItemIcon") as TextureRect
	if first_row_icon == null or first_row_icon.custom_minimum_size.x < 72.0:
		_fail(17, "ManagementUIPolishTest: upgrade row icon is too small.")
		return
	if not _is_primary_button(ui.upgrade_weapon_mode_button) or _is_primary_button(ui.upgrade_module_mode_button):
		_fail(19, "ManagementUIPolishTest: weapon upgrade mode button highlight is invalid.")
		return
	ui.upgrade_management_controller.apply_mode(&"module")
	if not (ui.upgrade_item_list is VBoxContainer):
		_fail(20, "ManagementUIPolishTest: module upgrade list is not row-based.")
		return
	if ui.upgrade_item_list.get_child_count() <= 0:
		_fail(21, "ManagementUIPolishTest: module upgrade rows were not created.")
		return
	var first_module_row := ui.upgrade_item_list.get_child(0) as HBoxContainer
	if first_module_row == null or first_module_row.get_child_count() > 2:
		_fail(22, "ManagementUIPolishTest: module upgrade row does not contain at most two items.")
		return
	if first_module_row.get_child_count() >= 2:
		var first_module_card := first_module_row.get_child(0) as Button
		var second_module_card := first_module_row.get_child(1) as Button
		var occupied_width := first_module_card.custom_minimum_size.x + second_module_card.custom_minimum_size.x + 8.0
		if occupied_width < ui.upgrade_item_scroll.size.x * 0.95:
			_fail(27, "ManagementUIPolishTest: module upgrade cards do not fill the row width.")
			return
	var module_row_height := first_module_row.custom_minimum_size.y
	var module_fifth_visible := ui.upgrade_item_scroll.size.y - (4.0 * module_row_height + 4.0 * 8.0)
	if module_fifth_visible <= 0.0 or module_fifth_visible >= module_row_height * 0.5:
		_fail(23, "ManagementUIPolishTest: module upgrade list does not show 4.x rows per page.")
		return
	if not _is_primary_button(ui.upgrade_module_mode_button) or _is_primary_button(ui.upgrade_weapon_mode_button):
		_fail(24, "ManagementUIPolishTest: module upgrade mode button highlight is invalid.")
		return
	ui.purchase_management_controller.apply_purchase_mode(&"module")
	if not _is_primary_button(ui.shop_module_mode_button) or _is_primary_button(ui.shop_weapon_mode_button):
		_fail(25, "ManagementUIPolishTest: module purchase mode button highlight is invalid.")
		return
	ui.purchase_management_controller.apply_purchase_mode(&"weapon")
	if not _is_primary_button(ui.shop_weapon_mode_button) or _is_primary_button(ui.shop_module_mode_button):
		_fail(26, "ManagementUIPolishTest: weapon purchase mode button highlight is invalid.")
		return
	if not _has_item_with_location(weapon_items, stored_weapon, "weapon", "仓库"):
		_fail(10, "ManagementUIPolishTest: stored weapon was missing from upgrade list.")
		return
	if not _has_item_with_location(module_items, module_instance, "module", "临时仓库"):
		_fail(11, "ManagementUIPolishTest: temporary module location was missing.")
		return
	if not _has_item_with_location(module_items, equipped_module, "module", "已装备:"):
		_fail(12, "ManagementUIPolishTest: equipped module weapon location was missing.")
		return
	if _any_item_params_contains_upgrade_preview(weapon_items) or _any_item_params_contains_upgrade_preview(module_items):
		_fail(13, "ManagementUIPolishTest: upgrade list still previews next-level values.")
		return
	ui.upgrade_management_controller.on_item_selected(_find_item_for_ref(weapon_items, stored_weapon, "weapon"))
	ui.upgrade_management_controller.refresh_detail()
	if _detail_text(ui).contains("->") or _detail_text(ui).contains("下一级"):
		_fail(14, "ManagementUIPolishTest: weapon detail still previews next-level values.")
		return
	ui.upgrade_management_controller.on_item_selected(_find_item_for_ref(module_items, module_instance, "module"))
	ui.upgrade_management_controller.refresh_detail()
	if _detail_text(ui).contains("->") or _detail_text(ui).contains("下一级"):
		_fail(15, "ManagementUIPolishTest: module detail still previews next-level values.")
		return
	ui.upgrade_management_controller.apply_mode(&"weapon")
	ui.upgrade_management_controller.on_item_selected(_find_item_for_ref(weapon_items, selected_weapon, "weapon"))
	var level_before := int(selected_weapon.level)
	PlayerData.player_gold = 999999
	ui.upgrade_management_controller.update_upg()
	if ui.upgrade_action_button.disabled:
		_fail(4, "ManagementUIPolishTest: explicit upgrade action did not become available.")
		return
	ui.upgrade_management_controller.on_action_pressed()
	if int(selected_weapon.level) != level_before + 1:
		_fail(5, "ManagementUIPolishTest: explicit upgrade action did not upgrade the selected weapon.")
		return

	ui.module_warehouse_controller.open_tab(&"module")
	ui.module_management_view.select_module(module_instance, null)
	if not _has_module_install_targets_label(ui.module_management_view):
		_fail(49, "ManagementUIPolishTest: temporary module card does not show install target types.")
		return
	if ui.selected_temporary_module != module_instance:
		_fail(6, "ManagementUIPolishTest: module click did not select the module.")
		return
	if ui.module_equip_selection_panel != null and ui.module_equip_selection_panel.visible:
		_fail(7, "ManagementUIPolishTest: module click still opened the equip modal immediately.")
		return
	if ui.module_sell_button.disabled:
		_fail(8, "ManagementUIPolishTest: module selection did not enable explicit actions.")
		return
	var first_socket := _find_first_enabled_socket(ui.module_management_view)
	if first_socket == null:
		_fail(30, "ManagementUIPolishTest: unified module warehouse did not expose an enabled compatible socket.")
		return
	first_socket.emit_signal("pressed")
	await get_tree().process_frame
	if InventoryData.temporary_modules.has(module_instance):
		_fail(31, "ManagementUIPolishTest: clicking a compatible socket did not install the selected temporary module.")
		return
	if module_instance.get_parent() != selected_weapon.modules:
		_fail(32, "ManagementUIPolishTest: selected module was not reparented to the target weapon modules.")
		return
	if ui.module_equip_selection_panel != null and ui.module_equip_selection_panel.visible:
		_fail(33, "ManagementUIPolishTest: direct socket install opened the old equip modal.")
		return
	var replacement_module := _instantiate_compatible_temporary_module(selected_weapon, module_instance)
	if replacement_module == null:
		_fail(40, "ManagementUIPolishTest: failed to create a compatible drag replacement module.")
		return
	InventoryData.obtain_module(replacement_module)
	ui.module_warehouse_controller.open_tab(&"module")
	var module_drag: Dictionary = ui.module_management_view.build_drag_data({"kind": "temporary_module", "module": replacement_module})
	if _get_module_weapon_card_highlight(ui.module_management_view, selected_weapon) != "compatible":
		_fail(50, "ManagementUIPolishTest: compatible drag target weapon was not highlighted as compatible.")
		return
	if not ui.module_management_view.drop_payload({"kind": "module_slot", "weapon": selected_weapon, "existing": module_instance, "slot_index": 0}, module_drag):
		_fail(41, "ManagementUIPolishTest: dragging a temporary module to an occupied slot did not replace it.")
		return
	await get_tree().process_frame
	if replacement_module.get_parent() != selected_weapon.modules:
		_fail(42, "ManagementUIPolishTest: dragged replacement module was not installed on the weapon.")
		return
	if not InventoryData.temporary_modules.has(module_instance):
		_fail(43, "ManagementUIPolishTest: replaced module did not return to temporary storage.")
		return
	var equipped_drag: Dictionary = ui.module_management_view.build_drag_data({"kind": "equipped_module", "module": replacement_module, "weapon": selected_weapon})
	if not ui.module_management_view.drop_payload({"kind": "temporary_module_area"}, equipped_drag):
		_fail(44, "ManagementUIPolishTest: dragging an equipped module to temporary storage did not unequip it.")
		return
	await get_tree().process_frame
	if not InventoryData.temporary_modules.has(replacement_module):
		_fail(45, "ManagementUIPolishTest: unequipped drag module was not in temporary storage.")
		return
	var incompatible_module := _instantiate_incompatible_temporary_module(selected_weapon)
	if incompatible_module == null:
		_fail(51, "ManagementUIPolishTest: failed to create an incompatible drag module fixture.")
		return
	InventoryData.obtain_module(incompatible_module)
	ui.module_warehouse_controller.open_tab(&"module")
	ui.module_management_view.build_drag_data({"kind": "temporary_module", "module": incompatible_module})
	if _get_module_weapon_card_highlight(ui.module_management_view, selected_weapon) != "blocked":
		_fail(52, "ManagementUIPolishTest: incompatible drag target weapon was not highlighted as blocked.")
		return
	InventoryData.temporary_modules.erase(incompatible_module)
	incompatible_module.queue_free()

	ui.module_warehouse_controller.open_tab(&"weapon")
	var weapon_drag: Dictionary = ui.module_management_view.build_drag_data({"kind": "stored_weapon", "weapon": stored_weapon})
	if not ui.module_management_view.drop_payload({"kind": "equipped_weapon", "weapon": selected_weapon}, weapon_drag):
		_fail(46, "ManagementUIPolishTest: dragging a stored weapon onto a held weapon did not exchange them.")
		return
	await get_tree().process_frame
	if not PlayerData.player_weapon_list.has(stored_weapon):
		_fail(47, "ManagementUIPolishTest: dragged stored weapon was not equipped after exchange.")
		return
	if not InventoryData.weapon_storage.has(selected_weapon):
		_fail(48, "ManagementUIPolishTest: exchanged held weapon was not moved to weapon storage.")
		return

	InventoryData.reset_runtime_state()
	rest_area_stub.queue_free()
	print("ManagementUIPolishTest: PASS")
	get_tree().quit(0)

func _instantiate_first_unequipped_weapon() -> Weapon:
	var equipped_id := ""
	if not PlayerData.player_weapon_list.is_empty():
		equipped_id = DataHandler.get_weapon_id_from_instance(PlayerData.player_weapon_list[0] as Weapon)
	for weapon_id in DataHandler.get_weapon_ids():
		if weapon_id == equipped_id:
			continue
		var definition := DataHandler.read_weapon_data(weapon_id) as WeaponDefinition
		if definition and definition.scene:
			return definition.scene.instantiate() as Weapon
	return null

func _has_item_with_location(items: Array[Dictionary], ref: Object, ref_key: String, expected_location: String) -> bool:
	for item in items:
		if item.get(ref_key, null) == ref and str(item.get("location", "")).contains(expected_location):
			return true
	return false

func _find_item_for_ref(items: Array[Dictionary], ref: Object, ref_key: String) -> Dictionary:
	for item in items:
		if item.get(ref_key, null) == ref:
			return item
	return {}

func _any_item_params_contains_upgrade_preview(items: Array[Dictionary]) -> bool:
	for item in items:
		if str(item.get("params", "")).contains(">"):
			return true
	return false

func _detail_text(ui: UI) -> String:
	var parts := PackedStringArray()
	for child in ui.upgrade_detail_body.get_children():
		var label := child as Label
		if label:
			parts.append(label.text)
	return "\n".join(parts)

func _is_primary_button(button: Button) -> bool:
	if button == null:
		return false
	var style := button.get_theme_stylebox("normal") as StyleBoxFlat
	if style == null:
		return false
	return style.bg_color.is_equal_approx(Color(0.12, 0.38, 0.58))

func _primary_menu_layout_matches(panel: Panel, buttons: Array) -> bool:
	if panel == null:
		return false
	var title := panel.get_node_or_null("Title") as Label
	var subtitle := panel.get_node_or_null("SubTitle") as Label
	if title == null or subtitle == null:
		return false
	if title.position != Vector2(28, 16) or not is_equal_approx(title.size.x, 256.0):
		print("Primary menu title mismatch: ", panel.get_path(), " pos=", title.position, " size=", title.size)
		return false
	if subtitle.position != Vector2(28, 48) or not is_equal_approx(subtitle.size.x, 256.0):
		print("Primary menu subtitle mismatch: ", panel.get_path(), " pos=", subtitle.position, " size=", subtitle.size)
		return false
	var expected_positions := [Vector2(28, 108), Vector2(28, 166)]
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if button == null:
			return false
		if button.position != expected_positions[index] or button.size != Vector2(220, 46):
			print("Primary menu button mismatch: ", panel.get_path(), " index=", index, " pos=", button.position, " size=", button.size)
			return false
		var style := button.get_theme_stylebox("normal") as StyleBoxFlat
		if style == null or not style.bg_color.is_equal_approx(Color(0.12, 0.18, 0.25)):
			print("Primary menu style mismatch: ", panel.get_path(), " index=", index, " color=", style.bg_color if style else Color.BLACK)
			return false
	return true

func _find_first_enabled_socket(view: ModuleManagementView) -> Button:
	if view == null:
		return null
	for node in _collect_nodes(view):
		var button := node as Button
		if button != null \
				and not button.disabled \
				and button.custom_minimum_size == Vector2(84, 76) \
				and bool(button.get_meta("slot_feedback_ok", true)):
			return button
	return null

func _has_module_install_targets_label(view: ModuleManagementView) -> bool:
	for node in _collect_nodes(view):
		var label := node as Label
		if label != null and label.name == "InstallTargets" and not label.text.strip_edges().is_empty():
			return true
	return false

func _get_module_weapon_card_highlight(view: ModuleManagementView, weapon: Weapon) -> String:
	for node in _collect_nodes(view):
		var panel := node as PanelContainer
		if panel != null \
				and panel.name == "ModuleWeaponCard" \
				and panel.get_meta("weapon", null) == weapon:
			return str(panel.get_meta("drag_highlight", ""))
	return ""

func _instantiate_compatible_temporary_module(weapon: Weapon, replaced_module: Module) -> Module:
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Modules"):
		if not file_name.ends_with(".tscn"):
			continue
		var scene_path := "res://Player/Weapons/Modules/%s" % file_name
		if InventoryData.find_owned_module_by_scene_path(scene_path) != null:
			continue
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		var module_instance := scene.instantiate() as Module
		if module_instance == null:
			continue
		var feedback := InventoryData.get_weapon_module_assignment_feedback(module_instance, weapon, replaced_module, false)
		if bool(feedback.get("ok", false)):
			return module_instance
		module_instance.queue_free()
	return null

func _instantiate_incompatible_temporary_module(weapon: Weapon) -> Module:
	for file_name in DirAccess.get_files_at("res://Player/Weapons/Modules"):
		if not file_name.ends_with(".tscn"):
			continue
		var scene_path := "res://Player/Weapons/Modules/%s" % file_name
		if InventoryData.find_owned_module_by_scene_path(scene_path) != null:
			continue
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		var module_instance := scene.instantiate() as Module
		if module_instance == null:
			continue
		var feedback := InventoryData.get_weapon_module_assignment_feedback(module_instance, weapon, null, false)
		if not bool(feedback.get("ok", false)) and str(feedback.get("reason", "")) != "Only one module of each type can be owned.":
			return module_instance
		module_instance.queue_free()
	return null

func _collect_nodes(root: Node) -> Array[Node]:
	var output: Array[Node] = [root]
	for child in root.get_children():
		output.append_array(_collect_nodes(child))
	return output

func _fail(code: int, message: String) -> void:
	push_error(message)
	InventoryData.reset_runtime_state()
	get_tree().quit(code)
