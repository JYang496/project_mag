extends PanelContainer
class_name WeaponReplacementPanel

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const WEAPON_DISPLAY_POLICY := preload("res://UI/scripts/presentation/weapon_display_policy.gd")
const WEAPON_STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")

const PANEL_BG := Color(0.055, 0.065, 0.072, 0.96)
const PANEL_LINE := Color(0.42, 0.5, 0.54, 0.55)
const ACTION_COLOR := Color(0.66, 0.82, 0.88, 1.0)
const EMPTY_SLOT_COLOR := Color(0.32, 0.39, 0.43, 0.85)
const POSITIVE_COLOR := Color(0.38, 0.88, 0.68, 1.0)
const NEGATIVE_COLOR := Color(1.0, 0.55, 0.38, 1.0)
const NEUTRAL_COLOR := Color(0.66, 0.74, 0.78, 1.0)

@onready var title_label: Label = $Margin/Root/Title
@onready var description_label: Label = $Margin/Root/Description
@onready var incoming_host: VBoxContainer = $Margin/Root/IncomingHost
@onready var slots_scroll: ScrollContainer = $Margin/Root/SlotsScroll
@onready var slots: VBoxContainer = $Margin/Root/SlotsScroll/SlotsPadding/Slots
@onready var footer: HBoxContainer = $Margin/Root/Footer
@onready var cancel_button: Button = $Margin/Root/Footer/Cancel

var _new_weapon: Weapon
var _allow_cancel := true
var _on_complete := Callable()
var _store_button: Button
var _confirm_button: Button
var _selected_slot_index := -1
var _selected_old_weapon: Weapon
var _slot_buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, PANEL_LINE, 2))
	slots.add_theme_constant_override("separation", 8)
	var scroll_bar := slots_scroll.get_v_scroll_bar()
	scroll_bar.custom_minimum_size.x = 14
	cancel_button.pressed.connect(_on_cancel_pressed)
	_store_button = Button.new()
	_store_button.name = "Store"
	_store_button.custom_minimum_size = Vector2(220, 44)
	_store_button.pressed.connect(_on_store_selected)
	footer.add_child(_store_button)
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmReplacement"
	_confirm_button.custom_minimum_size = Vector2(240, 44)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_selected)
	footer.add_child(_confirm_button)
	footer.move_child(_store_button, 0)
	_apply_button_style(cancel_button, PANEL_LINE)
	_apply_button_style(_store_button, PANEL_LINE)
	_apply_button_style(_confirm_button, ACTION_COLOR)

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
	title_label.text = LocalizationManager.tr_key("ui.weapon.replace.install_title", "Install Weapon")
	description_label.text = LocalizationManager.tr_key(
		"ui.weapon.replace.consequence_hint",
		"Choose a slot. The old weapon goes to storage and its modules are safely removed."
	)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	cancel_button.visible = _allow_cancel
	_store_button.text = LocalizationManager.tr_key("ui.weapon.warehouse.store", "Store in Warehouse")
	_selected_slot_index = -1
	_selected_old_weapon = null
	_confirm_button.text = LocalizationManager.tr_key("ui.weapon.replace.confirm_prompt", "Select a slot first")
	_confirm_button.disabled = true
	_rebuild_slots()
	visible = true
	_focus_first_slot.call_deferred()
	return true

func _rebuild_slots() -> void:
	_slot_buttons.clear()
	for child in incoming_host.get_children():
		incoming_host.remove_child(child)
		child.queue_free()
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	incoming_host.add_child(_make_incoming_weapon_card(_new_weapon))
	for index in range(PlayerData.max_weapon_num):
		if index < PlayerData.player_weapon_list.size():
			var old_weapon := PlayerData.player_weapon_list[index] as Weapon
			var button := _make_slot_button(
				index,
				old_weapon,
				LocalizationManager.tr_key("ui.weapon.replace.action_replace", "Replace"),
				false
			)
			button.pressed.connect(_on_slot_selected.bind(index, old_weapon))
			slots.add_child(button)
			_slot_buttons.append(button)
		else:
			var button := _make_slot_button(
				index,
				null,
				LocalizationManager.tr_key("ui.weapon.replace.action_equip", "Equip"),
				true
			)
			button.pressed.connect(_on_slot_selected.bind(index, null))
			slots.add_child(button)
			_slot_buttons.append(button)

func _make_incoming_weapon_card(weapon: Weapon) -> PanelContainer:
	var display_model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 96)
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

	var name_label := _make_slot_label(display_model.display_name, 18, Color(0.96, 0.99, 1.0, 1.0))
	text_column.add_child(name_label)

	var meta_label := _make_slot_label(_format_weapon_meta(weapon), 14, Color(0.76, 0.84, 0.88, 1.0))
	text_column.add_child(meta_label)
	var stats_label := _make_slot_label(
		WEAPON_STAT_FORMATTER.format_summary(
			display_model.current_stats,
			WEAPON_DISPLAY_POLICY.summary_limit(WEAPON_DISPLAY_POLICY.REPLACEMENT_COMPARE)
		),
		12,
		Color(0.72, 0.88, 0.92, 1.0)
	)
	text_column.add_child(stats_label)
	return card

func _make_slot_button(slot_index: int, weapon: Weapon, action_text: String, is_empty: bool) -> Button:
	var button := Button.new()
	button.name = "WeaponSlot%d" % (slot_index + 1)
	button.set_meta("slot_index", slot_index)
	var module_count := weapon.modules.get_child_count() if not is_empty and weapon.modules != null else 0
	button.custom_minimum_size = Vector2(520, 120 if module_count > 0 else (96 if not is_empty else 72))
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	_apply_button_style(button, EMPTY_SLOT_COLOR if is_empty else _get_weapon_color(weapon))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	button.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)

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

	var current_text := LocalizationManager.tr_key("ui.inventory.slot.empty", "Empty") if is_empty else LocalizationManager.get_weapon_instance_display_name(weapon)
	var current_label := _make_slot_label(current_text, 16, Color(0.93, 0.96, 0.96, 1.0))
	text_column.add_child(current_label)

	var meta_label := _make_slot_label(LocalizationManager.tr_key("ui.weapon.replace.empty_slot_hint", "Open slot") if is_empty else _format_weapon_meta(weapon), 14, Color(0.72, 0.80, 0.84, 1.0))
	text_column.add_child(meta_label)

	var action_label := _make_slot_label(
		LocalizationManager.tr_key("ui.weapon.replace.action_select", "Select") if not is_empty else action_text,
		15,
		ACTION_COLOR
	)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action_label.custom_minimum_size = Vector2(92, 0)
	row.add_child(action_label)
	button.set_meta("action_label", action_label)

	if not is_empty:
		var comparison := _make_replacement_comparison(_new_weapon, weapon)
		comparison.add_theme_constant_override("h_separation", 8)
		comparison.add_theme_constant_override("v_separation", 5)
		content.add_child(comparison)
		if module_count > 0:
			var warning_label := _make_slot_label(
				LocalizationManager.tr_format(
					"ui.weapon.replace.modules_safely_removed",
					{"count": module_count},
					"%d installed modules will be safely removed." % module_count
				),
				12,
				Color(1.0, 0.72, 0.42, 1.0)
			)
			content.add_child(warning_label)
	return button

func _make_replacement_comparison(incoming_weapon: Weapon, current_weapon: Weapon) -> HFlowContainer:
	var comparison_row := HFlowContainer.new()
	comparison_row.mouse_filter = Control.MOUSE_FILTER_PASS
	comparison_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if incoming_weapon == null or current_weapon == null:
		return comparison_row
	var incoming_model = WEAPON_DISPLAY_BUILDER.build_from_instance(incoming_weapon)
	var current_model = WEAPON_DISPLAY_BUILDER.build_from_instance(current_weapon)
	var comparison := WEAPON_STAT_FORMATTER.build_deltas(current_model.current_stats, incoming_model.current_stats)
	var full_comparison := PackedStringArray()
	var visible_count := 0
	for delta_data in comparison:
		if not bool(delta_data.get("changed", false)):
			continue
		full_comparison.append(WEAPON_STAT_FORMATTER.format_delta_line(delta_data))
		if visible_count >= WEAPON_DISPLAY_POLICY.summary_limit(WEAPON_DISPLAY_POLICY.REPLACEMENT_COMPARE):
			continue
		comparison_row.add_child(_make_delta_chip(delta_data))
		visible_count += 1
	comparison_row.tooltip_text = "\n".join(full_comparison)
	return comparison_row

func _make_delta_chip(delta_data: Dictionary) -> PanelContainer:
	var benefit := StringName(str(delta_data.get("benefit", "neutral")))
	var color := NEUTRAL_COLOR
	var marker := "•"
	if benefit == &"positive":
		color = POSITIVE_COLOR
		marker = "▲"
	elif benefit == &"negative":
		color = NEGATIVE_COLOR
		marker = "▼"
	var key: Variant = delta_data.get("key", &"")
	var delta_value: Variant = delta_data.get("delta", null)
	var value_text := ""
	if delta_value == null:
		value_text = LocalizationManager.tr_key("ui.weapon.replace.mechanic_changed", "Mechanic changed")
	else:
		value_text = WEAPON_STAT_FORMATTER.format_value(key, absf(float(delta_value)))
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size.x = 112
	var chip_style := _make_panel_style(Color(color.r, color.g, color.b, 0.08), Color(color.r, color.g, color.b, 0.42), 1)
	chip_style.content_margin_left = 6.0
	chip_style.content_margin_top = 2.0
	chip_style.content_margin_right = 6.0
	chip_style.content_margin_bottom = 2.0
	chip.add_theme_stylebox_override("panel", chip_style)
	var label := _make_slot_label(
		"%s %s %s" % [WEAPON_STAT_FORMATTER.format_label(key), marker, value_text],
		11,
		color
	)
	label.clip_text = false
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 0.9))
	chip.add_child(label)
	return chip

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
	var display_model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
	return LocalizationManager.tr_format(
		"ui.weapon.meta.level_fuse_mods",
		{
			"level": display_model.level,
			"max": display_model.max_level,
			"fuse": display_model.fuse,
			"modules": display_model.module_count,
			"module_max": display_model.module_capacity,
		},
		"Lv.%d/%d  Fuse %d  Mods %d/%d" % [
			display_model.level,
			display_model.max_level,
			display_model.fuse,
			display_model.module_count,
			display_model.module_capacity,
		]
	)


func _focus_first_slot() -> void:
	for child in slots.get_children():
		if child is Button and child.visible and not child.disabled:
			(child as Button).grab_focus()
			return

func _on_slot_selected(slot_index: int, old_weapon: Weapon) -> void:
	_selected_slot_index = slot_index
	_selected_old_weapon = old_weapon
	for button in _slot_buttons:
		var selected := int(button.get_meta("slot_index", -1)) == slot_index
		_apply_button_style(button, ACTION_COLOR if selected else _slot_accent_for_button(button))
		var action_label := button.get_meta("action_label", null) as Label
		if action_label != null:
			action_label.text = LocalizationManager.tr_key("ui.reward.selected", "Selected") if selected else (
				LocalizationManager.tr_key("ui.weapon.replace.action_equip", "Equip")
				if int(button.get_meta("slot_index", -1)) >= PlayerData.player_weapon_list.size()
				else LocalizationManager.tr_key("ui.weapon.replace.action_select", "Select")
			)
	if old_weapon == null:
		_confirm_button.text = LocalizationManager.tr_format(
			"ui.weapon.replace.confirm_equip_slot",
			{"slot": slot_index + 1},
			"Equip to Slot %d" % (slot_index + 1)
		)
	else:
		_confirm_button.text = LocalizationManager.tr_format(
			"ui.weapon.replace.confirm_replace_slot",
			{"slot": slot_index + 1},
			"Replace Slot %d" % (slot_index + 1)
		)
	_confirm_button.disabled = false
	_confirm_button.grab_focus()

func _slot_accent_for_button(button: Button) -> Color:
	var slot_index := int(button.get_meta("slot_index", -1))
	if slot_index < 0 or slot_index >= PlayerData.player_weapon_list.size():
		return EMPTY_SLOT_COLOR
	return _get_weapon_color(PlayerData.player_weapon_list[slot_index] as Weapon)

func _on_confirm_selected() -> void:
	if _selected_slot_index < 0:
		return
	if _selected_old_weapon == null:
		_on_empty_slot_selected()
	else:
		_on_replace_selected(_selected_old_weapon)

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
	PhaseManager.request_settlement_completion_check()
