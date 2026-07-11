extends Control
class_name RewardSelectionPanel

signal reward_confirmed(reward: RewardInfo)
signal selection_cancelled

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const PREVIEW_FORMATTER := preload("res://UI/scripts/weapon_obtain_preview_formatter.gd")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")

@onready var title_label: Label = $Panel/VBox/Title
@onready var panel: Panel = $Panel
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_scroll: ScrollContainer = $Panel/VBox/OptionsScroll
@onready var options_box: GridContainer = $Panel/VBox/OptionsScroll/Options
@onready var detail_title_label: Label = get_node_or_null("Panel/VBox/DetailPanel/Margin/DetailHBox/DetailVBox/DetailTitle") as Label
@onready var detail_vbox: VBoxContainer = get_node_or_null("Panel/VBox/DetailPanel/Margin/DetailHBox/DetailVBox") as VBoxContainer
@onready var detail_body_label: Label = get_node_or_null("Panel/VBox/DetailPanel/Margin/DetailHBox/DetailVBox/DetailBody") as Label
@onready var detail_outcome_label: Label = get_node_or_null("Panel/VBox/DetailPanel/Margin/DetailHBox/DetailVBox/DetailOutcome") as Label
@onready var confirm_button: Button = $Panel/VBox/DetailPanel/Margin/DetailHBox/ConfirmButton
@onready var cancel_button: Button = $Panel/VBox/Footer/CancelButton

var _reward_options: Array[RewardInfo] = []
var _selected_index: int = -1
var _on_confirm: Callable = Callable()
var _on_cancel: Callable = Callable()
var _route_display_name_cache: String = ""
var _allow_cancel: bool = true
var _title_override_cache: String = ""
var _subtitle_override_cache: String = ""
var _progress_index_cache: int = 0
var _progress_total_cache: int = 0
var _detail_chip_row: HBoxContainer
var _summary_mode := false
var _show_draft_hint_cache := false
var _pinned_index := 0
var _hover_index := -1
var _focus_index := -1
var _entry_tween: Tween

func _ready() -> void:
	visible = false
	if not confirm_button.is_connected("pressed", Callable(self, "_on_confirm_pressed")):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)
	_apply_action_button_style(confirm_button, true)
	_apply_action_button_style(cancel_button, false)
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)
	if not options_scroll.resized.is_connected(_update_grid_columns):
		options_scroll.resized.connect(_update_grid_columns)

func _input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	if not ModalUiController.is_cancel_input(event):
		return
	cancel_visible_modal()
	get_viewport().set_input_as_handled()

func open_for_rewards(
	route_display_name: String,
	reward_options: Array[RewardInfo],
	on_confirm: Callable = Callable(),
	on_cancel: Callable = Callable(),
	allow_cancel: bool = true,
	title_override: String = "",
	subtitle_override: String = "",
	progress_index: int = 0,
	progress_total: int = 0,
	show_draft_hint: bool = false
) -> bool:
	if visible:
		return false
	_summary_mode = false
	return _open_rewards(
		route_display_name,
		reward_options,
		on_confirm,
		on_cancel,
		allow_cancel,
		title_override,
		subtitle_override,
		progress_index,
		progress_total,
		show_draft_hint
	)

func open_for_summary(
	rewards: Array[RewardInfo],
	on_close: Callable = Callable(),
	title_override: String = "",
	subtitle_override: String = ""
) -> bool:
	if visible:
		return false
	_summary_mode = true
	return _open_rewards("", rewards, on_close, Callable(), true, title_override, subtitle_override)

func _open_rewards(
	route_display_name: String,
	reward_options: Array[RewardInfo],
	on_confirm: Callable,
	on_cancel: Callable,
	allow_cancel: bool,
	title_override: String,
	subtitle_override: String,
	progress_index: int = 0,
	progress_total: int = 0,
	show_draft_hint: bool = false
) -> bool:
	if reward_options.is_empty():
		return false
	if visible:
		return false
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	_allow_cancel = allow_cancel
	_route_display_name_cache = route_display_name
	_title_override_cache = title_override
	_subtitle_override_cache = subtitle_override
	_progress_index_cache = progress_index
	_progress_total_cache = progress_total
	_show_draft_hint_cache = show_draft_hint
	_selected_index = -1
	_pinned_index = 0
	_hover_index = -1
	_focus_index = -1
	_reward_options.clear()
	title_label.text = title_override if title_override != "" else LocalizationManager.tr_key(
		"ui.task_reward.summary_title" if _summary_mode else "ui.reward.title",
		"Objective Rewards" if _summary_mode else "Choose Reward"
	)
	subtitle_label.text = _build_subtitle_text(route_display_name, subtitle_override, progress_index, progress_total, show_draft_hint)
	confirm_button.text = _get_confirm_button_text()
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	cancel_button.visible = _allow_cancel and not _summary_mode
	cancel_button.disabled = not _allow_cancel or _summary_mode
	_update_detail_panel({})
	for child in options_box.get_children():
		options_box.remove_child(child)
		child.queue_free()
	var incoming_options := reward_options.duplicate()
	for reward in incoming_options:
		if reward == null:
			continue
		_reward_options.append(reward)
	if _reward_options.is_empty():
		return false
	for idx in range(_reward_options.size()):
		var button := _build_reward_card_button(_reward_options[idx])
		button.pressed.connect(Callable(self, "_on_reward_button_pressed").bind(idx, button))
		if _summary_mode:
			button.mouse_entered.connect(_on_reward_hover_entered.bind(idx))
			button.mouse_exited.connect(_on_reward_hover_exited.bind(idx))
			button.focus_entered.connect(_on_reward_focus_entered.bind(idx))
			button.focus_exited.connect(_on_reward_focus_exited.bind(idx))
		options_box.add_child(button)
	if options_box.get_child_count() > 0:
		var first := options_box.get_child(0) as Button
		if first:
			_on_reward_button_pressed(0, first)
	_update_grid_columns()
	_confirm_button_state()
	visible = true
	_play_entry_animation()
	return true

func _build_subtitle_text(
	route_display_name: String,
	subtitle_override: String,
	progress_index: int,
	progress_total: int,
	show_draft_hint: bool
) -> String:
	var subtitle := subtitle_override if subtitle_override != "" else LocalizationManager.tr_format(
		"ui.task_reward.summary_subtitle" if _summary_mode else "ui.reward.subtitle",
		{} if _summary_mode else {"route": route_display_name},
		"Rewards added to inventory." if _summary_mode else "Pick 1 option"
	)
	if not _summary_mode and subtitle_override == "":
		subtitle = LocalizationManager.tr_key("ui.reward.pick_one", "Pick 1 option")
	if show_draft_hint and not _summary_mode:
		var hint := LocalizationManager.tr_key(
			"ui.reward.draft.weapon_evolution_hint",
			"New weapons may trigger evolution effects."
		)
		if hint.strip_edges() != "":
			subtitle = "%s\n%s" % [subtitle, hint]
	if progress_index <= 0 or progress_total <= 0:
		return subtitle
	var progress_text := LocalizationManager.tr_format(
		"ui.task_reward.progress",
		{"current": progress_index, "total": progress_total},
		"Reward %d/%d" % [progress_index, progress_total]
	)
	return "%s\n%s" % [subtitle, progress_text]

func close_panel() -> void:
	_kill_entry_tween()
	visible = false
	modulate.a = 1.0
	panel.scale = Vector2.ONE
	_reward_options.clear()
	_selected_index = -1
	_on_confirm = Callable()
	_on_cancel = Callable()
	_allow_cancel = true
	_summary_mode = false
	_pinned_index = 0
	_hover_index = -1
	_focus_index = -1
	_title_override_cache = ""
	_subtitle_override_cache = ""
	_progress_index_cache = 0
	_progress_total_cache = 0
	_show_draft_hint_cache = false
	_update_detail_panel({})

func _play_entry_animation() -> void:
	_kill_entry_tween()
	modulate.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.96, 0.96)
	_entry_tween = create_tween()
	_entry_tween.set_trans(Tween.TRANS_QUAD)
	_entry_tween.set_ease(Tween.EASE_OUT)
	_entry_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	_entry_tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.18)

func _kill_entry_tween() -> void:
	if _entry_tween != null:
		_entry_tween.kill()
		_entry_tween = null

func is_modal_open() -> bool:
	return visible

func can_cancel_modal() -> bool:
	return _allow_cancel

func cancel_visible_modal() -> bool:
	if not is_modal_open() or not can_cancel_modal():
		return false
	if _summary_mode:
		_on_confirm_pressed()
		return true
	_on_cancel_pressed()
	return true

func _on_reward_button_pressed(index: int, source_button: Button) -> void:
	if _summary_mode:
		_pinned_index = index
	else:
		_selected_index = index
	if index >= 0 and index < _reward_options.size():
		_update_summary_detail()
	else:
		_update_detail_panel({})
	var child_index := 0
	for child in options_box.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := child_index == (_pinned_index if _summary_mode else _selected_index)
		button.button_pressed = selected
		if child_index < _reward_options.size():
			_apply_reward_card_style(button, _reward_options[child_index], selected)
		child_index += 1
	_confirm_button_state()

func _on_reward_hover_entered(index: int) -> void:
	_hover_index = index
	_update_summary_detail()

func _on_reward_hover_exited(index: int) -> void:
	if _hover_index == index:
		_hover_index = -1
	_update_summary_detail()

func _on_reward_focus_entered(index: int) -> void:
	_focus_index = index
	_update_summary_detail()

func _on_reward_focus_exited(index: int) -> void:
	if _focus_index == index:
		_focus_index = -1
	_update_summary_detail()

func _update_summary_detail() -> void:
	var index := _selected_index
	if _summary_mode:
		index = _hover_index if _hover_index >= 0 else (_focus_index if _focus_index >= 0 else _pinned_index)
	if index >= 0 and index < _reward_options.size():
		_update_detail_panel(_build_reward_display_data(_reward_options[index]))
	else:
		_update_detail_panel({})

func _update_grid_columns() -> void:
	if options_box == null or options_scroll == null:
		return
	options_box.columns = clampi(int(options_scroll.size.x / 222.0), 1, 4)

func _confirm_button_state() -> void:
	confirm_button.disabled = false if _summary_mode else _selected_index < 0 or _selected_index >= _reward_options.size()
	confirm_button.text = _get_confirm_button_text()

func _get_confirm_button_text() -> String:
	if _summary_mode:
		return LocalizationManager.tr_key("ui.task_reward.summary_confirm", "Continue")
	if _selected_index < 0 or _selected_index >= _reward_options.size():
		return LocalizationManager.tr_key("ui.reward.select_prompt", "Select a reward")
	return LocalizationManager.tr_key("ui.reward.confirm", "Confirm Reward")

func _on_confirm_pressed() -> void:
	if _summary_mode:
		if _on_confirm.is_valid():
			_on_confirm.call_deferred()
		close_panel()
		return
	if _selected_index < 0 or _selected_index >= _reward_options.size():
		return
	var reward := _reward_options[_selected_index]
	reward_confirmed.emit(reward)
	if _on_confirm.is_valid():
		_on_confirm.call_deferred(reward)
	close_panel()

func _on_cancel_pressed() -> void:
	if not _allow_cancel:
		return
	selection_cancelled.emit()
	if _on_cancel.is_valid():
		_on_cancel.call_deferred()
	close_panel()

func _build_reward_card_button(reward: RewardInfo) -> Button:
	var card_data: Dictionary = _build_reward_display_data(reward)
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(230, 176)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	button.tooltip_text = str(card_data.get("title", "Reward"))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	button.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	margin.add_child(body)

	var rarity_bar := ColorRect.new()
	rarity_bar.color = RARITY_UTIL.get_color(reward.get_rarity())
	rarity_bar.custom_minimum_size = Vector2(0, 4)
	rarity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rarity_bar)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 8)
	body.add_child(top_row)

	var type_badge := _make_badge_label(str(card_data.get("type_label", "Reward")).to_upper(), Color(0.58, 0.76, 0.92, 1.0))
	type_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(type_badge)

	var selected_badge := _make_badge_label(LocalizationManager.tr_key("ui.reward.selected", "SELECTED"), _get_reward_action_color(reward))
	selected_badge.name = "SelectedBadge"
	selected_badge.visible = false
	top_row.add_child(selected_badge)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	body.add_child(header)
	header.add_child(_make_reward_icon(card_data))

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	header.add_child(text_box)

	var name_label := _make_card_label(str(card_data.get("title", "Reward")), 16, Color(0.94, 0.97, 1.0, 1.0))
	var summary_count := int(reward.get_meta("summary_count", 1))
	if _summary_mode and summary_count > 1:
		name_label.text += " " + LocalizationManager.tr_format(
			"ui.reward.summary.count_suffix",
			{"count": summary_count},
			"x%d" % summary_count
		)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(0.0, 38.0)
	text_box.add_child(name_label)

	var meta_text := str(card_data.get("meta_text", "")).strip_edges()
	var level_text := str(card_data.get("level_text", "")).strip_edges()
	var meta_label := _make_card_label(level_text if level_text != "" else meta_text, 12, Color(0.74, 0.84, 0.88, 1.0))
	meta_label.clip_text = true
	text_box.add_child(meta_label)

	var summary_label := _make_card_label(str(card_data.get("summary_text", "")).strip_edges(), 12, Color(0.80, 0.88, 0.92, 1.0))
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.max_lines_visible = 2
	summary_label.custom_minimum_size = Vector2(0.0, 34.0)
	body.add_child(summary_label)

	var tag_text := str(card_data.get("short_tag", "")).strip_edges()
	var chips: Array = card_data.get("chips", [])
	if not chips.is_empty():
		var chip_row := BUILD_TAG_DISPLAY.make_chip_row(chips, 4)
		body.add_child(chip_row)
	elif tag_text != "":
		var tag_label := _make_card_label(tag_text, 12, Color(0.78, 0.86, 0.92, 1.0))
		tag_label.clip_text = true
		body.add_child(tag_label)

	_set_mouse_filter_recursive(button, Control.MOUSE_FILTER_IGNORE)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_reward_card_style(button, reward, false)
	return button

func _build_reward_card_data(reward: RewardInfo) -> Dictionary:
	var data := {
		"type": _localize_reward_category("Economy"),
		"name": LocalizationManager.tr_key("ui.reward.default", "Reward"),
		"tag": "",
	}
	if reward == null:
		return data
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon_name := reward.target_weapon_name.strip_edges()
		if weapon_name.strip_edges() == "":
			weapon_name = LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		data["type"] = _format_reward_type_label(reward, "Weapon")
		data["name"] = weapon_name
		data["tag"] = "Lv.%d -> Lv.%d" % [int(reward.target_weapon_from_level), int(reward.target_weapon_to_level)]
		return data
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		var definition := CellEffectRuntime.get_definition(reward.cell_effect_id)
		data["name"] = definition.get_display_name() if definition != null else _localize_reward_category("Cell Effect")
		data["type"] = _format_reward_type_label(reward, "Terrain")
		data["tag"] = _localize_reward_category("Cell Effect")
		return data
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		var task_definition := CellTaskModuleRuntime.get_definition(reward.task_module_id)
		if task_definition != null:
			data["name"] = task_definition.get_display_name()
			data["tag"] = task_definition.get_task_label()
		else:
			data["name"] = _localize_reward_category("Task Module")
			data["tag"] = _localize_reward_category("Task")
		data["type"] = _localize_reward_category("Task")
		return data
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_name := LocalizationManager.get_weapon_name_by_id(reward.item_id, reward.item_id)
		var base_weapon_text := LocalizationManager.tr_format(
			"ui.reward.weapon",
			{"id": weapon_name, "level": reward.item_level},
			"Weapon %s Lv.%d" % [weapon_name, reward.item_level]
		)
		var weapon_text := base_weapon_text
		var outcome := _get_weapon_obtain_prediction(reward.item_id)
		var result_type := str(outcome.get("result", "not_applicable"))
		if not outcome.is_empty():
			weapon_text = _format_weapon_obtain_prediction(base_weapon_text, weapon_name, outcome)
		if result_type == "fused":
			data["type"] = _format_reward_type_label(reward, LocalizationManager.tr_key("ui.reward.type.weapon_fusion", "Weapon Fusion"))
		elif result_type == "converted_to_gold":
			data["type"] = _format_reward_type_label(reward, LocalizationManager.tr_key("ui.reward.type.duplicate_weapon", "Duplicate Weapon"))
		else:
			data["type"] = _format_reward_type_label(reward, "Weapon")
		data["name"] = weapon_name
		data["tag"] = weapon_text if weapon_text != base_weapon_text else "Lv.%d" % int(reward.item_level)
		return data
	if reward.module_scene:
		var module_name := _extract_scene_name(reward.module_scene.resource_path)
		var module_id := reward.module_scene.resource_path.get_file().get_basename()
		if module_id != "":
			module_name = LocalizationManager.tr_key("module.%s.name" % module_id, module_name)
		data["type"] = _format_reward_type_label(reward, "Module")
		data["name"] = module_name
		data["tag"] = "Lv.%d" % max(1, reward.module_level)
		return data
	var economy_lines: PackedStringArray = []
	if reward.total_chip_value > 0:
		economy_lines.append(LocalizationManager.tr_format(
			"ui.reward.exp",
			{"value": reward.total_chip_value},
			"EXP +%d" % reward.total_chip_value
		))
	if reward.gold_value > 0:
		economy_lines.append(LocalizationManager.tr_format(
			"ui.reward.gold",
			{"value": reward.gold_value},
			"Gold +%d" % reward.gold_value
		))
	if not economy_lines.is_empty():
		var category := "Economy" if reward.gold_value > 0 or reward.reward_kind == RewardInfo.KIND_ECONOMY else "Supply"
		data["type"] = _format_reward_type_label(reward, category)
		data["name"] = economy_lines[0]
		if economy_lines.size() > 1:
			data["tag"] = economy_lines[1]
	return data

func _format_reward_type_label(_reward: RewardInfo, category: String) -> String:
	var localized_category := _localize_reward_category(category)
	if _reward == null:
		return localized_category
	if _reward.reward_kind == RewardInfo.KIND_CELL_EFFECT or _reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return localized_category
	var rarity_label := RARITY_UTIL.get_display_name(_reward.get_rarity())
	if rarity_label == "" or rarity_label == RARITY_UTIL.get_display_name(RARITY_UTIL.COMMON):
		return localized_category
	return LocalizationManager.tr_format(
		"ui.reward.type.with_rarity",
		{"rarity": rarity_label, "category": localized_category},
		"%s %s" % [rarity_label, localized_category]
	)

func _localize_reward_category(category: String) -> String:
	var normalized := category.strip_edges()
	match normalized:
		"Weapon":
			return LocalizationManager.tr_key("ui.reward.category.weapon", normalized)
		"Module":
			return LocalizationManager.tr_key("ui.reward.category.module", normalized)
		"Terrain":
			return LocalizationManager.tr_key("ui.reward.category.terrain", normalized)
		"Task":
			return LocalizationManager.tr_key("ui.reward.category.task", normalized)
		"Task Module":
			return LocalizationManager.tr_key("ui.reward.category.task_module", normalized)
		"Economy":
			return LocalizationManager.tr_key("ui.reward.category.economy", normalized)
		"Supply":
			return LocalizationManager.tr_key("ui.reward.category.supply", normalized)
		"Cell Effect":
			return LocalizationManager.tr_key("ui.reward.category.cell_effect", normalized)
		"New Weapon":
			return LocalizationManager.tr_key("ui.reward.category.new_weapon", normalized)
		"Reward":
			return LocalizationManager.tr_key("ui.reward.default", normalized)
		_:
			return normalized

func _build_reward_display_data(reward: RewardInfo) -> Dictionary:
	var data := {
		"title": LocalizationManager.tr_key("ui.reward.default", "Reward"),
		"type_label": _localize_reward_category("Supply"),
		"short_tag": "",
		"detail_text": "",
		"outcome_text": "",
		"rarity": RARITY_UTIL.COMMON,
		"chips": [],
		"meta_text": "",
		"level_text": "",
		"summary_text": "",
		"detail_bullets": PackedStringArray(),
		"icon_texture": null,
		"fallback_icon_key": "reward",
		"icon_badge_text": "",
		"icon_badge_color": Color(0.42, 0.78, 0.48, 1.0),
	}
	if reward == null:
		return data
	data["rarity"] = reward.get_rarity()
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		var weapon_name := reward.target_weapon_name.strip_edges()
		if weapon_name == "":
			weapon_name = LocalizationManager.tr_key("ui.branch.weapon", "Weapon")
		data["title"] = weapon_name
		data["type_label"] = _format_reward_type_label(reward, LocalizationManager.tr_key("ui.reward.type.weapon_upgrade", "Weapon Upgrade"))
		data["short_tag"] = "Lv.%d -> Lv.%d" % [int(reward.target_weapon_from_level), int(reward.target_weapon_to_level)]
		data["level_text"] = str(data["short_tag"])
		data["meta_text"] = LocalizationManager.tr_format(
			"ui.reward.meta.equipped_weapon_upgrade",
			{"from": int(reward.target_weapon_from_level), "to": int(reward.target_weapon_to_level)},
			"Equipped weapon upgrade: Lv.%d -> Lv.%d" % [int(reward.target_weapon_from_level), int(reward.target_weapon_to_level)]
		)
		data["fallback_icon_key"] = "weapon"
		data["icon_badge_text"] = "Lv"
		data["icon_badge_color"] = _get_reward_action_color(reward)
		var upgrade_detail := PackedStringArray([str(data["short_tag"])])
		var target_definition := DataHandler.read_weapon_data(reward.target_weapon_id) as WeaponDefinition
		if target_definition != null:
			data["icon_texture"] = target_definition.icon
			var description := LocalizationManager.get_weapon_description_from_definition(target_definition).strip_edges()
			if description != "":
				upgrade_detail.append(description)
		data["detail_text"] = "\n".join(upgrade_detail)
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.weapon_upgrade", "Upgrade equipped weapon level")
		data["summary_text"] = _first_sentence(str(data["detail_text"]), LocalizationManager.tr_key("ui.reward.summary.weapon_upgrade", "Upgrade equipped weapon level."))
		data["detail_bullets"] = _fallback_detail_bullets(reward)
		return data
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		var definition := CellEffectRuntime.get_definition(reward.cell_effect_id)
		if definition != null:
			data["title"] = definition.get_display_name()
			data["detail_text"] = definition.get_description()
			data["icon_texture"] = definition.icon_texture
		else:
			data["title"] = _localize_reward_category("Cell Effect")
		data["type_label"] = _format_reward_type_label(reward, "Terrain")
		data["short_tag"] = _localize_reward_category("Cell Effect")
		data["level_text"] = str(data["short_tag"])
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.cell_effect_meta", "Terrain Effect")
		data["fallback_icon_key"] = "terrain"
		data["chips"] = [BUILD_TAG_DISPLAY.build_tag_chip(&"terrain", _localize_reward_category("Terrain"))]
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.cell_effect", "Added to cell effects")
		data["summary_text"] = _first_sentence(str(data["detail_text"]), LocalizationManager.tr_key("ui.reward.summary.cell_effect", "Adds a terrain effect."))
		data["detail_bullets"] = _fallback_detail_bullets(reward)
		return data
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		var task_definition := CellTaskModuleRuntime.get_definition(reward.task_module_id)
		if task_definition != null:
			data["title"] = task_definition.get_display_name()
			data["short_tag"] = LocalizationManager.tr_format(
				"ui.reward.task_tag",
				{"task": task_definition.get_task_label()},
				"Task: %s" % task_definition.get_task_label()
			)
			data["detail_text"] = task_definition.get_description()
			data["icon_texture"] = task_definition.icon_texture
			data["meta_text"] = LocalizationManager.tr_format(
				"ui.reward.task_module_meta",
				{"task": task_definition.get_task_label()},
				"%s Task Module" % task_definition.get_task_label()
			)
		else:
			data["title"] = _localize_reward_category("Task Module")
			data["short_tag"] = LocalizationManager.tr_format(
				"ui.reward.task_tag",
				{"task": LocalizationManager.tr_key("ui.common.unknown", "Unknown")},
				"Task: Unknown"
			)
			data["meta_text"] = _localize_reward_category("Task Module")
		data["type_label"] = _localize_reward_category("Task Module")
		data["fallback_icon_key"] = "task"
		data["chips"] = [BUILD_TAG_DISPLAY.build_tag_chip(&"task", _localize_reward_category("Task"))]
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.task_module", "Added to Ready To Install")
		data["level_text"] = str(data["short_tag"])
		data["summary_text"] = _first_sentence(str(data["detail_text"]), LocalizationManager.tr_key("ui.reward.summary.task_module", "Adds a task module."))
		data["detail_bullets"] = _fallback_detail_bullets(reward)
		return data
	var summary_chunks: PackedStringArray = []
	var detail_chunks: PackedStringArray = []
	data["type_label"] = _format_reward_type_label(reward, "Reward")
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var weapon_name := LocalizationManager.get_weapon_name_by_id(reward.item_id, reward.item_id)
		var weapon_definition := DataHandler.read_weapon_data(reward.item_id) as WeaponDefinition
		var base_weapon_text := LocalizationManager.tr_format(
			"ui.reward.weapon",
			{"id": weapon_name, "level": reward.item_level},
			"Weapon %s Lv.%d" % [weapon_name, reward.item_level]
		)
		var weapon_text := base_weapon_text
		var outcome := _get_weapon_obtain_prediction(reward.item_id)
		var result_type := str(outcome.get("result", "not_applicable"))
		if result_type == "not_applicable":
			outcome = _with_new_weapon_destination_prediction(outcome)
		if not outcome.is_empty():
			weapon_text = _format_weapon_obtain_prediction(base_weapon_text, weapon_name, outcome)
		summary_chunks.append(weapon_name)
		detail_chunks.append(weapon_text)
		if weapon_definition != null:
			data["icon_texture"] = weapon_definition.icon
			var weapon_description := LocalizationManager.get_weapon_description_from_definition(weapon_definition).strip_edges()
			if weapon_description != "":
				detail_chunks.append(weapon_description)
		data["type_label"] = _format_reward_type_label(reward, "New Weapon")
		data["level_text"] = "Lv.%d" % int(reward.item_level)
		data["meta_text"] = LocalizationManager.tr_format(
			"ui.reward.level_category_meta",
			{"level": int(reward.item_level), "category": LocalizationManager.tr_key("ui.branch.weapon", "Weapon")},
			"Lv.%d - %s" % [int(reward.item_level), LocalizationManager.tr_key("ui.branch.weapon", "Weapon")]
		)
		data["fallback_icon_key"] = "weapon"
		data["icon_badge_text"] = "+"
		data["icon_badge_color"] = Color(0.42, 0.78, 0.48, 1.0)
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.weapon_obtain", "Obtain new weapon")
		if result_type == "fused":
			var from_fuse := int(outcome.get("from_fuse", 1))
			var target_fuse := int(outcome.get("target_fuse", 1))
			data["type_label"] = _format_reward_type_label(reward, LocalizationManager.tr_key("ui.reward.type.weapon_fusion", "Weapon Fusion"))
			data["meta_text"] = LocalizationManager.tr_format(
				"ui.reward.meta.weapon_fuse",
				{"from": from_fuse, "to": target_fuse},
				"Fuse %d -> %d" % [from_fuse, target_fuse]
			)
			data["icon_badge_text"] = "^"
			data["icon_badge_color"] = _get_reward_action_color(reward)
			data["outcome_text"] = LocalizationManager.tr_format(
				"ui.reward.outcome.weapon_fuse",
				{"name": weapon_name, "fuse": target_fuse},
				"Fuse equipped %s to Fuse %d; choose a branch next if one is available" % [weapon_name, target_fuse]
			)
		elif result_type == "converted_to_gold":
			var gold_value := int(outcome.get("gold", 0))
			data["title"] = LocalizationManager.tr_format(
				"ui.reward.gold",
				{"value": gold_value},
				"Gold +%d" % gold_value
			)
			data["type_label"] = _format_reward_type_label(reward, "Economy")
			data["meta_text"] = LocalizationManager.tr_key("ui.reward.economy_meta", "Run Resource")
			data["short_tag"] = ""
			summary_chunks.clear()
			summary_chunks.append(str(data["title"]))
			detail_chunks.clear()
			detail_chunks.append(str(data["title"]))
			data["icon_badge_text"] = "$"
			data["icon_badge_color"] = _get_reward_action_color(reward)
			data["fallback_icon_key"] = "economy"
			data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.resource", "Added to resources")
	if reward.module_scene:
		var module_data := _build_module_reward_display_data(reward.module_scene, reward.module_level)
		var module_name := str(module_data.get("name", _extract_scene_name(reward.module_scene.resource_path)))
		var module_summary := LocalizationManager.tr_format(
			"ui.reward.module",
			{"name": module_name, "level": max(1, reward.module_level)},
			"Module %s Lv.%d" % [module_name, max(1, reward.module_level)]
		)
		summary_chunks.append(module_name)
		detail_chunks.append(module_summary)
		var module_short_tag := str(module_data.get("short_tag", "")).strip_edges()
		if module_short_tag != "":
			summary_chunks.append(module_short_tag)
		var module_detail := str(module_data.get("detail_text", "")).strip_edges()
		if module_detail != "":
			detail_chunks.append(module_detail)
		data["chips"] = module_data.get("chips", [])
		data["icon_texture"] = module_data.get("icon_texture", null)
		data["fallback_icon_key"] = "module"
		data["meta_text"] = LocalizationManager.tr_format(
			"ui.reward.level_category_meta",
			{"level": max(1, reward.module_level), "category": _format_reward_type_label(reward, "Module")},
			"Lv.%d - %s" % [max(1, reward.module_level), _format_reward_type_label(reward, "Module")]
		)
		data["type_label"] = _format_reward_type_label(reward, "Module")
		data["level_text"] = "Lv.%d" % max(1, reward.module_level)
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.module_obtain", "Added to temporary modules")
	if reward.total_chip_value > 0:
		summary_chunks.append(LocalizationManager.tr_format(
			"ui.reward.exp",
			{"value": reward.total_chip_value},
			"EXP +%d" % reward.total_chip_value
		))
		data["chips"] = _append_display_chip(data.get("chips", []), BUILD_TAG_DISPLAY.build_tag_chip(&"economy", _localize_reward_category("Economy")))
		data["type_label"] = _format_reward_type_label(reward, "Economy")
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.economy_meta", "Run Resource")
		data["fallback_icon_key"] = "economy"
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.resource", "Added to resources")
	if reward.gold_value > 0:
		summary_chunks.append(LocalizationManager.tr_format(
			"ui.reward.gold",
			{"value": reward.gold_value},
			"Gold +%d" % reward.gold_value
		))
		data["chips"] = _append_display_chip(data.get("chips", []), BUILD_TAG_DISPLAY.build_tag_chip(&"economy", _localize_reward_category("Economy")))
		data["type_label"] = _format_reward_type_label(reward, "Economy")
		data["meta_text"] = LocalizationManager.tr_key("ui.reward.economy_meta", "Run Resource")
		data["fallback_icon_key"] = "economy"
		data["outcome_text"] = LocalizationManager.tr_key("ui.reward.outcome.resource", "Added to resources")
	if not summary_chunks.is_empty():
		data["title"] = summary_chunks[0]
		if summary_chunks.size() > 1:
			data["short_tag"] = " + ".join(summary_chunks.slice(1))
		var detail_source: PackedStringArray = detail_chunks if not detail_chunks.is_empty() else summary_chunks
		data["detail_text"] = " + ".join(detail_source)
	data["summary_text"] = _first_sentence(str(data["detail_text"]), _fallback_summary(reward))
	if str(data["level_text"]).strip_edges() == "":
		data["level_text"] = _derive_level_text(reward, data)
	data["detail_bullets"] = _fallback_detail_bullets(reward)
	return data

func _build_module_reward_display_data(module_scene: PackedScene, module_level: int) -> Dictionary:
	var data := {
		"name": "",
		"short_tag": "",
		"detail_text": "",
		"chips": [],
		"icon_texture": null,
	}
	if module_scene == null:
		return data
	var module_instance := module_scene.instantiate() as Module
	if module_instance == null:
		return data
	module_instance.set_module_level(max(1, module_level))
	data["name"] = LocalizationManager.get_module_name(module_instance)
	data["icon_texture"] = _get_module_texture(module_instance)
	var fit_data: Dictionary = MODULE_FIT_FORMATTER.build_display_data(module_instance, MODULE_FIT_FORMATTER.get_current_weapon())
	var effect_chips: Array = fit_data.get("effect_chips", [])
	var chips: Array = []
	chips.append(fit_data.get("fit_badge", {}))
	for chip in effect_chips:
		chips.append(chip)
	data["chips"] = chips
	var tag_parts := PackedStringArray()
	var fit_label := str(fit_data.get("fit_label", "")).strip_edges()
	if fit_label != "":
		tag_parts.append(fit_label)
	for label in BUILD_TAG_DISPLAY.chip_labels(effect_chips, 3):
		tag_parts.append(str(label))
	if not tag_parts.is_empty():
		data["short_tag"] = " / ".join(tag_parts)
	var descriptions := PackedStringArray()
	for detail_line in fit_data.get("detail_lines", PackedStringArray()):
		var fit_line := str(detail_line).strip_edges()
		if fit_line != "":
			descriptions.append(fit_line)
	var chip_labels := BUILD_TAG_DISPLAY.chip_labels(effect_chips, 4)
	if not chip_labels.is_empty():
		descriptions.append(_format_module_chip_summary(effect_chips))
	for description in module_instance.get_effect_descriptions():
		var line := str(description).strip_edges()
		if MODULE_FIT_FORMATTER.filter_effect_description(line):
			descriptions.append(line)
	data["detail_text"] = "\n".join(descriptions)
	module_instance.queue_free()
	return data

func _format_module_chip_summary(effect_chips: Array) -> String:
	var compatibility := PackedStringArray()
	var tags := PackedStringArray()
	for chip in effect_chips:
		var chip_data := chip as Dictionary
		var label := str(chip_data.get("label", "")).strip_edges()
		if label == "":
			continue
		var source_key := str(chip_data.get("source_key", "")).strip_edges()
		if source_key == "projectile" or source_key == "beam" or source_key == "area" or source_key == "melee_contact":
			compatibility.append(label)
		else:
			tags.append(label)
	var lines := PackedStringArray()
	if not tags.is_empty():
		lines.append(LocalizationManager.tr_format(
			"ui.reward.detail.tags",
			{"tags": " / ".join(tags.slice(0, 4))},
			"Tags: %s" % " / ".join(tags.slice(0, 4))
		))
	if not compatibility.is_empty():
		lines.append(LocalizationManager.tr_format(
			"ui.reward.detail.compatible_with",
			{"types": " / ".join(compatibility)},
			"Compatible With: %s" % " / ".join(compatibility)
		))
	return "\n".join(lines)

func _make_reward_icon(card_data: Dictionary) -> Control:
	var fallback_key := str(card_data.get("fallback_icon_key", "reward")).strip_edges()
	var chip := BUILD_TAG_DISPLAY.build_tag_chip(fallback_key)
	var accent: Color = chip.get("color", Color(0.54, 0.64, 0.72, 1.0))
	var root := Control.new()
	root.name = "RewardIcon"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(56.0, 56.0)
	var frame := PanelContainer.new()
	frame.name = "RewardIconFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.custom_minimum_size = Vector2(56.0, 56.0)
	frame.add_theme_stylebox_override("panel", _make_icon_frame_style(accent))
	root.add_child(frame)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	frame.add_child(margin)

	var texture := card_data.get("icon_texture", null) as Texture2D
	if texture != null:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = texture
		margin.add_child(icon)
	else:
		var fallback := Label.new()
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.text = _fallback_icon_text(fallback_key)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 17)
		fallback.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 1.0))
		margin.add_child(fallback)
	var badge_text := str(card_data.get("icon_badge_text", "")).strip_edges()
	if badge_text != "":
		var badge := Label.new()
		badge.name = "RewardIconBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.text = badge_text
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color(0.98, 1.0, 0.96, 1.0))
		badge.add_theme_stylebox_override("normal", _make_icon_badge_style(card_data.get("icon_badge_color", accent) as Color))
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -18.0
		badge.offset_top = -3.0
		badge.offset_right = 3.0
		badge.offset_bottom = 18.0
		root.add_child(badge)
	return root

func _make_icon_frame_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.64)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _make_icon_badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.92)
	style.border_color = Color(0.04, 0.05, 0.06, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func _fallback_icon_text(icon_key: String) -> String:
	match icon_key:
		"weapon":
			return "W"
		"module":
			return "M"
		"terrain":
			return "T"
		"task":
			return "Q"
		"economy":
			return "$"
		_:
			return "R"

func _get_module_texture(module_instance: Module) -> Texture2D:
	if module_instance == null or not is_instance_valid(module_instance):
		return null
	var sprite_node := module_instance.get_node_or_null("%Sprite")
	if sprite_node and sprite_node is Sprite2D:
		return (sprite_node as Sprite2D).texture
	if module_instance.get("sprite") is Sprite2D:
		return (module_instance.get("sprite") as Sprite2D).texture
	return null

func _make_card_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_badge_label(text: String, color: Color) -> Label:
	var label := _make_card_label(text, 10, Color(0.94, 0.98, 1.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size = Vector2(54.0, 22.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.22)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 6
	style.content_margin_right = 6
	label.add_theme_stylebox_override("normal", style)
	return label

func _update_detail_panel(display_data: Dictionary) -> void:
	if detail_title_label == null or detail_body_label == null or detail_outcome_label == null:
		return
	var title := str(display_data.get("title", "")).strip_edges()
	var detail_text := str(display_data.get("detail_text", "")).strip_edges()
	var outcome_text := str(display_data.get("outcome_text", "")).strip_edges()
	var type_label := str(display_data.get("type_label", "")).strip_edges()
	var level_text := str(display_data.get("level_text", "")).strip_edges()
	var meta_line := type_label
	if level_text != "":
		meta_line = "%s · %s" % [type_label, level_text] if type_label != "" else level_text
	var body_lines := PackedStringArray()
	if meta_line != "":
		body_lines.append(meta_line)
	if detail_text != "":
		body_lines.append(detail_text)
	for bullet in display_data.get("detail_bullets", PackedStringArray()):
		var line := str(bullet).strip_edges()
		if line != "":
			body_lines.append("• %s" % line)
	detail_title_label.text = title if title != "" else LocalizationManager.tr_key("ui.reward.detail.title", "Reward Details")
	_update_detail_chip_row(display_data.get("chips", []))
	detail_body_label.text = "\n".join(body_lines) if not body_lines.is_empty() else LocalizationManager.tr_key("ui.reward.detail.empty", "Select a reward to view details.")
	detail_outcome_label.text = outcome_text
	detail_outcome_label.visible = outcome_text != ""

func _update_detail_chip_row(chips: Array) -> void:
	if detail_vbox == null:
		return
	if _detail_chip_row == null or not is_instance_valid(_detail_chip_row):
		_detail_chip_row = BUILD_TAG_DISPLAY.make_chip_row([], 5)
		detail_vbox.add_child(_detail_chip_row)
		if detail_body_label != null:
			detail_vbox.move_child(_detail_chip_row, detail_body_label.get_index())
	BUILD_TAG_DISPLAY.populate_chip_row(_detail_chip_row, chips, 5)

func _append_display_chip(existing: Variant, chip: Dictionary) -> Array:
	var chips: Array = existing if existing is Array else []
	if chip.is_empty():
		return chips
	var source_key := str(chip.get("source_key", "")).strip_edges()
	for existing_chip in chips:
		if str((existing_chip as Dictionary).get("source_key", "")) == source_key:
			return chips
	chips.append(chip)
	return chips

func _first_sentence(text: String, fallback: String) -> String:
	var clean := text.replace("\n", " ").strip_edges()
	if clean == "":
		return fallback
	var dot := clean.find(".")
	if dot >= 0 and dot < clean.length() - 1:
		return clean.substr(0, dot + 1)
	return clean

func _fallback_summary(reward: RewardInfo) -> String:
	if reward == null:
		return ""
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return LocalizationManager.tr_key("ui.reward.summary.weapon_upgrade", "Upgrade equipped weapon level.")
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return LocalizationManager.tr_key("ui.reward.summary.task_module", "Gain a new task module.")
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		return LocalizationManager.tr_key("ui.reward.summary.cell_effect", "Gain a terrain effect.")
	if reward.module_scene:
		return LocalizationManager.tr_key("ui.reward.summary.module", "Gain a new weapon module.")
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		return LocalizationManager.tr_key("ui.reward.summary.weapon", "New weapon added to your loadout.")
	if reward.total_chip_value > 0 or reward.gold_value > 0:
		return LocalizationManager.tr_key("ui.reward.summary.economy", "Gain run resources.")
	return ""

func _derive_level_text(reward: RewardInfo, data: Dictionary) -> String:
	if reward == null:
		return ""
	var short_tag := str(data.get("short_tag", "")).strip_edges()
	if short_tag.begins_with("Lv."):
		return short_tag
	if reward.item_level > 0:
		return "Lv.%d" % int(reward.item_level)
	if reward.module_scene:
		return "Lv.%d" % max(1, reward.module_level)
	return ""

func _fallback_detail_bullets(reward: RewardInfo) -> PackedStringArray:
	if reward == null:
		return PackedStringArray()
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return _localized_reward_bullets("weapon_upgrade", ["Increases weapon level", "Improves the equipped weapon's performance", "Strengthens the current build direction"])
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return _localized_reward_bullets("task_module", ["Adds a task module", "Creates route objective options", "Can improve future rewards"])
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		return _localized_reward_bullets("cell_effect", ["Adds a cell effect", "Changes board options", "Supports route planning"])
	if reward.module_scene:
		return _localized_reward_bullets("module", ["Adds a weapon modifier", "Changes or improves weapon behavior", "Can create build synergy"])
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		return _localized_reward_bullets("weapon", ["Adds a new weapon to your loadout", "Expands build options", "May trigger evolution effects"])
	if reward.total_chip_value > 0 or reward.gold_value > 0:
		return _localized_reward_bullets("economy", ["Adds resources immediately", "Supports current run progression"])
	return PackedStringArray()

func _localized_reward_bullets(category: String, fallbacks: Array) -> PackedStringArray:
	var output := PackedStringArray()
	for index in range(fallbacks.size()):
		output.append(LocalizationManager.tr_key(
			"ui.reward.detail.bullet.%s.%d" % [category, index + 1],
			str(fallbacks[index])
		))
	return output

func _apply_reward_card_style(button: Button, reward: RewardInfo, selected: bool) -> void:
	if button == null or reward == null:
		return
	var action_color := _get_reward_action_color(reward)
	var recommended_fuse := _is_recommended_fuse_reward(reward)
	var selected_badge := button.find_child("SelectedBadge", true, false) as Control
	if selected_badge != null:
		selected_badge.visible = selected
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.10)
		if recommended_fuse:
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.20)
		if selected:
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.30)
		elif state == "hover" or state == "focus":
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.14)
		elif state == "pressed":
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.16)
		if recommended_fuse and (state == "hover" or state == "focus"):
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.24)
		elif recommended_fuse and state == "pressed":
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.26)
		if recommended_fuse and selected:
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.28)
		style.border_color = Color(action_color.r, action_color.g, action_color.b, 1.0 if selected else 0.78)
		style.set_border_width_all(3 if selected or recommended_fuse else 1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, style)

func _apply_action_button_style(button: Button, primary: bool) -> void:
	var color := Color(0.42, 0.78, 0.92, 1.0) if primary else Color(0.56, 0.64, 0.70, 1.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		var state_color := color
		style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.15 if primary else 0.10)
		if state == "hover" or state == "focus":
			style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.22 if primary else 0.16)
		elif state == "pressed":
			style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.28 if primary else 0.20)
		elif state == "disabled":
			state_color = Color(0.40, 0.46, 0.50, 1.0)
			style.bg_color = Color(0.10, 0.12, 0.14, 0.64)
		style.border_color = Color(state_color.r, state_color.g, state_color.b, 0.78)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, Color(0.94, 0.98, 1.0, 1.0))

func _get_reward_action_color(reward: RewardInfo) -> Color:
	if reward == null:
		return Color(0.54, 0.64, 0.72, 1.0)
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return Color(0.36, 0.62, 0.95, 1.0)
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var outcome := _get_weapon_obtain_prediction(reward.item_id)
		var result_type := str(outcome.get("result", "not_applicable"))
		if result_type == "fused":
			return Color(0.94, 0.68, 0.24, 1.0)
		if result_type == "converted_to_gold":
			return Color(0.93, 0.72, 0.22, 1.0)
		return Color(0.42, 0.78, 0.48, 1.0)
	return RARITY_UTIL.get_color(reward.get_rarity())

func _is_recommended_fuse_reward(reward: RewardInfo) -> bool:
	if reward == null:
		return false
	if reward.item_id.strip_edges() == "" or reward.item_level <= 0:
		return false
	var outcome := _get_weapon_obtain_prediction(reward.item_id)
	return str(outcome.get("result", "not_applicable")) == "fused"

func _set_mouse_filter_recursive(root: Control, mouse_filter_value: Control.MouseFilter) -> void:
	for child in root.get_children():
		var control := child as Control
		if control == null:
			continue
		control.mouse_filter = mouse_filter_value
		_set_mouse_filter_recursive(control, mouse_filter_value)

func _extract_scene_name(scene_path: String) -> String:
	if scene_path == "":
		return LocalizationManager.tr_key("ui.common.unknown", "Unknown")
	var file_name := scene_path.get_file().get_basename()
	if file_name == "":
		return LocalizationManager.tr_key("ui.common.unknown", "Unknown")
	return file_name.replace("_", " ").capitalize()

func _get_weapon_obtain_prediction(weapon_id: String) -> Dictionary:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return {}
	if not PlayerData.player.has_method("predict_auto_fuse_weapon_obtain"):
		return {}
	return PlayerData.player.predict_auto_fuse_weapon_obtain(weapon_id)

func _with_new_weapon_destination_prediction(outcome: Dictionary) -> Dictionary:
	var next_outcome := outcome.duplicate(true)
	if PlayerData == null:
		return next_outcome
	var equipped_count := int(PlayerData.player_weapon_list.size())
	var max_count := maxi(1, int(PlayerData.max_weapon_num))
	next_outcome["will_equip_to_empty_slot"] = equipped_count < max_count
	next_outcome["will_choose_replacement"] = equipped_count >= max_count
	return next_outcome

func _format_weapon_obtain_prediction(base_text: String, weapon_name: String, outcome: Dictionary) -> String:
	return PREVIEW_FORMATTER.format_obtain_preview(base_text, weapon_name, outcome)

func _on_language_changed(_locale: String) -> void:
	if not visible:
		return
	var rewards := _reward_options.duplicate()
	var on_confirm := _on_confirm
	var on_cancel := _on_cancel
	var summary_mode := _summary_mode
	var route_name := _route_display_name_cache
	var allow_cancel := _allow_cancel
	var title_override := _title_override_cache
	var subtitle_override := _subtitle_override_cache
	var progress_index := _progress_index_cache
	var progress_total := _progress_total_cache
	var show_draft_hint := _show_draft_hint_cache
	visible = false
	if summary_mode:
		open_for_summary(rewards, on_confirm, title_override, subtitle_override)
	else:
		open_for_rewards(
			route_name,
			rewards,
			on_confirm,
			on_cancel,
			allow_cancel,
			title_override,
			subtitle_override,
			progress_index,
			progress_total,
			show_draft_hint
		)
