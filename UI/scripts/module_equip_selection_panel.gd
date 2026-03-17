extends PanelContainer
class_name ModuleEquipSelectionPanel

signal selection_completed(assigned: bool)

@export var incompatible_slot_color: Color = Color(0.25, 0.25, 0.25, 1.0)
@export var occupied_slot_color: Color = Color(0.45, 0.45, 0.45, 1.0)
@export var available_slot_color: Color = Color(0.18, 0.42, 0.18, 1.0)

@onready var title_label: Label = $Margin/Root/TitleLabel
@onready var module_label: Label = $Margin/Root/ModuleLabel
@onready var equipped_list: VBoxContainer = $Margin/Root/Columns/EquippedPanel/EquippedList
@onready var inventory_list: VBoxContainer = $Margin/Root/Columns/InventoryPanel/InventoryList
@onready var cancel_button: Button = $Margin/Root/Footer/CancelButton

var _module_instance: Module
var _on_complete: Callable = Callable()

func _ready() -> void:
	visible = false
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)

func open_for_module(module_instance: Module, on_complete: Callable = Callable()) -> bool:
	if module_instance == null:
		return false
	_module_instance = module_instance
	_on_complete = on_complete
	title_label.text = "Equip Module"
	module_label.text = "%s Lv.%d - Select a weapon slot." % [
		_module_instance.get_module_display_name(),
		_module_instance.module_level
	]
	_rebuild_lists()
	visible = true
	return true

func _rebuild_lists() -> void:
	_clear_list(equipped_list)
	_clear_list(inventory_list)
	_build_weapon_section(equipped_list, _collect_equipped_weapons(), "Equipped Weapons")
	_build_weapon_section(inventory_list, _collect_inventory_weapons(), "Inventory Weapons")

func _collect_equipped_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon: Weapon = weapon_ref as Weapon
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func _collect_inventory_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for weapon_ref in InventoryData.inventory_slots:
		var weapon: Weapon = weapon_ref as Weapon
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func _build_weapon_section(parent: VBoxContainer, weapons: Array[Weapon], section_name: String) -> void:
	var section_header: Label = Label.new()
	section_header.text = section_name
	parent.add_child(section_header)
	if weapons.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "(none)"
		parent.add_child(empty_label)
		return
	for weapon in weapons:
		_build_weapon_row(parent, weapon)

func _build_weapon_row(parent: VBoxContainer, weapon: Weapon) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)

	var weapon_name_label: Label = Label.new()
	var item_name: Variant = weapon.get("ITEM_NAME")
	weapon_name_label.text = str(item_name) if item_name != null else weapon.name
	weapon_name_label.custom_minimum_size = Vector2(160, 0)
	row.add_child(weapon_name_label)

	var slots: HBoxContainer = HBoxContainer.new()
	row.add_child(slots)

	var max_slots: int = int(weapon.MAX_MODULE_NUMBER)
	var occupied_count: int = 0
	if weapon.modules:
		occupied_count = weapon.modules.get_child_count()
	var compatible: bool = _module_instance.can_apply_to_weapon(weapon)

	for index in range(max_slots):
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(52, 28)
		var is_occupied: bool = index < occupied_count
		if is_occupied:
			slot_button.text = "Used"
			slot_button.disabled = true
			slot_button.modulate = occupied_slot_color
		elif not compatible:
			slot_button.text = "N/A"
			slot_button.disabled = true
			slot_button.modulate = incompatible_slot_color
		else:
			slot_button.text = "Slot %d" % (index + 1)
			slot_button.disabled = false
			slot_button.modulate = available_slot_color
			slot_button.pressed.connect(_on_slot_selected.bind(weapon))
		slots.add_child(slot_button)

func _on_slot_selected(weapon: Weapon) -> void:
	if weapon == null or not is_instance_valid(weapon) or _module_instance == null:
		_complete(false)
		return
	if weapon.modules == null:
		_complete(false)
		return
	if _module_instance.get_parent() != null:
		_module_instance.reparent(weapon.modules)
	else:
		weapon.modules.add_child(_module_instance)
	InventoryData.moddule_slots.erase(_module_instance)
	if weapon.has_method("calculate_status"):
		weapon.calculate_status()
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui):
		ui.update_modules()
		ui.update_inventory()
		ui.refresh_border()
		if ui.has_method("show_item_message"):
			ui.show_item_message(
				"Equipped %s Lv.%d to %s" % [
					_module_instance.get_module_display_name(),
					_module_instance.module_level,
					str(weapon.get("ITEM_NAME")) if weapon.get("ITEM_NAME") != null else weapon.name
				],
				2.0
			)
	_complete(true)

func _on_cancel_pressed() -> void:
	_complete(false)

func _complete(assigned: bool) -> void:
	visible = false
	emit_signal("selection_completed", assigned)
	if _on_complete.is_valid():
		_on_complete.call_deferred(assigned)
	_on_complete = Callable()

func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
