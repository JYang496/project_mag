extends PanelContainer
class_name WeaponReplacementPanel

@onready var title_label: Label = $Margin/Root/Title
@onready var description_label: Label = $Margin/Root/Description
@onready var slots: VBoxContainer = $Margin/Root/Slots
@onready var cancel_button: Button = $Margin/Root/Cancel

var _new_weapon: Weapon
var _allow_cancel := true
var _on_complete := Callable()
var _store_button: Button

func _ready() -> void:
	visible = false
	cancel_button.pressed.connect(_on_cancel_pressed)
	_store_button = Button.new()
	_store_button.name = "Store"
	_store_button.custom_minimum_size = Vector2(0, 52)
	_store_button.pressed.connect(_on_store_selected)
	cancel_button.add_sibling(_store_button)

func _input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	if not ModalUiController.is_cancel_input(event):
		return
	cancel_visible_modal()
	get_viewport().set_input_as_handled()

func open_for_weapon(
	new_weapon: Weapon,
	allow_cancel: bool = true,
	on_complete: Callable = Callable()
) -> bool:
	if new_weapon == null or not is_instance_valid(new_weapon):
		return false
	_new_weapon = new_weapon
	_allow_cancel = allow_cancel
	_on_complete = on_complete
	InventoryData.begin_pending_transaction({
		"id": "weapon_replacement",
		"type": "weapon_replacement",
		"weapon": DataHandler.build_weapon_save_payload(new_weapon),
		"allow_cancel": allow_cancel,
	})
	title_label.text = LocalizationManager.tr_key("ui.weapon.replace.title", "Choose Weapon Slot")
	description_label.text = LocalizationManager.tr_format(
		"ui.weapon.replace.description",
		{"weapon": LocalizationManager.get_weapon_name_from_node(new_weapon)},
		"Equip %s, exchange an equipped weapon, or store it." % LocalizationManager.get_weapon_name_from_node(new_weapon)
	)
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	cancel_button.visible = _allow_cancel
	_store_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.store", "Store in Warehouse")
	_rebuild_slots()
	visible = true
	return true

func _rebuild_slots() -> void:
	for child in slots.get_children():
		child.queue_free()
	for index in range(PlayerData.max_weapon_num):
		var button := Button.new()
		button.custom_minimum_size = Vector2(520, 52)
		if index < PlayerData.player_weapon_list.size():
			var old_weapon := PlayerData.player_weapon_list[index] as Weapon
			button.text = LocalizationManager.tr_format(
				"ui.weapon.replace.slot",
				{
					"slot": index + 1,
					"old": LocalizationManager.get_weapon_name_from_node(old_weapon),
					"new": LocalizationManager.get_weapon_name_from_node(_new_weapon),
				},
				"Slot %d: %s -> %s" % [
					index + 1,
					LocalizationManager.get_weapon_name_from_node(old_weapon),
					LocalizationManager.get_weapon_name_from_node(_new_weapon),
				]
			)
			button.pressed.connect(_on_replace_selected.bind(old_weapon))
		else:
			button.text = LocalizationManager.tr_format(
				"ui.weapon.replace.empty_slot",
				{"slot": index + 1},
				"Slot %d: Empty" % [index + 1]
			)
			button.pressed.connect(_on_empty_slot_selected)
		slots.add_child(button)

func _on_empty_slot_selected() -> void:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return
	var weapon := _new_weapon
	_new_weapon = null
	var result := InventoryData.equip_incoming_weapon_to_slot(weapon)
	_complete(bool(result.get("ok", false)), result)

func _on_replace_selected(old_weapon: Weapon) -> void:
	var result := InventoryData.equip_incoming_weapon_to_slot(_new_weapon, old_weapon)
	if not result.get("ok", false):
		return
	_new_weapon = null
	_complete(true, result)

func _on_store_selected() -> void:
	var result := InventoryData.store_weapon(_new_weapon)
	if not result.get("ok", false):
		return
	_new_weapon = null
	_complete(true, result)

func _on_cancel_pressed() -> void:
	if not _allow_cancel:
		return
	var result := {"result": "cancelled"}
	if _new_weapon and is_instance_valid(_new_weapon):
		_new_weapon.queue_free()
	_new_weapon = null
	_complete(false, result)

func is_modal_open() -> bool:
	return visible

func can_cancel_modal() -> bool:
	return _allow_cancel

func cancel_visible_modal() -> bool:
	if not is_modal_open() or not can_cancel_modal():
		return false
	_on_cancel_pressed()
	return true

func _complete(accepted: bool, result: Dictionary) -> void:
	visible = false
	InventoryData.finish_pending_transaction("weapon_replacement")
	if _on_complete.is_valid():
		_on_complete.call_deferred(accepted, result)
	_on_complete = Callable()
