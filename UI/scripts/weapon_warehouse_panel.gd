extends PanelContainer
class_name WeaponWarehousePanel

var _equipped_list: VBoxContainer
var _stored_list: VBoxContainer

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 160.0
	offset_top = 48.0
	offset_right = -160.0
	offset_bottom = -48.0
	_build_layout()
	if not InventoryData.weapon_storage_changed.is_connected(_refresh):
		InventoryData.weapon_storage_changed.connect(_refresh)
	if not PlayerData.weapon_list_changed.is_connected(_refresh):
		PlayerData.weapon_list_changed.connect(_refresh)

func open_panel() -> void:
	_refresh()
	visible = true

func close_panel() -> void:
	visible = false

func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := Label.new()
	title.text = LocalizationManager.tr_key("ui.weapon.warehouse.title", "Weapon Warehouse")
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var hint := Label.new()
	hint.text = LocalizationManager.tr_key(
		"ui.weapon.warehouse.hint",
		"Store equipped weapons or exchange stored weapons with equipped slots. Stored weapons cannot keep modules."
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	root.add_child(columns)
	_equipped_list = _make_column(columns)
	_stored_list = _make_column(columns)
	var close_button := Button.new()
	close_button.text = LocalizationManager.tr_key("ui.panel.back", "Back")
	close_button.custom_minimum_size = Vector2(0, 50)
	close_button.pressed.connect(_on_close_pressed)
	root.add_child(close_button)

func _make_column(parent: HBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list

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
		var empty := Label.new()
		empty.text = LocalizationManager.tr_key("ui.weapon.warehouse.empty", "Warehouse is empty.")
		_stored_list.add_child(empty)
	for weapon in stored:
		_add_stored_row(weapon)

func _add_header(parent: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(label)

func _add_equipped_row(weapon: Weapon) -> void:
	var row := _make_weapon_row(_equipped_list, weapon)
	var store_button := Button.new()
	store_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.store", "Store in Warehouse")
	store_button.disabled = PlayerData.player_weapon_list.size() <= 1
	store_button.pressed.connect(_on_store_equipped.bind(weapon))
	row.add_child(store_button)

func _add_stored_row(weapon: Weapon) -> void:
	var row := _make_weapon_row(_stored_list, weapon)
	if PlayerData.player_weapon_list.size() < PlayerData.max_weapon_num:
		var equip_button := Button.new()
		equip_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.equip", "Equip")
		equip_button.pressed.connect(_on_equip_stored.bind(weapon))
		row.add_child(equip_button)
		return
	for equipped_ref in PlayerData.player_weapon_list:
		var equipped := equipped_ref as Weapon
		if equipped == null:
			continue
		var swap_button := Button.new()
		swap_button.text = LocalizationManager.tr_format(
			"ui.weapon.warehouse.swap",
			{"name": LocalizationManager.get_weapon_name_from_node(equipped)},
			"Swap with %s" % LocalizationManager.get_weapon_name_from_node(equipped)
		)
		swap_button.pressed.connect(_on_exchange.bind(weapon, equipped))
		row.add_child(swap_button)

func _make_weapon_row(parent: VBoxContainer, weapon: Weapon) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	var label := Label.new()
	label.text = LocalizationManager.tr_format(
		"ui.weapon.warehouse.row",
		{
			"name": LocalizationManager.get_weapon_name_from_node(weapon),
			"level": int(weapon.level),
			"fuse": int(weapon.fuse),
		},
		"%s  Lv.%d  Fuse %d" % [
			LocalizationManager.get_weapon_name_from_node(weapon),
			int(weapon.level),
			int(weapon.fuse),
		]
	)
	row.add_child(label)
	return row

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
