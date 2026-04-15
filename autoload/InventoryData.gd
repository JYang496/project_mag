extends Node

var INVENTORY_MAX_SLOTS : int = 8
var MAX_FUSE_SIZE : int = 2
const MODULE_DUPLICATE_BASE_CONVERT_COINS: int = 6
var inventory_slots : Array = []
var moddule_slots : Array = []
var ready_to_sell_list : Array = []
var ready_to_fuse_list : Array = []
#@onready var ui : UI = get_tree().get_first_node_in_group("ui")
#@onready var player : Player = get_tree().get_first_node_in_group("player")

func _get_ui():
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui):
		return ui
	return null

func _safe_refresh_all_panels() -> void:
	var ui = _get_ui()
	if ui == null:
		return
	ui.update_modules()
	ui.update_inventory()
	ui.update_shop()
	ui.refresh_border()

func _safe_update_inventory_and_border() -> void:
	var ui = _get_ui()
	if ui == null:
		return
	ui.update_inventory()
	ui.refresh_border()

func _safe_update_upg() -> void:
	var ui = _get_ui()
	if ui == null:
		return
	ui.update_upg()

func _safe_update_gf() -> void:
	var ui = _get_ui()
	if ui == null:
		return
	ui.update_gf()

func _safe_set_drag_icon(texture) -> void:
	var ui = _get_ui()
	if ui == null or not ui.drag_item_icon:
		return
	ui.drag_item_icon.texture = texture

func _notify_module_message(message: String, duration: float = 1.8) -> void:
	var ui = _get_ui()
	if ui and ui.has_method("show_item_message"):
		ui.show_item_message(message, duration)

func _get_localized_module_name(module_instance: Module) -> String:
	if module_instance == null or not is_instance_valid(module_instance):
		return ""
	return LocalizationManager.get_module_name(module_instance)

func get_weapon_module_assignment_feedback(module_instance: Module, weapon: Weapon) -> Dictionary:
	if module_instance == null or not is_instance_valid(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	if weapon == null or not is_instance_valid(weapon):
		return {"ok": false, "reason": "Invalid weapon."}
	if weapon.modules == null:
		return {"ok": false, "reason": "Weapon has no module container."}
	if weapon.get_module_count() >= int(weapon.MAX_MODULE_NUMBER):
		return {"ok": false, "reason": "No module slots available."}
	var reason: String = str(module_instance.get_incompatibility_reason(weapon))
	if reason != "":
		return {"ok": false, "reason": reason}
	return {"ok": true, "reason": ""}

func equip_module_to_weapon(module_instance: Module, weapon: Weapon) -> Dictionary:
	var feedback := get_weapon_module_assignment_feedback(module_instance, weapon)
	if not feedback.get("ok", false):
		return feedback
	if module_instance.get_parent() != null:
		module_instance.reparent(weapon.modules)
	else:
		weapon.modules.add_child(module_instance)
	moddule_slots.erase(module_instance)
	if weapon.has_method("calculate_status"):
		weapon.calculate_status()
	_safe_refresh_all_panels()
	return {"ok": true, "reason": ""}

func unequip_module_from_weapon(module_instance: Module, weapon: Weapon) -> Dictionary:
	if module_instance == null or not is_instance_valid(module_instance):
		return {"ok": false, "reason": "Invalid module."}
	if weapon == null or not is_instance_valid(weapon):
		return {"ok": false, "reason": "Invalid weapon."}
	if module_instance.get_parent() == null:
		return {"ok": false, "reason": "Module is not equipped."}
	module_instance.reparent(self)
	if not moddule_slots.has(module_instance):
		moddule_slots.append(module_instance)
	if weapon.has_method("calculate_status"):
		weapon.calculate_status()
	_safe_refresh_all_panels()
	return {"ok": true, "reason": ""}

# At this stage, on_select_module should not do anything
var on_select_module :
	get:
		return on_select_module
	#set(value):
		#if value != null and on_select_module == null and on_select_inventory_module == null:
			##on_select_module = value
			##on_drag_item = on_select_module
			#on_drag_item = null
			#on_select_module = null
			#print("module was empt, assign value")
		#elif value != null and on_select_module != null and on_select_inventory_module == null:
			## Clear the drag and on select value, no swap action taken
			#on_drag_item = null
			#on_select_module = null
		#elif value != null and on_select_module == null and on_select_inventory_module != null:
			## Swap module between weapon and inv, no swap action taken
			#on_drag_item = null
			#on_select_inventory_module = null
		#elif value == null and on_select_module == null and on_select_inventory_module != null:
			## Install module into a weapon
			#on_drag_item = null
			#on_select_inventory_module = null
		#else:
			#on_select_module = value
			#on_drag_item = on_select_module
		#ui.update_modules()
		#ui.update_inventory()
		#ui.update_shop()
		#ui.refresh_border()

var on_select_module_weapon :
	get:
		return on_select_module_weapon
	set(value):
		if value != null and on_select_inventory_module != null and on_select_module == null:
			var result := equip_module_to_weapon(on_select_inventory_module, value)
			if not result.get("ok", false):
				push_warning(
					"Module '%s' cannot be equipped on '%s': %s" %
					[on_select_inventory_module.name, value.name, str(result.get("reason", ""))]
				)
				var reason_text := LocalizationManager.localize_module_reason(str(result.get("reason", "Cannot equip module.")))
				_notify_module_message(LocalizationManager.tr_format("ui.module.cannot_equip", {"reason": reason_text}, "Cannot equip: %s" % reason_text))
				on_drag_item = null
			on_select_inventory_module = null

var on_select_inventory_module :
	get:
		return on_select_inventory_module
	set(value):
		if value != null and on_select_inventory_module == null and on_select_module == null:
			# Pick module in inv
			on_select_inventory_module = value
			on_drag_item = on_select_inventory_module
		elif value != null and on_select_inventory_module != null and on_select_module == null:
			# Swap position in inventory
			on_drag_item = null
			on_select_inventory_module = null
		elif value != null and on_select_inventory_module == null and on_select_module != null:
			# Put weapon module into inv, not gonna work
			on_drag_item = null
			on_select_module = null
		else:
			on_select_inventory_module = value
			on_drag_item = on_select_inventory_module

var on_select_eqp :
	get:
		return on_select_eqp
	set(value):
		if value != null and on_select_eqp == null and on_select_slot == null:
			# Pick equipment
			on_select_eqp = value
			on_drag_item = on_select_eqp
		elif value != null and on_select_eqp != null and on_select_slot == null:
			# Swap position
			on_drag_item = null
			if value != on_select_eqp:
				PlayerData.player.swap_weapon_position(on_select_eqp,value)
			on_select_eqp = null
		elif value != null and on_select_eqp == null and on_select_slot != null:
			# Swap eqp and slot
			on_select_eqp = value
			slot_eqp_swap()
		elif value == null and on_select_eqp == null and on_select_slot != null:
			# Put item from inv to equipment
			on_drag_item = null
			inventory_slots.erase(on_select_slot)
			PlayerData.player.create_weapon(on_select_slot)
			on_select_slot = null
		else:
			on_select_eqp = value
			on_drag_item = on_select_eqp
		_safe_refresh_all_panels()

var on_select_slot :
	get:
		return on_select_slot
	set(value) :
		on_select_slot = value
		on_drag_item = on_select_slot
		if on_select_slot != null and on_select_eqp != null:
			slot_eqp_swap()
		elif on_select_slot == null and on_select_eqp != null:
			on_drag_item = null
			var copy_eqp = on_select_eqp.duplicate()
			if not self.inventory_slots.has(copy_eqp):
				copy_eqp.level = on_select_eqp.level
				self.inventory_slots.append(copy_eqp)
				PlayerData.player_weapon_list.erase(on_select_eqp)
				on_select_eqp.queue_free()
			on_select_eqp = null
		_safe_update_inventory_and_border()

func slot_eqp_swap() -> void:
	# Swap eqp and slot
	on_drag_item = null
	var copy_eqp = on_select_eqp.duplicate()
	if not self.inventory_slots.has(copy_eqp):
		copy_eqp.level = on_select_eqp.level
		self.inventory_slots.append(copy_eqp)
		PlayerData.player_weapon_list.erase(on_select_eqp)
		on_select_eqp.queue_free()
		inventory_slots.erase(on_select_slot)
		PlayerData.player.create_weapon(on_select_slot)
	on_select_eqp = null
	on_select_slot = null
	on_select_eqp = null

var on_select_upg :
	get:
		return on_select_upg
	set(value):
		on_select_upg = value
		_safe_update_upg()

var on_select_eqp_gf :
	get:
		return on_select_eqp_gf
	set(value):
		add_fuse_item(value)
		on_select_eqp_gf = value
		_safe_update_gf()

var on_select_slot_gf :
	get:
		return on_select_slot_gf
	set(value):
		add_fuse_item(value)
		on_select_slot_gf = value
		_safe_update_gf()

func add_fuse_item(item) -> void:
	if ready_to_fuse_list.size() < MAX_FUSE_SIZE and not ready_to_fuse_list.has(item):
		if ready_to_fuse_list.size() == 0 or item.ITEM_NAME == ready_to_fuse_list[0].ITEM_NAME:
			ready_to_fuse_list.append(item)
		_safe_update_gf()

func obtain_module(module_instance: Module, ignore_weapon: Weapon = null) -> void:
	if module_instance == null:
		return
	module_instance.set_module_level(module_instance.module_level)
	var existing_module: Module = _find_existing_module_by_name(module_instance.get_module_display_name(), ignore_weapon)
	if existing_module == null:
		moddule_slots.append(module_instance)
		_notify_module_message(LocalizationManager.tr_format(
			"ui.inventory.obtain",
			{"name": _get_localized_module_name(module_instance), "level": module_instance.module_level},
			"Obtained %s Lv.%d" % [_get_localized_module_name(module_instance), module_instance.module_level]
		))
		_safe_refresh_all_panels()
		return
	if existing_module.increase_module_level(1):
		_discard_module_instance(module_instance, existing_module)
		_notify_module_message(LocalizationManager.tr_format(
			"ui.inventory.upgrade",
			{"name": _get_localized_module_name(existing_module), "level": existing_module.module_level},
			"Upgraded %s to Lv.%d" % [_get_localized_module_name(existing_module), existing_module.module_level]
		))
		var owner_weapon: Weapon = _resolve_module_owner_weapon(existing_module)
		if owner_weapon and owner_weapon.has_method("calculate_status"):
			owner_weapon.calculate_status()
		_safe_refresh_all_panels()
		return
	_discard_module_instance(module_instance, existing_module)
	var convert_coins: int = _calculate_module_conversion_coins(existing_module)
	PlayerData.player_gold += convert_coins
	_notify_module_message(LocalizationManager.tr_format(
		"ui.inventory.convert",
		{"name": _get_localized_module_name(existing_module), "gold": convert_coins},
		"Converted duplicate %s into +%d Gold" % [_get_localized_module_name(existing_module), convert_coins]
	))
	_safe_refresh_all_panels()

func _find_existing_module_by_name(module_name: String, ignore_weapon: Weapon = null) -> Module:
	var normalized_name: String = module_name.strip_edges().to_lower()
	if normalized_name == "":
		return null
	for inv_module_ref in moddule_slots:
		var inv_module: Module = inv_module_ref as Module
		if inv_module == null or not is_instance_valid(inv_module):
			continue
		if inv_module.get_module_display_name().strip_edges().to_lower() == normalized_name:
			return inv_module
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon: Weapon = weapon_ref as Weapon
		if weapon == null or not is_instance_valid(weapon):
			continue
		if ignore_weapon != null and weapon == ignore_weapon:
			continue
		if weapon.modules == null:
			continue
		for child in weapon.modules.get_children():
			var equipped_module: Module = child as Module
			if equipped_module == null:
				continue
			if equipped_module.get_module_display_name().strip_edges().to_lower() == normalized_name:
				return equipped_module
	return null

func _resolve_module_owner_weapon(module_instance: Module) -> Weapon:
	if module_instance == null or not is_instance_valid(module_instance):
		return null
	var current: Node = module_instance
	while current:
		if current is Weapon:
			return current as Weapon
		current = current.get_parent()
	return null

func _calculate_module_conversion_coins(module_instance: Module) -> int:
	var base_cost: int = int(max(MODULE_DUPLICATE_BASE_CONVERT_COINS, int(module_instance.cost) * 6))
	return int(base_cost * max(1, module_instance.module_level))

func _discard_module_instance(module_instance: Module, keep_instance: Module = null) -> void:
	if module_instance == null or module_instance == keep_instance or not is_instance_valid(module_instance):
		return
	if module_instance.get_parent() != null:
		module_instance.queue_free()
	else:
		module_instance.free()

func remove_fuse_item(item) -> void:
	if ready_to_fuse_list.has(item):
		ready_to_fuse_list.erase(item)
		_safe_update_gf()

var on_drag_item :
	get:
		return on_drag_item
	set(value):
		if on_drag_item == value:
			# Cancel selection
			_safe_set_drag_icon(null)
			on_drag_item = null
			return
		# Select item
		if value == null:
			_safe_set_drag_icon(null)
		else:
			_safe_set_drag_icon(value.get_node("Sprite").texture)
		on_drag_item = value

func clear_on_select() -> void:
	on_select_upg = null
	on_select_module = null
	on_select_module_weapon = null
	on_select_inventory_module = null
	on_select_eqp = null
	on_select_slot = null
	on_drag_item = null


func reset_runtime_state() -> void:
	inventory_slots.clear()
	moddule_slots.clear()
	ready_to_sell_list.clear()
	ready_to_fuse_list.clear()
	clear_on_select()
