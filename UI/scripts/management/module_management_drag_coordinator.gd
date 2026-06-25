extends RefCounted
class_name ModuleManagementDragCoordinator

var owner_view: Node
var left_list: VBoxContainer
var status_label: Label
var card_factory: RefCounted
var active_drag_module: Module

func bind(view: Node, list: VBoxContainer, status: Label, factory: RefCounted) -> void:
	owner_view = view
	left_list = list
	status_label = status
	card_factory = factory

func set_context(list: VBoxContainer, status: Label, factory: RefCounted) -> void:
	left_list = list
	status_label = status
	card_factory = factory

func handle_drag_end() -> void:
	if active_drag_module == null:
		return
	active_drag_module = null
	refresh_module_drag_highlights()

func build_drag_data(payload: Dictionary, source_control: Control = null) -> Dictionary:
	if payload.is_empty():
		return {}
	if str(payload.get("kind", "")) == "temporary_module":
		active_drag_module = payload.get("module", null) as Module
		refresh_module_drag_highlights()
	var preview := build_drag_preview(payload)
	if source_control != null and preview != null:
		source_control.set_drag_preview(preview)
	return {"warehouse_drag": true, "payload": payload}

func can_drop_payload(target: Dictionary, data: Variant) -> bool:
	var result := get_drop_feedback(target, data)
	_set_status_text(str(result.get("reason", "")))
	return bool(result.get("ok", false))

func drop_payload(target: Dictionary, data: Variant) -> bool:
	var result := get_drop_feedback(target, data)
	if not bool(result.get("ok", false)):
		_set_status_text(str(result.get("reason", "")))
		return false
	var payload: Dictionary = data.get("payload", {})
	var action_result := perform_drop_action(target, payload)
	if not bool(action_result.get("ok", false)):
		_set_status_text(str(action_result.get("reason", "")))
		return false
	clear_drag_selection(payload)
	active_drag_module = null
	if owner_view != null and owner_view.has_method("refresh_all"):
		owner_view.call("refresh_all")
	return true

func get_drop_feedback(target: Dictionary, data: Variant) -> Dictionary:
	if not (data is Dictionary) or not bool(data.get("warehouse_drag", false)):
		return {"ok": false, "reason": ""}
	var payload: Dictionary = data.get("payload", {})
	var source_kind := str(payload.get("kind", ""))
	var target_kind := str(target.get("kind", ""))
	match target_kind:
		"weapon_storage_area":
			if source_kind != "equipped_weapon":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.warehouse.drag.invalid_target", "Drop this item on a compatible warehouse target.")}
			var equipped_weapon := payload.get("weapon", null) as Weapon
			if equipped_weapon == null or not PlayerData.player_weapon_list.has(equipped_weapon):
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.invalid_equipped", "Invalid held weapon.")}
			if PlayerData.player_weapon_list.size() <= 1:
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.keep_one", "At least one weapon must remain equipped.")}
			return {"ok": true, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_store", "Release to store this weapon.")}
		"held_empty_slot":
			if source_kind != "stored_weapon":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_stored_only", "Only stored weapons can be equipped into an empty slot.")}
			var stored_weapon := payload.get("weapon", null) as Weapon
			if stored_weapon == null or not InventoryData.weapon_storage.has(stored_weapon):
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.invalid_stored", "Invalid stored weapon.")}
			if PlayerData.player_weapon_list.size() >= int(PlayerData.max_weapon_num):
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.no_empty_slot", "No weapon slots available.")}
			return {"ok": true, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_equip", "Release to equip this weapon.")}
		"equipped_weapon":
			if source_kind != "stored_weapon":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_stored_exchange", "Drop a stored weapon on a held weapon to exchange.")}
			var exchange_stored := payload.get("weapon", null) as Weapon
			var exchange_equipped := target.get("weapon", null) as Weapon
			if exchange_stored == null or exchange_equipped == null:
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.invalid_exchange", "Invalid weapon exchange.")}
			if not InventoryData.weapon_storage.has(exchange_stored) or not PlayerData.player_weapon_list.has(exchange_equipped):
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.invalid_exchange", "Invalid weapon exchange.")}
			return {"ok": true, "reason": LocalizationManager.tr_key("ui.weapon.warehouse.drop_exchange", "Release to exchange these weapons.")}
		"module_slot":
			if source_kind != "temporary_module":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.drag.drop_temp_only", "Drop a temporary module on a weapon slot to install it.")}
			var module_instance := payload.get("module", null) as Module
			var weapon := target.get("weapon", null) as Weapon
			var existing := target.get("existing", null) as Module
			return InventoryData.get_weapon_module_assignment_feedback(module_instance, weapon, existing, false)
		"temporary_module_area":
			if source_kind != "equipped_module":
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.drag.drop_equipped_only", "Drop an installed module here to unequip it.")}
			var equipped_module := payload.get("module", null) as Module
			var owner_weapon := payload.get("weapon", null) as Weapon
			if equipped_module == null or owner_weapon == null:
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.drag.invalid_module", "Invalid module.")}
			if owner_weapon.modules == null or equipped_module.get_parent() != owner_weapon.modules:
				return {"ok": false, "reason": LocalizationManager.tr_key("ui.module.drag.not_equipped", "Module is not equipped.")}
			return {"ok": true, "reason": LocalizationManager.tr_key("ui.module.drag.drop_unequip", "Release to unequip this module.")}
	return {"ok": false, "reason": LocalizationManager.tr_key("ui.warehouse.drag.invalid_target", "Drop this item on a compatible warehouse target.")}

func perform_drop_action(target: Dictionary, payload: Dictionary) -> Dictionary:
	match str(target.get("kind", "")):
		"weapon_storage_area":
			return InventoryData.store_weapon(payload.get("weapon", null) as Weapon)
		"held_empty_slot":
			return InventoryData.equip_stored_weapon(payload.get("weapon", null) as Weapon)
		"equipped_weapon":
			return InventoryData.exchange_stored_weapon(payload.get("weapon", null) as Weapon, target.get("weapon", null) as Weapon)
		"module_slot":
			return InventoryData.equip_module_to_weapon(payload.get("module", null) as Module, target.get("weapon", null) as Weapon, target.get("existing", null) as Module, false)
		"temporary_module_area":
			return InventoryData.unequip_module_from_weapon(payload.get("module", null) as Module, payload.get("weapon", null) as Weapon)
	return {"ok": false, "reason": LocalizationManager.tr_key("ui.warehouse.drag.invalid_target", "Drop this item on a compatible warehouse target.")}

func clear_drag_selection(payload: Dictionary) -> void:
	if owner_view == null:
		return
	match str(payload.get("kind", "")):
		"stored_weapon", "equipped_weapon":
			owner_view.set("selected_stored_weapon", null)
			owner_view.set("selected_equipped_weapon", null)
		"temporary_module", "equipped_module":
			owner_view.set("selected_module", null)
			owner_view.set("selected_equipped_module", null)
			owner_view.set("selected_equipped_module_weapon", null)
			if owner_view.has_method("_sync_owner_selection"):
				owner_view.call("_sync_owner_selection")

func build_drag_preview(payload: Dictionary) -> Control:
	if card_factory == null or not card_factory.has_method("build_drag_preview"):
		return null
	return card_factory.call("build_drag_preview", payload) as Control

func refresh_module_drag_highlights() -> void:
	if left_list == null or owner_view == null:
		return
	if owner_view.get("active_tab") != &"module":
		return
	for child in left_list.get_children():
		var panel := child as PanelContainer
		if panel == null or panel.name != "ModuleWeaponCard":
			continue
		var weapon := panel.get_meta("weapon", null) as Weapon
		if weapon != null and is_instance_valid(weapon) and card_factory != null:
			card_factory.call("apply_module_weapon_card_style", panel, weapon, active_drag_module)

func can_drag_module_install_on_weapon(module_instance: Module, weapon: Weapon) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	if weapon == null or not is_instance_valid(weapon):
		return false
	if weapon.modules == null:
		return false
	var installed: Array[Module] = []
	for child in weapon.modules.get_children():
		var existing := child as Module
		if existing != null and is_instance_valid(existing):
			installed.append(existing)
	for existing in installed:
		var replace_feedback := InventoryData.get_weapon_module_assignment_feedback(module_instance, weapon, existing, false)
		if bool(replace_feedback.get("ok", false)):
			return true
	if installed.size() < int(weapon.MAX_MODULE_NUMBER):
		var empty_feedback := InventoryData.get_weapon_module_assignment_feedback(module_instance, weapon, null, false)
		return bool(empty_feedback.get("ok", false))
	return false

func _set_status_text(text: String) -> void:
	if status_label != null:
		status_label.text = text
