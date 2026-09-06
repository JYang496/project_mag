extends PanelContainer

const WEAPON_ROW_SCENE := preload("res://UI/components/WarehouseWeaponRow/WarehouseWeaponRow.tscn")
const SECTION_HEADER_SCENE := preload("res://UI/components/SectionHeader/SectionHeader.tscn")
const EMPTY_STATE_SCENE := preload("res://UI/components/EmptyStateLabel/EmptyStateLabel.tscn")

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _equipped_list: VBoxContainer = %EquippedList
@onready var _stored_list: VBoxContainer = %StoredList
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_refresh_static_texts()
	if not InventoryData.weapon_storage_changed.is_connected(_refresh):
		InventoryData.weapon_storage_changed.connect(_refresh)
	if not PlayerData.weapon_list_changed.is_connected(_refresh):
		PlayerData.weapon_list_changed.connect(_refresh)

func open_panel() -> void:
	_refresh()
	visible = true

func close_panel() -> void:
	visible = false

func _refresh() -> void:
	if _equipped_list == null or _stored_list == null:
		return
	_clear(_equipped_list)
	_clear(_stored_list)
	_add_header(_equipped_list, LocalizationManager.tr_key("ui.weapon.warehouse.equipped", "Equipped Weapons"))
	_add_header(_stored_list, LocalizationManager.tr_key("ui.weapon.warehouse.stored", "Stored Weapons"))
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon:
			_add_equipped_row(weapon)
	var stored := InventoryData.get_stored_weapons()
	if stored.is_empty():
		var empty := EMPTY_STATE_SCENE.instantiate() as Label
		empty.call("set_data", LocalizationManager.tr_key("ui.weapon.warehouse.empty", "Warehouse is empty."))
		_stored_list.add_child(empty)
	for weapon in stored:
		_add_stored_row(weapon)

func _add_header(parent: VBoxContainer, text_value: String) -> void:
	var label := SECTION_HEADER_SCENE.instantiate() as Label
	label.call("set_data", text_value)
	parent.add_child(label)

func _add_equipped_row(weapon: Weapon) -> void:
	var row := _make_weapon_row(_equipped_list, weapon)
	row.call("add_action", LocalizationManager.tr_key("ui.weapon.warehouse.store", "Store in Warehouse"), _on_store_equipped.bind(weapon), PlayerData.player_weapon_list.size() <= 1)

func _add_stored_row(weapon: Weapon) -> void:
	var row := _make_weapon_row(_stored_list, weapon)
	if PlayerData.player_weapon_list.size() < PlayerData.max_weapon_num:
		row.call("add_action", LocalizationManager.tr_key("ui.weapon.warehouse.equip", "Equip"), _on_equip_stored.bind(weapon))
		return
	for equipped_ref in PlayerData.player_weapon_list:
		var equipped := equipped_ref as Weapon
		if equipped == null:
			continue
		var swap_text := LocalizationManager.tr_format(
			"ui.weapon.warehouse.swap",
			{"name": LocalizationManager.get_weapon_instance_display_name(equipped)},
			"Swap with %s" % LocalizationManager.get_weapon_instance_display_name(equipped)
		)
		row.call("add_action", swap_text, _on_exchange.bind(weapon, equipped))

func _make_weapon_row(parent: VBoxContainer, weapon: Weapon) -> Control:
	var row := WEAPON_ROW_SCENE.instantiate() as Control
	parent.add_child(row)
	var label_text := LocalizationManager.tr_format(
		"ui.weapon.warehouse.row",
		{
			"name": LocalizationManager.get_weapon_instance_display_name(weapon),
			"level": int(weapon.level),
			"fuse": int(weapon.fuse),
		},
		"%s  Lv.%d  Fuse %d" % [
			LocalizationManager.get_weapon_instance_display_name(weapon),
			int(weapon.level),
			int(weapon.fuse),
		]
	)
	row.call("set_data", label_text)
	return row

func _refresh_static_texts() -> void:
	_title.text = LocalizationManager.tr_key("ui.weapon.warehouse.title", "Weapon Warehouse")
	_hint.text = LocalizationManager.tr_key("ui.weapon.warehouse.hint", "Store equipped weapons or exchange stored weapons with equipped slots. Stored weapons cannot keep modules.")
	_close_button.text = LocalizationManager.tr_key("ui.panel.back", "Back")

func _on_store_equipped(weapon: Weapon) -> void:
	InventoryData.store_weapon(weapon)
	_refresh()

func _on_equip_stored(weapon: Weapon) -> void:
	InventoryData.equip_stored_weapon(weapon)
	_refresh()

func _on_exchange(stored_weapon: Weapon, equipped_weapon: Weapon) -> void:
	InventoryData.exchange_stored_weapon(stored_weapon, equipped_weapon)
	_refresh()

func _on_close_pressed() -> void:
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("warehouse_back_to_purchase"):
		ui.call("warehouse_back_to_purchase")
	else:
		close_panel()

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
