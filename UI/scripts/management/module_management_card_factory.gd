extends RefCounted
class_name ModuleManagementCardFactory

const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const WAREHOUSE_DRAG_CONTROLS := preload("res://UI/scripts/management/warehouse_drag_controls.gd")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")

var view: Node
var owner_ui: Node

func bind(module_view: Node, ui: Node) -> void:
	view = module_view
	owner_ui = ui

func make_weapon_button(weapon: Weapon, location: String, selected: bool, pressed_callback: Callable) -> Button:
	var button := WAREHOUSE_DRAG_CONTROLS.WarehouseDragDropButton.new()
	button.view = view
	if location == "stored":
		button.drag_payload = {"kind": "stored_weapon", "weapon": weapon}
	else:
		button.drag_payload = {"kind": "equipped_weapon", "weapon": weapon}
		button.drop_payload = {"kind": "equipped_weapon", "weapon": weapon}
	button.custom_minimum_size = Vector2(0, 86)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(pressed_callback)
	_populate_weapon_button(button, weapon, selected)
	_style_button(button, selected)
	return button

func make_empty_weapon_slot_button(slot_index: int) -> Button:
	var button := WAREHOUSE_DRAG_CONTROLS.WarehouseDragDropButton.new()
	button.view = view
	button.drop_payload = {"kind": "held_empty_slot", "slot_index": slot_index}
	button.custom_minimum_size = Vector2(0, 70)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = LocalizationManager.tr_format("ui.weapon.warehouse.empty_slot", {"index": slot_index + 1}, "Empty weapon slot %d" % (slot_index + 1))
	button.tooltip_text = LocalizationManager.tr_key("ui.weapon.warehouse.drop_to_equip", "Drop a stored weapon here to equip it.")
	_style_button(button, false)
	return button

func make_module_button(module_instance: Module, selected: bool, pressed_callback: Callable) -> Button:
	var button := WAREHOUSE_DRAG_CONTROLS.WarehouseDragDropButton.new()
	button.view = view
	button.drag_payload = {"kind": "temporary_module", "module": module_instance}
	button.custom_minimum_size = Vector2(0, 112)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(pressed_callback)
	button.text = ""
	var margin := _make_full_margin(10, 7, 10, 7)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var icon := _make_icon(Vector2(58, 58))
	icon.texture = _get_module_texture(module_instance)
	row.add_child(icon)
	var text_box := _make_text_box()
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = LocalizationManager.get_module_name(module_instance)
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", RARITY_UTIL.get_color(module_instance.get_rarity()))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(name_label)
	var level := Label.new()
	level.text = _format_module_meta(module_instance)
	level.add_theme_font_size_override("font_size", 12)
	level.add_theme_color_override("font_color", Color(0.74, 0.84, 0.9))
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(level)
	var targets := Label.new()
	targets.name = "InstallTargets"
	targets.text = "%s: %s" % [
		LocalizationManager.tr_key("ui.module.install_targets", "Install Targets"),
		_format_module_install_targets(module_instance),
	]
	targets.clip_text = true
	targets.add_theme_font_size_override("font_size", 11)
	targets.add_theme_color_override("font_color", Color(0.68, 0.78, 0.84))
	targets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(targets)
	var effect_chips := MODULE_FIT_FORMATTER.build_effect_chips(module_instance, 3)
	if not effect_chips.is_empty():
		var chip_row := BUILD_TAG_DISPLAY.make_chip_row(effect_chips, 3)
		text_box.add_child(chip_row)
	_style_button(button, selected)
	return button

func make_module_weapon_card(weapon: Weapon, active_drag_module: Module, socket_callback_builder: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ModuleWeaponCard"
	panel.custom_minimum_size = Vector2(0, 142)
	panel.set_meta("weapon", weapon)
	apply_module_weapon_card_style(panel, weapon, active_drag_module)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var weapon_icon_frame := PanelContainer.new()
	weapon_icon_frame.name = "WeaponIconFrame"
	weapon_icon_frame.custom_minimum_size = Vector2(52, 64)
	weapon_icon_frame.add_theme_stylebox_override("panel", _make_icon_frame_style(_get_weapon_rarity_color(weapon)))
	root.add_child(weapon_icon_frame)
	var weapon_icon := _make_icon(Vector2(46, 54))
	weapon_icon.name = "WeaponIcon"
	weapon_icon.texture = weapon.sprite.texture if weapon.sprite else null
	weapon_icon_frame.add_child(weapon_icon)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	root.add_child(content)
	var name_label := Label.new()
	name_label.name = "WeaponName"
	name_label.text = LocalizationManager.get_weapon_instance_display_name(weapon)
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", _get_weapon_rarity_color(weapon))
	content.add_child(name_label)
	var level_label := Label.new()
	level_label.name = "WeaponLevel"
	level_label.text = "Lv.%d" % int(weapon.level)
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(0.66, 0.78, 0.86))
	content.add_child(level_label)
	var slot_row := HBoxContainer.new()
	slot_row.name = "ModuleSlots"
	slot_row.add_theme_constant_override("separation", 4)
	content.add_child(slot_row)
	var installed: Array[Module] = []
	if weapon.modules:
		for child in weapon.modules.get_children():
			var module_instance := child as Module
			if module_instance:
				installed.append(module_instance)
	var max_slots := weapon.module_slot_capacity
	for index in range(max_slots):
		var existing: Module = installed[index] if index < installed.size() else null
		slot_row.add_child(make_module_socket_button(weapon, existing, index, socket_callback_builder.call(weapon, existing)))
	return panel

func make_module_socket_button(weapon: Weapon, existing: Module, index: int, pressed_callback: Callable) -> Button:
	var button := WAREHOUSE_DRAG_CONTROLS.WarehouseDragDropButton.new()
	button.view = view
	button.drop_payload = {"kind": "module_slot", "weapon": weapon, "existing": existing, "slot_index": index}
	if existing != null and is_instance_valid(existing):
		button.drag_payload = {"kind": "equipped_module", "module": existing, "weapon": weapon}
	button.custom_minimum_size = Vector2(48, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	var feedback := _get_slot_feedback(weapon, existing)
	button.disabled = false
	button.set_meta("slot_feedback_ok", bool(feedback.get("ok", true)))
	button.tooltip_text = str(feedback.get("reason", ""))
	button.pressed.connect(pressed_callback)
	var margin := _make_full_margin(3, 3, 3, 3)
	button.add_child(margin)
	var root := CenterContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)
	var visual := Control.new()
	visual.custom_minimum_size = Vector2(40, 54)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(visual)
	var icon := _make_icon(Vector2(36, 42))
	icon.name = "ModuleIcon"
	icon.position = Vector2(2, 2)
	icon.texture = _get_module_texture(existing) if existing else null
	visual.add_child(icon)
	if existing == null:
		var empty_mark := Label.new()
		empty_mark.name = "EmptyMark"
		empty_mark.text = "+"
		empty_mark.position = Vector2(6, -2)
		empty_mark.size = Vector2(28, 38)
		empty_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_mark.add_theme_font_size_override("font_size", 26)
		empty_mark.add_theme_color_override("font_color", Color(0.32, 0.70, 0.86, 0.78))
		empty_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(empty_mark)
	var badge := Label.new()
	badge.name = "SlotBadge"
	badge.text = "Lv.%d" % int(existing.module_level) if existing else str(index + 1)
	badge.position = Vector2(0, 39)
	badge.size = Vector2(40, 14)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", RARITY_UTIL.get_color(existing.get_rarity()) if existing else Color(0.58, 0.72, 0.8))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(badge)
	if button.tooltip_text.strip_edges() == "":
		button.tooltip_text = LocalizationManager.get_module_name(existing) if existing else LocalizationManager.tr_format("ui.module.slot_empty", {"index": index + 1}, "Slot %d" % (index + 1))
	_style_button(button, bool(feedback.get("ok", true)) and _get_selected_module() != null)
	return button

func _make_icon_frame_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.9)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 5
	style.content_margin_top = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
	return style

func apply_module_weapon_card_style(panel: PanelContainer, weapon: Weapon, active_drag_module: Module) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.1, 0.96)
	style.border_color = _get_weapon_rarity_color(weapon)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	if active_drag_module != null and is_instance_valid(active_drag_module):
		var compatible := _can_drag_module_install_on_weapon(active_drag_module, weapon)
		style.border_color = Color(1.0, 1.0, 1.0) if compatible else Color(1.0, 0.18, 0.14)
		style.set_border_width_all(3)
		style.bg_color = Color(0.1, 0.12, 0.13, 0.98) if compatible else Color(0.16, 0.065, 0.06, 0.98)
		panel.set_meta("drag_highlight", "compatible" if compatible else "blocked")
	else:
		panel.set_meta("drag_highlight", "")
	panel.add_theme_stylebox_override("panel", style)

func build_drag_preview(payload: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 62)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.145, 0.96)
	style.border_color = Color(0.3, 0.52, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var icon := _make_icon(Vector2(44, 44))
	row.add_child(icon)
	var text_box := _make_text_box()
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.clip_text = true
	text_box.add_child(name_label)
	var sub_label := Label.new()
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.9))
	text_box.add_child(sub_label)
	var payload_kind := str(payload.get("kind", ""))
	var module_instance := payload.get("module", null) as Module
	var weapon := payload.get("weapon", null) as Weapon
	if _is_module_drag_kind(payload_kind) and module_instance != null and is_instance_valid(module_instance):
		icon.texture = _get_module_texture(module_instance)
		name_label.text = LocalizationManager.get_module_name(module_instance)
		name_label.add_theme_color_override("font_color", RARITY_UTIL.get_color(module_instance.get_rarity()))
		sub_label.text = _format_module_meta(module_instance)
	elif weapon != null and is_instance_valid(weapon):
		icon.texture = weapon.sprite.texture if weapon.sprite else null
		name_label.text = LocalizationManager.get_weapon_instance_display_name(weapon)
		name_label.add_theme_color_override("font_color", _get_weapon_rarity_color(weapon))
		sub_label.text = _format_weapon_meta(weapon)
	elif module_instance != null and is_instance_valid(module_instance):
		icon.texture = _get_module_texture(module_instance)
		name_label.text = LocalizationManager.get_module_name(module_instance)
		name_label.add_theme_color_override("font_color", RARITY_UTIL.get_color(module_instance.get_rarity()))
		sub_label.text = _format_module_meta(module_instance)
	return panel

func _is_module_drag_kind(payload_kind: String) -> bool:
	return payload_kind == "temporary_module" or payload_kind == "equipped_module"

func _populate_weapon_button(button: Button, weapon: Weapon, selected: bool) -> void:
	var display_model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
	button.text = ""
	var margin := _make_full_margin(10, 7, 10, 7)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var icon := _make_icon(Vector2(58, 58))
	icon.texture = weapon.sprite.texture if weapon.sprite else null
	row.add_child(icon)
	var text_box := _make_text_box()
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = display_model.display_name
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", _get_weapon_rarity_color(weapon))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(name_label)
	var stats := Label.new()
	stats.text = _format_weapon_meta(weapon)
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(0.74, 0.84, 0.9))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(stats)
	if selected:
		var selected_label := Label.new()
		selected_label.text = LocalizationManager.tr_key("ui.common.selected", "Selected")
		selected_label.add_theme_font_size_override("font_size", 11)
		selected_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
		selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(selected_label)

func _make_full_margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin

func _make_icon(size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_text_box() -> VBoxContainer:
	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return text_box

func _style_button(button: Button, selected: bool) -> void:
	if owner_ui:
		owner_ui.call("_style_management_button", button, selected)

func _get_selected_module() -> Module:
	return view.get("selected_module") as Module if view != null else null

func _get_slot_feedback(weapon: Weapon, existing: Module) -> Dictionary:
	return view.call("_get_slot_feedback", weapon, existing) if view != null else {}

func _get_module_texture(module_instance: Module) -> Texture2D:
	return view.call("_get_module_texture", module_instance) as Texture2D if view != null else null

func _get_weapon_rarity_color(weapon: Weapon) -> Color:
	return view.call("_get_weapon_rarity_color", weapon) if view != null else Color.WHITE

func _format_module_install_targets(module_instance: Module) -> String:
	return str(view.call("_format_module_install_targets", module_instance)) if view != null else ""

func _can_drag_module_install_on_weapon(module_instance: Module, weapon: Weapon) -> bool:
	return bool(view.call("_can_drag_module_install_on_weapon", module_instance, weapon)) if view != null else false

func _format_module_meta(module_instance: Module) -> String:
	return LocalizationManager.tr_format(
		"ui.module.meta.level_rarity",
		{
			"level": int(module_instance.module_level),
			"rarity": RARITY_UTIL.get_display_name(module_instance.get_rarity()),
		},
		"Lv.%d  %s" % [int(module_instance.module_level), RARITY_UTIL.get_display_name(module_instance.get_rarity())]
	)

func _format_weapon_meta(weapon: Weapon) -> String:
	var display_model = WEAPON_DISPLAY_BUILDER.build_from_instance(weapon)
	return LocalizationManager.tr_format(
		"ui.weapon.meta.level_fuse",
		{
			"level": display_model.level,
			"max": display_model.max_level,
			"fuse": display_model.fuse,
		},
		"Lv.%d/%d  Fuse %d" % [display_model.level, display_model.max_level, display_model.fuse]
	)
