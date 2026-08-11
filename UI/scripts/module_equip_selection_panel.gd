extends PanelContainer
class_name ModuleEquipSelectionPanel

const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")

signal selection_completed(assigned: bool)

@export var incompatible_slot_color: Color = TOKENS.COLOR_TEXT_MUTED
@export var occupied_slot_color: Color = TOKENS.COLOR_TEXT_SECONDARY
@export var available_slot_color: Color = TOKENS.COLOR_POSITIVE
@export var feedback_text_color: Color = TOKENS.COLOR_WARNING
@export var stat_up_color: Color = TOKENS.COLOR_POSITIVE
@export var stat_down_color: Color = TOKENS.COLOR_DANGER

@onready var eyebrow_label: Label = $Margin/Root/TopRow/TitleBlock/EyebrowLabel
@onready var title_label: Label = $Margin/Root/TopRow/TitleBlock/Header/TitleLabel
@onready var progress_label: Label = $Margin/Root/TopRow/TitleBlock/Header/ProgressLabel
@onready var title_hint: Label = $Margin/Root/TopRow/TitleBlock/TitleHint
@onready var module_panel: PanelContainer = $Margin/Root/TopRow/ModulePanel
@onready var module_icon: TextureRect = $Margin/Root/TopRow/ModulePanel/Margin/Row/ModuleIcon
@onready var module_name_label: Label = $Margin/Root/TopRow/ModulePanel/Margin/Row/Info/NameRow/ModuleNameLabel
@onready var level_label: Label = $Margin/Root/TopRow/ModulePanel/Margin/Row/Info/NameRow/LevelLabel
@onready var module_label: Label = $Margin/Root/TopRow/ModulePanel/Margin/Row/Info/ModuleLabel
@onready var fit_title: Label = $Margin/Root/TopRow/ModulePanel/Margin/Row/FitSummary/FitTitle
@onready var trigger_label: Label = $Margin/Root/TopRow/ModulePanel/Margin/Row/FitSummary/TriggerLabel
@onready var section_title: Label = $Margin/Root/SectionHeader/SectionTitle
@onready var section_hint: Label = $Margin/Root/SectionHeader/SectionHint
@onready var equipped_list: GridContainer = $Margin/Root/EquippedScroll/EquippedList
@onready var cancel_button: Button = $Margin/Root/Footer/CancelButton
@onready var reward_cancel_dialog: ConfirmationDialog = $RewardCancelDialog

var _module_instance: Module
var _module_instances: Array[Module] = []
var _current_module_index := 0
var _on_item_complete: Callable = Callable()
var _on_complete: Callable = Callable()
var _allow_reward_transaction := false
var _tracked_stat_keys: PackedStringArray = [
	"damage", "attack_cooldown", "projectile_hits", "speed", "size", "hp",
	"dash_speed", "return_speed", "attack_range",
]

func _ready() -> void:
	visible = false
	_apply_visual_style()
	cancel_button.pressed.connect(_on_cancel_pressed)
	reward_cancel_dialog.confirmed.connect(_on_reward_cancel_confirmed)
	LocalizationManager.language_changed.connect(_on_language_changed)

func _input(event: InputEvent) -> void:
	if not is_modal_open() or not ModalUiController.is_cancel_input(event):
		return
	_request_cancel()
	get_viewport().set_input_as_handled()

func open_for_module(module_instance: Module, on_complete: Callable = Callable(), allow_reward_transaction: bool = false) -> bool:
	if module_instance == null or not is_instance_valid(module_instance):
		return false
	var modules: Array[Module] = [module_instance]
	return open_for_modules(modules, Callable(), on_complete, allow_reward_transaction)

func open_for_modules(module_instances: Array[Module], on_item_complete: Callable = Callable(), on_complete: Callable = Callable(), allow_reward_transaction: bool = false) -> bool:
	if visible:
		return false
	_module_instances.clear()
	for module_instance in module_instances:
		if module_instance != null and is_instance_valid(module_instance):
			_module_instances.append(module_instance)
	if _module_instances.is_empty():
		return false
	_current_module_index = 0
	_on_item_complete = on_item_complete
	_on_complete = on_complete
	_allow_reward_transaction = allow_reward_transaction
	_show_current_module()
	visible = true
	return true

func _show_current_module() -> void:
	if _current_module_index < 0 or _current_module_index >= _module_instances.size():
		_complete(true)
		return
	_module_instance = _module_instances[_current_module_index]
	if _module_instance == null or not is_instance_valid(_module_instance):
		_finish_current(false)
		return
	_apply_localized_static_text()
	progress_label.text = "%d / %d" % [_current_module_index + 1, _module_instances.size()] if _module_instances.size() > 1 else ""
	module_name_label.text = LocalizationManager.get_module_name(_module_instance)
	level_label.text = "Lv.%d" % int(_module_instance.module_level)
	var effect_lines := _module_instance.get_effect_descriptions()
	var summary := _build_module_summary(effect_lines)
	var content_lines := summary.get("content", PackedStringArray()) as PackedStringArray
	module_label.text = "\n".join(content_lines) if not content_lines.is_empty() else LocalizationManager.tr_key("ui.module.no_effect", "No direct stat changes.")
	trigger_label.text = str(summary.get("fit", LocalizationManager.tr_key("ui.module.fit.general", "All weapon types")))
	module_icon.texture = _get_node_texture(_module_instance, "%Sprite")
	_rebuild_lists()

func _build_module_summary(effect_lines: PackedStringArray) -> Dictionary:
	var content := PackedStringArray()
	var fit_text := ""
	var best_on_prefix := LocalizationManager.tr_key("ui.module.best_on_prefix", "Best On:")
	var triggers_prefix := LocalizationManager.tr_key("ui.module.triggers_prefix", "Triggers:")
	for line in effect_lines:
		var normalized := str(line).strip_edges()
		if normalized.begins_with(triggers_prefix):
			continue
		if normalized.begins_with(best_on_prefix):
			fit_text = normalized
			continue
		content.append(normalized)
	return {"content": content, "fit": fit_text if fit_text != "" else LocalizationManager.tr_key("ui.module.fit.general", "All weapon types")}

func _rebuild_lists() -> void:
	_clear_list(equipped_list)
	var weapons := _collect_equipped_weapons()
	for weapon in weapons:
		_build_weapon_row(equipped_list, weapon)

func _collect_equipped_weapons() -> Array[Weapon]:
	var result: Array[Weapon] = []
	for weapon_ref in PlayerData.player_weapon_list:
		var weapon := weapon_ref as Weapon
		if weapon and is_instance_valid(weapon):
			result.append(weapon)
	return result

func _build_weapon_row(parent: Container, weapon: Weapon) -> void:
	var feedback := InventoryData.get_weapon_module_assignment_feedback(_module_instance, weapon, null, _allow_reward_transaction)
	var replacement := _find_replacement(weapon)
	var can_equip := bool(feedback.get("ok", false)) or replacement != null
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 158)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(not can_equip))
	parent.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 14)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	card.add_child(margin)
	var card_root := HBoxContainer.new()
	card_root.add_theme_constant_override("separation", 12)
	margin.add_child(card_root)
	var left_content := VBoxContainer.new()
	left_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_content.add_theme_constant_override("separation", 8)
	card_root.add_child(left_content)
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 10)
	left_content.add_child(identity_row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(72, 68)
	icon_panel.add_theme_stylebox_override("panel", _make_icon_well_style())
	identity_row.add_child(icon_panel)
	var icon := TextureRect.new()
	icon.name = "WeaponTexture"
	icon.texture = _get_node_texture(weapon, "Sprite")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not can_equip:
		icon.modulate = Color(0.46, 0.49, 0.50, 0.62)
	icon_panel.add_child(icon)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_row.add_child(identity)
	var name_label := Label.new()
	name_label.text = _get_weapon_display_name(weapon)
	TOKENS.style_label(name_label, 20)
	identity.add_child(name_label)
	var fit_info := VBoxContainer.new()
	fit_info.add_theme_constant_override("separation", 2)
	identity.add_child(fit_info)
	var fit_label := Label.new()
	fit_label.text = "✓ %s" % LocalizationManager.tr_key("ui.module.compatible", "Compatible") if can_equip else LocalizationManager.tr_key("ui.module.fit.incompatible_short", "Incompatible")
	fit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TOKENS.style_label(fit_label, TOKENS.FONT_LABEL, stat_up_color if can_equip else feedback_text_color)
	fit_info.add_child(fit_label)
	if not can_equip:
		var reason_label := Label.new()
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.text = LocalizationManager.localize_module_reason(str(feedback.get("reason", "")))
		TOKENS.style_label(reason_label, TOKENS.FONT_CAPTION, feedback_text_color)
		fit_info.add_child(reason_label)

	var status_panel := PanelContainer.new()
	status_panel.name = "StatusEffect"
	status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_panel.add_theme_stylebox_override("panel", _make_status_style())
	left_content.add_child(status_panel)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	status_panel.add_child(status_row)
	var effect_bar := ColorRect.new()
	effect_bar.name = "PulseBar"
	effect_bar.custom_minimum_size = Vector2(4, 0)
	effect_bar.color = TOKENS.COLOR_ACCENT_SYSTEM
	effect_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(effect_bar)
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(stats)
	var stat_label := RichTextLabel.new()
	stat_label.bbcode_enabled = true
	stat_label.fit_content = true
	stat_label.scroll_active = false
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label.text = _build_stat_preview_bbcode(weapon)
	stat_label.add_theme_font_size_override("normal_font_size", TOKENS.FONT_LABEL)
	stat_label.add_theme_color_override("default_color", TOKENS.COLOR_TEXT_PRIMARY)
	stats.add_child(stat_label)
	_start_status_pulse(effect_bar)
	var modules_label := Label.new()
	modules_label.text = LocalizationManager.tr_key("ui.module.equipped_modules_prefix", "Equipped modules:")
	TOKENS.style_label(modules_label, TOKENS.FONT_CAPTION, TOKENS.COLOR_TEXT_SECONDARY)

	var right_actions := VBoxContainer.new()
	right_actions.custom_minimum_size = Vector2(220, 0)
	right_actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_actions.add_theme_constant_override("separation", 5)
	card_root.add_child(right_actions)
	right_actions.add_child(modules_label)
	var sockets := HBoxContainer.new()
	sockets.name = "ModuleSockets"
	sockets.custom_minimum_size = Vector2(220, 64)
	sockets.add_theme_constant_override("separation", 8)
	right_actions.add_child(sockets)
	var equipped_modules := weapon.get_equipped_modules()
	for index in range(int(weapon.MAX_MODULE_NUMBER)):
		sockets.add_child(_make_socket(index, equipped_modules[index] if index < equipped_modules.size() else null))
	var action := Button.new()
	action.name = "EquipButton"
	action.custom_minimum_size = Vector2(220, 36)
	action.text = LocalizationManager.tr_key("ui.module.action.equip", "Equip")
	action.disabled = not can_equip
	action.pressed.connect(_on_slot_selected.bind(weapon, replacement))
	_style_secondary_button(action)
	right_actions.add_child(action)

func _start_status_pulse(effect_bar: ColorRect) -> void:
	var tween := effect_bar.create_tween().set_loops()
	tween.tween_property(effect_bar, "modulate:a", 0.42, TOKENS.MOTION_SLOW)
	tween.tween_property(effect_bar, "modulate:a", 1.0, TOKENS.MOTION_SLOW)

func _make_socket(index: int, installed: Module) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(68, 72)
	panel.add_theme_stylebox_override("panel", _make_socket_style(installed != null))
	panel.mouse_default_cursor_shape = Control.CURSOR_HELP if installed != null else Control.CURSOR_ARROW
	if installed != null:
		panel.tooltip_text = _build_module_tooltip(installed)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.texture = _get_node_texture(installed, "%Sprite") if installed != null else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label := Label.new()
	label.text = "%02d" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOKENS.style_label(label, TOKENS.FONT_CAPTION, TOKENS.COLOR_TEXT_MUTED)
	box.add_child(label)
	return panel

func _build_module_tooltip(module_instance: Module) -> String:
	var lines: PackedStringArray = [
		"%s  Lv.%d" % [LocalizationManager.get_module_name(module_instance), int(module_instance.module_level)],
	]
	var effects := module_instance.get_effect_descriptions()
	if effects.is_empty():
		lines.append(LocalizationManager.tr_key("ui.module.no_effect", "No direct stat changes."))
	else:
		for effect in effects:
			lines.append(str(effect))
	var tags := _format_module_tags(module_instance)
	if tags != "":
		lines.append(LocalizationManager.tr_format("ui.module.tooltip.tags", {"tags": tags}, "Tags: %s" % tags))
	return "\n".join(lines)

func _find_replacement(weapon: Weapon) -> Module:
	if weapon.get_module_count() < int(weapon.MAX_MODULE_NUMBER):
		return null
	for equipped_module in weapon.get_equipped_modules():
		var feedback := InventoryData.get_weapon_module_assignment_feedback(_module_instance, weapon, equipped_module, _allow_reward_transaction)
		if bool(feedback.get("ok", false)):
			return equipped_module
	return null

func _on_slot_selected(weapon: Weapon, replaced_module: Module = null) -> void:
	if weapon == null or not is_instance_valid(weapon) or _module_instance == null:
		_complete(false)
		return
	var result := InventoryData.equip_module_to_weapon(_module_instance, weapon, replaced_module, _allow_reward_transaction)
	if not result.get("ok", false):
		_show_failure(str(result.get("reason", "")))
		return
	_finish_current(true)

func _show_failure(reason: String) -> void:
	var ui = GlobalVariables.ui
	if ui and is_instance_valid(ui) and ui.has_method("show_item_message"):
		ui.show_item_message(LocalizationManager.localize_module_reason(reason), 1.8)

func _on_cancel_pressed() -> void:
	_request_cancel()

func _request_cancel() -> void:
	if _allow_reward_transaction:
		reward_cancel_dialog.title = LocalizationManager.tr_key("ui.module.reward_cancel.title", "Store Module")
		reward_cancel_dialog.dialog_text = LocalizationManager.tr_key("ui.module.reward_cancel.confirm", "Cancel installation and keep this module in the module warehouse?")
		reward_cancel_dialog.ok_button_text = LocalizationManager.tr_key("ui.module.reward_cancel.store", "Store Module")
		reward_cancel_dialog.cancel_button_text = LocalizationManager.tr_key("ui.module.reward_cancel.back", "Return")
		reward_cancel_dialog.popup_centered(Vector2i(560, 240))
		return
	_cancel_remaining()

func _on_reward_cancel_confirmed() -> void:
	_cancel_remaining()

func close_without_assignment() -> void:
	if visible:
		_cancel_remaining()

func is_modal_open() -> bool:
	return visible

func can_cancel_modal() -> bool:
	return true

func cancel_visible_modal() -> bool:
	if not is_modal_open():
		return false
	_request_cancel()
	return true

func _complete(assigned: bool) -> void:
	visible = false
	reward_cancel_dialog.hide()
	emit_signal("selection_completed", assigned)
	if _on_complete.is_valid():
		_on_complete.call_deferred(assigned)
	_module_instance = null
	_module_instances.clear()
	_current_module_index = 0
	_on_item_complete = Callable()
	_on_complete = Callable()
	_allow_reward_transaction = false

func _finish_current(assigned: bool) -> void:
	var completed_index := _current_module_index
	var completed_module := _module_instance
	if _on_item_complete.is_valid():
		_on_item_complete.call(completed_index, completed_module, assigned)
	_current_module_index += 1
	if _current_module_index >= _module_instances.size():
		_complete(true)
	else:
		_show_current_module()

func _cancel_remaining() -> void:
	while _current_module_index < _module_instances.size():
		_module_instance = _module_instances[_current_module_index]
		if _on_item_complete.is_valid():
			_on_item_complete.call(_current_module_index, _module_instance, false)
		_current_module_index += 1
	_complete(false)

func _clear_list(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()

func _get_weapon_display_name(weapon: Weapon) -> String:
	return LocalizationManager.get_weapon_instance_display_name(weapon)

func _build_stat_preview_bbcode(weapon: Weapon) -> String:
	var current: Dictionary = weapon.build_stat_snapshot()
	var projected: Dictionary = weapon.get_projected_stats_with_module(_module_instance)
	var deltas: PackedStringArray = []
	for stat_key in _tracked_stat_keys:
		if not current.has(stat_key) or not projected.has(stat_key):
			continue
		var before := float(current[stat_key])
		var after := float(projected[stat_key])
		if is_equal_approx(before, after):
			continue
		var value_color := stat_up_color if after > before else stat_down_color
		deltas.append("%s %.2f → [color=#%s]%.2f[/color]" % [
			_format_stat_label(stat_key), before, value_color.to_html(false), after,
		])
	if deltas.is_empty():
		return LocalizationManager.tr_key("ui.module.stat_changes_none", "Stat changes: none")
	return "%s %s" % [
		LocalizationManager.tr_key("ui.module.stat_changes_prefix", "Stat changes:"),
		", ".join(deltas),
	]

func _format_stat_label(stat_key: String) -> String:
	return LocalizationManager.get_module_term(StringName("stat.%s" % stat_key), stat_key.replace("_", " ").capitalize())

func _format_module_tags(module_instance: Module) -> String:
	var tags: PackedStringArray = []
	for tag in module_instance.module_tags:
		var normalized := str(tag).strip_edges().to_lower()
		tags.append(LocalizationManager.get_module_term(StringName(normalized), normalized.capitalize()))
	return " / ".join(tags)

func _apply_localized_static_text() -> void:
	eyebrow_label.text = LocalizationManager.tr_key("ui.module.terminal", "Module Assembly Terminal")
	title_label.text = LocalizationManager.tr_key("ui.module.title", "Equip Module")
	title_hint.text = LocalizationManager.tr_key("ui.module.panel_hint", "Choose a compatible weapon to install the module.")
	fit_title.text = LocalizationManager.tr_key("ui.module.fit.title", "Fit Check")
	section_title.text = LocalizationManager.tr_key("ui.module.choose_weapon", "Choose Weapon")
	section_hint.text = LocalizationManager.tr_key("ui.module.choose_weapon_hint", "Choose a weapon to install this module.")
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")

func _get_node_texture(owner: Node, path: NodePath) -> Texture2D:
	if owner == null or not is_instance_valid(owner):
		return null
	var sprite := owner.get_node_or_null(path) as Sprite2D
	return sprite.texture if sprite != null else null

func _apply_visual_style() -> void:
	_apply_localized_static_text()
	add_theme_stylebox_override("panel", TOKENS.make_panel_style(true, TOKENS.COLOR_BORDER_STRONG))
	TOKENS.style_label(eyebrow_label, TOKENS.FONT_CAPTION, TOKENS.COLOR_ACCENT_SYSTEM)
	TOKENS.style_label(title_label, TOKENS.FONT_DISPLAY)
	TOKENS.style_label(progress_label, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_SECONDARY)
	TOKENS.style_label(title_hint, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_SECONDARY)
	module_panel.add_theme_stylebox_override("panel", TOKENS.make_panel_style(false, TOKENS.COLOR_BORDER))
	TOKENS.style_label(module_name_label, TOKENS.FONT_TITLE)
	TOKENS.style_label(level_label, TOKENS.FONT_LABEL, TOKENS.COLOR_ACCENT_SYSTEM)
	TOKENS.style_label(module_label, TOKENS.FONT_BODY, TOKENS.COLOR_TEXT_PRIMARY)
	TOKENS.style_label(fit_title, TOKENS.FONT_CAPTION, TOKENS.COLOR_ACCENT_SYSTEM)
	TOKENS.style_label(trigger_label, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_SECONDARY)
	TOKENS.style_label(section_title, TOKENS.FONT_TITLE, TOKENS.COLOR_ACCENT_SYSTEM)
	TOKENS.style_label(section_hint, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_SECONDARY)
	equipped_list.add_theme_constant_override("separation", 10)
	_style_secondary_button(cancel_button)

func _make_card_style(disabled: bool = false) -> StyleBoxFlat:
	var style := TOKENS.make_panel_style(false, Color(0.28, 0.31, 0.33, 0.72) if disabled else TOKENS.COLOR_BORDER)
	style.bg_color = Color(0.055, 0.060, 0.064, 0.94) if disabled else TOKENS.COLOR_SURFACE_ELEVATED
	return style

func _make_icon_well_style() -> StyleBoxFlat:
	var style := TOKENS.make_panel_style(false, TOKENS.COLOR_BORDER)
	style.bg_color = TOKENS.COLOR_CANVAS
	return style

func _make_socket_style(occupied: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TOKENS.COLOR_SURFACE_INTERACTIVE if occupied else TOKENS.COLOR_CANVAS
	style.border_color = TOKENS.COLOR_ACCENT_SYSTEM if occupied else TOKENS.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(TOKENS.RADIUS_SMALL)
	return style

func _make_status_style() -> StyleBoxFlat:
	var accent := TOKENS.COLOR_ACCENT_SYSTEM
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.07)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	style.set_border_width_all(1)
	style.set_corner_radius_all(TOKENS.RADIUS_SMALL)
	style.content_margin_left = 8
	style.content_margin_top = 5
	style.content_margin_right = 8
	style.content_margin_bottom = 5
	return style

func _style_secondary_button(button: Button) -> void:
	var styles := TOKENS.make_button_style(TOKENS.COLOR_SURFACE_INTERACTIVE, TOKENS.COLOR_ACCENT_SYSTEM)
	for state in styles:
		button.add_theme_stylebox_override(state, styles[state])
	button.add_theme_color_override("font_color", TOKENS.COLOR_TEXT_PRIMARY)

func _style_primary_button(button: Button) -> void:
	var styles := TOKENS.make_button_style(Color(0.34, 0.20, 0.035, 1.0), TOKENS.COLOR_ACCENT_ACTION)
	for state in styles:
		button.add_theme_stylebox_override(state, styles[state])
	button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))

func _on_language_changed(_locale: String) -> void:
	if visible and _module_instance != null and is_instance_valid(_module_instance):
		_show_current_module()
