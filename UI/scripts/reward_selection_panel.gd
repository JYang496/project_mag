extends Control
class_name RewardSelectionPanel

signal reward_confirmed(reward: RewardInfo)
signal selection_cancelled

const RARITY_UTIL := preload("res://data/LootRarity.gd")
const PREVIEW_FORMATTER := preload("res://UI/scripts/weapon_obtain_preview_formatter.gd")
const MODULE_FIT_FORMATTER := preload("res://UI/scripts/module_fit_formatter.gd")
const BUILD_TAG_DISPLAY := preload("res://UI/scripts/build_tag_display.gd")
const WEAPON_DISPLAY_BUILDER := preload("res://UI/scripts/presentation/weapon_display_model_builder.gd")
const WEAPON_DISPLAY_POLICY := preload("res://UI/scripts/presentation/weapon_display_policy.gd")
const WEAPON_STAT_FORMATTER := preload("res://UI/scripts/presentation/weapon_stat_formatter.gd")
const REWARD_CARD_MODEL_BUILDER := preload("res://UI/scripts/presentation/reward_card_model_builder.gd")
const REWARD_CARD_DATA_ASSEMBLER := preload("res://UI/scripts/presentation/reward_card_data_assembler.gd")
const QUICK_SELECT_HOLD_SECONDS := 0.55
const CARD_FONT_SIZE_BONUS := 1
const CARD_LINE_SPACING := -2
const CARD_BODY_SEPARATION := 4

@onready var title_label: Label = $Panel/VBox/Title
@onready var panel: Panel = $Panel
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_scroll: ScrollContainer = $Panel/VBox/OptionsScroll
@onready var options_box: GridContainer = $Panel/VBox/OptionsScroll/Options
@onready var confirm_button: Button = $Panel/VBox/ActionPanel/Margin/Actions/ConfirmButton
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
var _summary_mode := false
var _show_draft_hint_cache := false
var _pinned_index := 0
var _hover_index := -1
var _focus_index := -1
var _entry_tween: Tween
var _held_quick_select_index := -1
var _held_quick_select_elapsed := 0.0
var _synergy_evaluator: Callable = Callable()
var _reward_data_assembler: RefCounted
var _cropped_reward_textures: Dictionary = {}

func set_synergy_evaluator(evaluator: Callable) -> void:
	_synergy_evaluator = evaluator

func _get_reward_data_assembler():
	if _reward_data_assembler == null:
		_reward_data_assembler = REWARD_CARD_DATA_ASSEMBLER.new(self)
	return _reward_data_assembler

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
	if not _summary_mode and event is InputEventKey and not event.echo:
		var index := _quick_select_index_for_key(event.keycode)
		if index >= 0:
			if event.pressed:
				_begin_quick_select_hold(index)
			elif index == _held_quick_select_index:
				_cancel_quick_select_hold()
			get_viewport().set_input_as_handled()
			return
	if not ModalUiController.is_cancel_input(event):
		return
	cancel_visible_modal()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _held_quick_select_index < 0 or not is_modal_open():
		return
	_held_quick_select_elapsed += maxf(delta, 0.0)
	_update_quick_select_hold_visual()
	if _held_quick_select_elapsed < QUICK_SELECT_HOLD_SECONDS:
		return
	var index := _held_quick_select_index
	_cancel_quick_select_hold()
	if index == _selected_index:
		_on_confirm_pressed()

func _quick_select_index_for_key(keycode: Key) -> int:
	match keycode:
		KEY_1, KEY_KP_1: return 0
		KEY_2, KEY_KP_2: return 1
		KEY_3, KEY_KP_3: return 2
	return -1

func _begin_quick_select_hold(index: int) -> void:
	if index < 0 or index >= _reward_options.size() or index >= options_box.get_child_count():
		_cancel_quick_select_hold()
		return
	if _held_quick_select_index == index:
		return
	if _held_quick_select_index >= 0:
		_cancel_quick_select_hold()
	_held_quick_select_index = index
	_held_quick_select_elapsed = 0.0
	_on_reward_button_pressed(index, options_box.get_child(index) as Button)
	_update_quick_select_hold_visual()

func _cancel_quick_select_hold() -> void:
	var previous_index := _held_quick_select_index
	_held_quick_select_index = -1
	_held_quick_select_elapsed = 0.0
	if previous_index >= 0 and previous_index < options_box.get_child_count():
		var button := options_box.get_child(previous_index) as Button
		var progress := button.find_child("HoldProgress", true, false) as ProgressBar if button != null else null
		if progress != null:
			progress.value = 0.0
			progress.visible = false
		if previous_index < _reward_options.size():
			_apply_reward_card_style(button, _reward_options[previous_index], previous_index == _selected_index)
	_confirm_button_state()

func _update_quick_select_hold_visual() -> void:
	if _held_quick_select_index < 0 or _held_quick_select_index >= options_box.get_child_count():
		return
	var button := options_box.get_child(_held_quick_select_index) as Button
	if button == null:
		return
	var progress := button.find_child("HoldProgress", true, false) as ProgressBar
	if progress != null:
		progress.visible = true
		progress.value = clampf(_held_quick_select_elapsed / QUICK_SELECT_HOLD_SECONDS, 0.0, 1.0)
	_apply_reward_card_style(button, _reward_options[_held_quick_select_index], true, true)
	_confirm_button_state()

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
	_apply_unified_layout()
	confirm_button.text = _get_confirm_button_text()
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	cancel_button.visible = _allow_cancel and not _summary_mode
	cancel_button.disabled = not _allow_cancel or _summary_mode
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
		var button := _build_reward_card_button(_reward_options[idx], idx)
		button.pressed.connect(Callable(self, "_on_reward_button_pressed").bind(idx, button))
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

func _apply_unified_layout() -> void:
	panel.offset_left = -500.0
	panel.offset_top = -310.0
	panel.offset_right = 500.0
	panel.offset_bottom = 310.0
	options_scroll.custom_minimum_size.y = 410.0
	var footer := get_node_or_null("Panel/VBox/Footer") as Control
	if footer != null:
		footer.visible = _allow_cancel and not _summary_mode

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
	_cancel_quick_select_hold()
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

func _update_grid_columns() -> void:
	if options_box == null or options_scroll == null:
		return
	var option_count := maxi(1, options_box.get_child_count())
	options_box.columns = mini(3, option_count)

func _confirm_button_state() -> void:
	confirm_button.disabled = false if _summary_mode else _selected_index < 0 or _selected_index >= _reward_options.size()
	confirm_button.text = _get_confirm_button_text()

func _get_confirm_button_text() -> String:
	if _summary_mode:
		return LocalizationManager.tr_key("ui.task_reward.summary_confirm", "Continue")
	if _selected_index < 0 or _selected_index >= _reward_options.size():
		return LocalizationManager.tr_key("ui.reward.select_prompt", "Select a reward")
	if _held_quick_select_index >= 0:
		return LocalizationManager.tr_format(
			"ui.reward.quick.holding",
			{"progress": int(round(100.0 * clampf(_held_quick_select_elapsed / QUICK_SELECT_HOLD_SECONDS, 0.0, 1.0)))},
			"Holding %d%%" % int(round(100.0 * clampf(_held_quick_select_elapsed / QUICK_SELECT_HOLD_SECONDS, 0.0, 1.0)))
		)
	var confirm_text := LocalizationManager.tr_key("ui.reward.confirm", "Confirm Reward")
	return confirm_text

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

func _build_reward_card_button(reward: RewardInfo, reward_index: int = -1) -> Button:
	var card_data: Dictionary = _build_reward_card_model(reward).to_display_data()
	var is_module_reward := card_data.has("compatible_weapons")
	var detail_variant := StringName(card_data.get("detail_variant", &"generic"))
	var is_weapon_visual_reward := detail_variant in [&"new_weapon", &"weapon_fusion", &"weapon_upgrade"]
	var button := Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 372 if is_module_reward else 296)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.text = ""
	var full_detail := str(card_data.get("detail_text", "")).strip_edges()
	button.tooltip_text = "%s\n%s" % [str(card_data.get("title", "Reward")), full_detail] if full_detail != "" else str(card_data.get("title", "Reward"))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	button.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", CARD_BODY_SEPARATION)
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
	if not _summary_mode and reward_index >= 0 and reward_index < 3:
		var key_badge := _make_badge_label(str(reward_index + 1), Color(0.40, 0.78, 0.94, 1.0))
		key_badge.name = "KeyBadge"
		key_badge.custom_minimum_size.x = 28.0
		top_row.add_child(key_badge)

	var type_badge := _make_badge_label(str(card_data.get("type_label", "Reward")).to_upper(), Color(0.58, 0.76, 0.92, 1.0))
	type_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(type_badge)

	var selected_badge := _make_badge_label(LocalizationManager.tr_key("ui.reward.selected", "SELECTED"), _get_reward_action_color(reward))
	selected_badge.name = "SelectedBadge"
	selected_badge.visible = false
	top_row.add_child(selected_badge)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	if is_weapon_visual_reward:
		body.add_child(_build_weapon_reward_hero(card_data))
		body.add_child(text_box)
	else:
		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_theme_constant_override("separation", 10)
		body.add_child(header)
		header.add_child(_make_reward_icon(card_data))
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
	name_label.custom_minimum_size = Vector2(0.0, 24.0 if is_weapon_visual_reward else 38.0)
	if is_weapon_visual_reward:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(name_label)

	var meta_text := str(card_data.get("meta_text", "")).strip_edges()
	var level_text := str(card_data.get("level_text", "")).strip_edges()
	var meta_label := _make_card_label(level_text if level_text != "" else meta_text, 14, Color(0.78, 0.87, 0.91, 1.0))
	meta_label.clip_text = true
	if is_weapon_visual_reward:
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(meta_label)

	var summary_parent: VBoxContainer = body
	if is_module_reward:
		var effect_box := VBoxContainer.new()
		effect_box.name = "ModuleEffectBox"
		effect_box.add_theme_constant_override("separation", 3)
		body.add_child(effect_box)
		var effect_heading := _make_card_label(LocalizationManager.tr_key("ui.reward.module_effect", "Module Effect"), 13, Color(0.58, 0.82, 0.94, 1.0))
		effect_heading.name = "ModuleEffectHeading"
		effect_box.add_child(effect_heading)
		summary_parent = effect_box
	var summary_label := _make_card_label(str(card_data.get("summary_text", "")).strip_edges(), 14, Color(0.84, 0.91, 0.94, 1.0))
	summary_label.name = "BehaviorSummary"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.max_lines_visible = 2
	summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary_label.custom_minimum_size = Vector2(0.0, 34.0)
	summary_label.tooltip_text = full_detail
	summary_parent.add_child(summary_label)

	var feature_lines: PackedStringArray = card_data.get("feature_lines", PackedStringArray())
	if not feature_lines.is_empty():
		var feature_box := VBoxContainer.new()
		feature_box.name = "FeatureList"
		feature_box.custom_minimum_size.y = 46.0
		feature_box.add_theme_constant_override("separation", 2)
		summary_parent.add_child(feature_box)
		for feature in feature_lines.slice(0, 2):
			var feature_label := _make_card_label("• %s" % str(feature).strip_edges(), 13, Color(0.70, 0.80, 0.84, 1.0))
			feature_label.name = "FeatureLine"
			_configure_two_line_summary(feature_label)
			feature_label.tooltip_text = str(feature)
			feature_box.add_child(feature_label)

	if is_module_reward:
		body.add_child(_build_module_weapon_grid(card_data))
	else:
		var comparison_lines := _card_comparison_lines(card_data)
		var comparison_box := VBoxContainer.new()
		comparison_box.name = "ComparisonBox"
		comparison_box.custom_minimum_size.y = 82.0
		comparison_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		comparison_box.alignment = BoxContainer.ALIGNMENT_CENTER
		comparison_box.add_theme_constant_override("separation", 3)
		body.add_child(comparison_box)
		for comparison_line in comparison_lines:
			var comparison_label := _make_card_label(str(comparison_line), 14, Color(0.76, 0.93, 0.82, 1.0))
			comparison_label.name = "ComparisonLine"
			_configure_two_line_summary(comparison_label)
			comparison_label.tooltip_text = str(comparison_line)
			comparison_box.add_child(comparison_label)

	var tag_text := str(card_data.get("short_tag", "")).strip_edges()
	var chips: Array = card_data.get("chips", [])
	if not chips.is_empty():
		var chip_row := BUILD_TAG_DISPLAY.make_chip_row(chips, 3)
		body.add_child(chip_row)
	elif tag_text != "" and detail_variant != &"weapon_upgrade":
		var tag_label := _make_card_label(tag_text, 14, Color(0.82, 0.90, 0.95, 1.0))
		tag_label.name = "ShortTagLabel"
		tag_label.clip_text = true
		body.add_child(tag_label)

	var synergy_text := str(card_data.get("synergy_label", "")).strip_edges()
	if synergy_text != "":
		var synergy_label := _make_card_label(synergy_text, 13, _synergy_status_color(StringName(card_data.get("synergy_status", &"neutral"))))
		synergy_label.name = "SynergyStatusLabel"
		synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		synergy_label.max_lines_visible = 2
		synergy_label.tooltip_text = str(card_data.get("synergy_reason", ""))
		body.add_child(synergy_label)

	var hold_progress := ProgressBar.new()
	hold_progress.name = "HoldProgress"
	hold_progress.max_value = 1.0
	hold_progress.value = 0.0
	hold_progress.show_percentage = false
	hold_progress.custom_minimum_size = Vector2(0.0, 5.0)
	hold_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold_progress.visible = false
	var progress_background := StyleBoxFlat.new()
	progress_background.bg_color = Color(0.06, 0.10, 0.12, 0.92)
	progress_background.set_corner_radius_all(2)
	var progress_fill := StyleBoxFlat.new()
	var action_color := _get_reward_action_color(reward)
	progress_fill.bg_color = Color(action_color.r, action_color.g, action_color.b, 1.0)
	progress_fill.set_corner_radius_all(2)
	hold_progress.add_theme_stylebox_override("background", progress_background)
	hold_progress.add_theme_stylebox_override("fill", progress_fill)
	body.add_child(hold_progress)

	_set_mouse_filter_recursive(button, Control.MOUSE_FILTER_IGNORE)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_reward_card_style(button, reward, false)
	return button

func _build_weapon_reward_hero(card_data: Dictionary) -> CenterContainer:
	var hero := CenterContainer.new()
	hero.name = "WeaponRewardHero"
	hero.custom_minimum_size = Vector2(0.0, 104.0)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _make_reward_icon(card_data, Vector2(144.0, 94.0), 8)
	icon.name = "WeaponHeroImage"
	hero.add_child(icon)
	return hero

func _build_module_weapon_grid(card_data: Dictionary) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "CompatibleWeaponsSection"
	section.custom_minimum_size.y = 120.0
	section.add_theme_constant_override("separation", 5)
	var previews: Array = card_data.get("compatible_weapons", [])
	var owned_count := int(card_data.get("owned_weapon_count", 0))
	var heading_row := HBoxContainer.new()
	section.add_child(heading_row)
	var heading := _make_card_label(LocalizationManager.tr_key("ui.reward.compatible_weapons", "Compatible Weapons"), 13, Color(0.58, 0.82, 0.94, 1.0))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	var count_label := _make_card_label("%d/%d" % [previews.size(), owned_count], 13, Color(0.72, 0.84, 0.88, 1.0))
	count_label.name = "CompatibleWeaponCount"
	heading_row.add_child(count_label)
	if previews.is_empty():
		var empty_label := _make_card_label(LocalizationManager.tr_key("ui.reward.no_compatible_weapons", "No owned weapon can equip this module"), 13, Color(0.92, 0.52, 0.48, 1.0))
		empty_label.name = "NoCompatibleWeapons"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(empty_label)
		return section
	var grid := GridContainer.new()
	grid.name = "CompatibleWeaponsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	section.add_child(grid)
	for preview_variant in previews.slice(0, 4):
		grid.add_child(_build_module_weapon_tile(preview_variant as Dictionary))
	return section

func _build_module_weapon_tile(preview: Dictionary) -> PanelContainer:
	var requires_replace := bool(preview.get("requires_replace", false))
	var state_color := Color(0.95, 0.74, 0.30, 1.0) if requires_replace else Color(0.40, 0.86, 0.57, 1.0)
	var tile := PanelContainer.new()
	tile.name = "CompatibleWeaponTile"
	tile.custom_minimum_size = Vector2(0.0, 50.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(state_color.r, state_color.g, state_color.b, 0.08)
	style.border_color = Color(state_color.r, state_color.g, state_color.b, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 5
	style.content_margin_top = 4
	style.content_margin_right = 5
	style.content_margin_bottom = 4
	tile.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tile.add_child(row)
	var icon := TextureRect.new()
	icon.name = "WeaponIcon"
	icon.custom_minimum_size = Vector2(38.0, 38.0)
	icon.texture = preview.get("icon_texture", null) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	var weapon_name := str(preview.get("name", "Weapon"))
	var name_label := _make_card_label(weapon_name, 13, Color(0.90, 0.95, 0.97, 1.0))
	name_label.name = "WeaponName"
	name_label.clip_text = true
	name_label.tooltip_text = weapon_name
	text_box.add_child(name_label)
	var status_text := LocalizationManager.tr_key("ui.reward.weapon_requires_replace", "Requires replacement") if requires_replace else LocalizationManager.tr_key("ui.reward.weapon_has_slot", "Slot available")
	var status_label := _make_card_label(("↻ " if requires_replace else "✓ ") + status_text, 11, state_color)
	status_label.name = "WeaponFitStatus"
	status_label.clip_text = true
	text_box.add_child(status_label)
	return tile

func _card_comparison_lines(card_data: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for value in card_data.get("comparison_lines", PackedStringArray()):
		var line := str(value).strip_edges()
		if line != "":
			lines.append(line)
		if lines.size() >= 3:
			return lines
	if StringName(card_data.get("detail_variant", &"generic")) == &"weapon_upgrade":
		return lines
	var candidates: Array[Dictionary] = [
		{"heading": LocalizationManager.tr_key("ui.reward.detail.section.combat_profile", "Combat Profile"), "value": card_data.get("detail_role", "")},
		{"heading": LocalizationManager.tr_key("ui.reward.detail.section.main_effect", "Main Effect"), "value": card_data.get("detail_effect", "")},
		{"heading": LocalizationManager.tr_key("ui.reward.detail.section.result_preview", "Result Preview"), "value": card_data.get("outcome_text", "")},
	]
	for candidate in candidates:
		if lines.size() >= 3:
			break
		var value := _compact_detail_text(str(candidate.get("value", "")), 46)
		if value == "" or _line_collection_contains(lines, value):
			continue
		lines.append("%s  %s" % [str(candidate.get("heading", "")), value])
	if lines.size() < 2:
		for value in card_data.get("detail_bullets", PackedStringArray()):
			var line := _compact_detail_text(str(value), 46)
			if line != "" and not _line_collection_contains(lines, line):
				lines.append("• %s" % line)
			if lines.size() >= 2:
				break
	return lines

func _line_collection_contains(lines: PackedStringArray, value: String) -> bool:
	for line in lines:
		if str(line).contains(value) or value.contains(str(line)):
			return true
	return false

func _build_reward_card_model(reward: RewardInfo):
	var synergy_result: Dictionary = {}
	if _synergy_evaluator.is_valid():
		var evaluated: Variant = _synergy_evaluator.call(reward)
		if evaluated is Dictionary: synergy_result = evaluated
	elif reward != null and reward.has_meta("synergy_evaluation"):
		var metadata: Variant = reward.get_meta("synergy_evaluation")
		if metadata is Dictionary: synergy_result = metadata
	return REWARD_CARD_MODEL_BUILDER.build(_build_reward_display_data(reward), synergy_result)

func _synergy_status_color(status: StringName) -> Color:
	match status:
		&"direct_fit", &"unlocks_chain": return Color(0.48, 0.90, 0.64, 1.0)
		&"partial_fit": return Color(0.94, 0.78, 0.36, 1.0)
		&"blocked", &"conflict": return Color(1.0, 0.56, 0.48, 1.0)
		_: return Color(0.72, 0.80, 0.86, 1.0)

func _build_reward_card_data(reward: RewardInfo) -> Dictionary:
	return _get_reward_data_assembler()._build_reward_card_data(reward)

func _build_reward_display_data(reward: RewardInfo) -> Dictionary:
	return _get_reward_data_assembler()._build_reward_display_data(reward)

func _make_reward_icon(card_data: Dictionary, minimum_size: Vector2 = Vector2(56.0, 56.0), content_margin: int = 6) -> Control:
	var fallback_key := str(card_data.get("fallback_icon_key", "reward")).strip_edges()
	var chip := BUILD_TAG_DISPLAY.build_tag_chip(fallback_key)
	var accent: Color = chip.get("color", Color(0.54, 0.64, 0.72, 1.0))
	var root := Control.new()
	root.name = "RewardIcon"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = minimum_size
	var frame := PanelContainer.new()
	frame.name = "RewardIconFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.custom_minimum_size = minimum_size
	frame.add_theme_stylebox_override("panel", _make_icon_frame_style(accent))
	root.add_child(frame)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", content_margin)
	margin.add_theme_constant_override("margin_top", content_margin)
	margin.add_theme_constant_override("margin_right", content_margin)
	margin.add_theme_constant_override("margin_bottom", content_margin)
	frame.add_child(margin)

	var texture := card_data.get("icon_texture", null) as Texture2D
	if texture != null:
		if fallback_key == "weapon":
			texture = _crop_reward_texture_to_content(texture)
		var icon := TextureRect.new()
		icon.name = "RewardIconTexture"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

func _crop_reward_texture_to_content(source: Texture2D) -> Texture2D:
	if source == null:
		return source
	var cache_key := source.get_rid()
	if _cropped_reward_textures.has(cache_key):
		return _cropped_reward_textures[cache_key] as Texture2D
	var image := source.get_image()
	if image == null or image.is_empty():
		_cropped_reward_textures[cache_key] = source
		return source
	var used_rect := image.get_used_rect()
	if not used_rect.has_area():
		_cropped_reward_textures[cache_key] = source
		return source
	var texture_rect := Rect2i(Vector2i.ZERO, image.get_size())
	var padded_rect := used_rect.grow(2).intersection(texture_rect)
	if padded_rect == texture_rect:
		_cropped_reward_textures[cache_key] = source
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(padded_rect)
	_cropped_reward_textures[cache_key] = atlas
	return atlas

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
	label.add_theme_font_size_override("font_size", font_size + CARD_FONT_SIZE_BONUS)
	label.add_theme_constant_override("line_spacing", CARD_LINE_SPACING)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _configure_two_line_summary(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.y = 34.0

func _make_badge_label(text: String, color: Color) -> Label:
	var label := _make_card_label(text, 14, Color(0.94, 0.98, 1.0, 1.0))
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

func _compact_detail_text(text: String, max_characters: int) -> String:
	var compact := text.replace("\r", " ").replace("\n", " ").replace("  ", " ").strip_edges()
	if compact.length() <= max_characters:
		return compact
	return compact.left(maxi(1, max_characters - 1)).strip_edges() + "…"

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
	var sentence_end := -1
	for delimiter in ["。", ".", "！", "!", "？", "?"]:
		var found := clean.find(delimiter)
		if found >= 0 and (sentence_end < 0 or found < sentence_end):
			sentence_end = found
	if sentence_end >= 0:
		return clean.substr(0, sentence_end + 1)
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
		return PackedStringArray()
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return _localized_reward_bullets("task_module", ["Adds a task module", "Creates route objective options", "Can improve future rewards"])
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		return _localized_reward_bullets("cell_effect", ["Adds a cell effect", "Changes board options", "Supports route planning"])
	if reward.module_scene:
		return _localized_reward_bullets("module", ["Adds a weapon modifier", "Changes or improves weapon behavior", "Can create build synergy"])
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		return PackedStringArray()
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

func _apply_reward_card_style(button: Button, reward: RewardInfo, selected: bool, holding: bool = false) -> void:
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
		if holding:
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.28)
		elif selected:
			style.bg_color = Color(action_color.r, action_color.g, action_color.b, 0.18)
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
		style.border_color = Color(action_color.r, action_color.g, action_color.b, 1.0 if selected or holding else 0.78)
		style.set_border_width_all(3 if holding else (2 if selected or recommended_fuse else 1))
		if selected and not holding:
			style.shadow_color = Color(action_color.r, action_color.g, action_color.b, 0.34)
			style.shadow_size = 5
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
