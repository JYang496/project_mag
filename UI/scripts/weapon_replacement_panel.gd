extends PanelContainer
class_name WeaponReplacementPanel

const RARITY_UTIL := preload("res://data/LootRarity.gd")

const PANEL_BG := Color(0.055, 0.065, 0.072, 0.96)
const PANEL_LINE := Color(0.42, 0.5, 0.54, 0.55)
const ACTION_COLOR := Color(0.66, 0.82, 0.88, 1.0)
const EMPTY_SLOT_COLOR := Color(0.32, 0.39, 0.43, 0.85)

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
	add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, PANEL_LINE, 2))
	slots.add_theme_constant_override("separation", 8)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_store_button = Button.new()
	_store_button.name = "Store"
	_store_button.custom_minimum_size = Vector2(0, 52)
	_store_button.pressed.connect(_on_store_selected)
	cancel_button.add_sibling(_store_button)
	_apply_button_style(cancel_button, PANEL_LINE)
	_apply_button_style(_store_button, ACTION_COLOR)

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
	var weapon_name := LocalizationManager.get_weapon_name_from_node(new_weapon)
	title_label.text = LocalizationManager.tr_key("ui.weapon.replace.install_title", "Install Weapon")
	description_label.text = LocalizationManager.tr_format(
		"ui.weapon.replace.incoming",
		{"weapon": weapon_name},
		weapon_name
	)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	cancel_button.visible = _allow_cancel
	_store_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.store", "Store in Warehouse")
	_rebuild_slots()
	visible = true
	return true

func _rebuild_slots() -> void:
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	slots.add_child(_make_incoming_weapon_card(_new_weapon))
	for index in range(PlayerData.max_weapon_num):
		if index < PlayerData.player_weapon_list.size():
			var old_weapon := PlayerData.player_weapon_list[index] as Weapon
			var button := _make_slot_button(
				index,
				old_weapon,
				LocalizationManager.tr_key("ui.weapon.replace.action_replace", "Replace"),
				false
			)
			button.pressed.connect(_on_replace_selected.bind(old_weapon))
			slots.add_child(button)
		else:
			var button := _make_slot_button(
				index,
				null,
				LocalizationManager.tr_key("ui.weapon.replace.action_equip", "Equip"),
				true
			)
			button.pressed.connect(_on_empty_slot_selected)
			slots.add_child(button)

func _make_incoming_weapon_card(weapon: Weapon) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 78)
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.07, 0.085, 0.095, 0.98), _get_weapon_color(weapon), 2))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	row.add_child(_make_weapon_icon(weapon, Vector2(54, 54)))

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 2)
	row.add_child(text_column)

	var name_label := _make_slot_label(LocalizationManager.get_weapon_name_from_node(weapon), 18, Color(0.96, 0.99, 1.0, 1.0))
	text_column.add_child(name_label)

	var meta_label := _make_slot_label(_format_weapon_meta(weapon), 12, Color(0.68, 0.77, 0.82, 1.0))
	text_column.add_child(meta_label)
	return card

func _make_slot_button(slot_index: int, weapon: Weapon, action_text: String, is_empty: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(520, 66)
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	_apply_button_style(button, EMPTY_SLOT_COLOR if is_empty else _get_weapon_color(weapon))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var slot_label := _make_slot_label(
		LocalizationManager.tr_format("ui.weapon.replace.slot_label", {"slot": slot_index + 1}, "Slot %d" % [slot_index + 1]),
		13,
		Color(0.68, 0.77, 0.82, 1.0)
	)
	slot_label.custom_minimum_size = Vector2(94, 0)
	row.add_child(slot_label)
	row.add_child(_make_weapon_icon(weapon, Vector2(42, 42), is_empty))

	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 1)
	row.add_child(text_column)

	var current_text := LocalizationManager.tr_key("ui.inventory.slot.empty", "Empty") if is_empty else LocalizationManager.get_weapon_name_from_node(weapon)
	var current_label := _make_slot_label(current_text, 15, Color(0.93, 0.96, 0.96, 1.0))
	text_column.add_child(current_label)

	var meta_label := _make_slot_label(LocalizationManager.tr_key("ui.weapon.replace.empty_slot_hint", "Open slot") if is_empty else _format_weapon_meta(weapon), 12, Color(0.58, 0.67, 0.72, 1.0))
	text_column.add_child(meta_label)

	var action_label := _make_slot_label(action_text, 13, ACTION_COLOR)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_label.custom_minimum_size = Vector2(76, 0)
	row.add_child(action_label)
	return button

func _make_weapon_icon(weapon: Weapon, min_size: Vector2, is_empty: bool = false) -> Control:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = min_size
	frame.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.03, 0.035, 0.9), EMPTY_SLOT_COLOR if is_empty else _get_weapon_color(weapon), 1))
	if is_empty:
		var label := _make_slot_label("+", 20, EMPTY_SLOT_COLOR)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frame.add_child(label)
		return frame
	var texture := TextureRect.new()
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.texture = _get_weapon_icon(weapon)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(texture)
	return frame

func _make_slot_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label

func _apply_button_style(button: Button, accent: Color) -> void:
	if button == null:
		return
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := PANEL_BG
		if state == "hover" or state == "focus":
			bg = Color(0.08, 0.095, 0.105, 0.98)
		elif state == "pressed":
			bg = Color(0.095, 0.115, 0.13, 0.98)
		elif state == "disabled":
			bg = Color(0.045, 0.05, 0.055, 0.75)
		var border := accent
		border.a = 0.5 if state != "focus" else 0.9
		button.add_theme_stylebox_override(state, _make_panel_style(bg, border, 1))

func _make_panel_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style

func _get_weapon_definition(weapon: Weapon) -> WeaponDefinition:
	if weapon == null or not is_instance_valid(weapon):
		return null
	var weapon_id := DataHandler.get_weapon_id_from_instance(weapon)
	return DataHandler.read_weapon_data(weapon_id) as WeaponDefinition

func _get_weapon_icon(weapon: Weapon) -> Texture2D:
	var weapon_def := _get_weapon_definition(weapon)
	return weapon_def.icon if weapon_def != null else null

func _get_weapon_color(weapon: Weapon) -> Color:
	var weapon_def := _get_weapon_definition(weapon)
	if weapon_def == null:
		return ACTION_COLOR
	return RARITY_UTIL.get_color(weapon_def.get_rarity())

func _format_weapon_meta(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return ""
	var module_count := 0
	if weapon.modules != null:
		module_count = weapon.modules.get_child_count()
	return LocalizationManager.tr_format(
		"ui.weapon.meta.level_fuse_mods",
		{
			"level": int(weapon.level),
			"max": int(weapon.max_level),
			"fuse": int(weapon.fuse),
			"modules": module_count,
			"module_max": int(weapon.MAX_MODULE_NUMBER),
		},
		"Lv.%d/%d  Fuse %d  Mods %d/%d" % [
			int(weapon.level),
			int(weapon.max_level),
			int(weapon.fuse),
			module_count,
			int(weapon.MAX_MODULE_NUMBER),
		]
	)

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
