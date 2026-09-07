extends Control

const REWARD_ICON_SCENE := preload("res://UI/components/RewardIcon/RewardIcon.tscn")
const REWARD_CARD_SCENE := preload("res://UI/components/RewardCard/RewardCard.tscn")
const WEAPON_CORE_CONTENT_SCENE := preload("res://UI/components/WeaponCoreRewardContent/WeaponCoreRewardContent.tscn")
const CORE_WEAPON_STATS_SCENE := preload("res://UI/components/CoreWeaponStats/CoreWeaponStats.tscn")
const DAMAGE_TYPE_ICON_ROW_SCENE := preload("res://UI/components/DamageTypeIconRow/DamageTypeIconRow.tscn")
const BRANCH_FUSION_RECIPE_SCENE := preload("res://UI/components/BranchFusionRecipe/BranchFusionRecipe.tscn")
const WEAPON_BRANCH_PREVIEW_SECTION_SCENE := preload("res://UI/components/WeaponBranchPreviewSection/WeaponBranchPreviewSection.tscn")
const BRANCH_PREVIEW_CARD_SCENE := preload("res://UI/components/BranchPreviewCard/BranchPreviewCard.tscn")
const WEAPON_BRANCH_DETAIL_OVERLAY_SCENE := preload("res://UI/components/WeaponBranchDetailOverlay/WeaponBranchDetailOverlay.tscn")
const BRANCH_DETAIL_CARD_SCENE := preload("res://UI/components/BranchDetailCard/BranchDetailCard.tscn")
const MODULE_FIT_SECTION_SCENE := preload("res://UI/components/ModuleFitSection/ModuleFitSection.tscn")
const MODULE_FIT_WEAPON_TILE_SCENE := preload("res://UI/components/ModuleFitWeaponTile/ModuleFitWeaponTile.tscn")
const REWARD_CARD_LABEL_SCENE := preload("res://UI/components/RewardCardLabel/RewardCardLabel.tscn")
const MODULE_EFFECT_SUMMARY_SCENE := preload("res://UI/components/ModuleEffectSummary/ModuleEffectSummary.tscn")
const REWARD_PROMPT_TEXT_SCENE := preload("res://UI/components/RewardPromptText/RewardPromptText.tscn")
const INPUT_PROMPT_ICON_SCENE := preload("res://UI/components/InputPromptIcon/InputPromptIcon.tscn")
const INPUT_PROMPT_GROUP_SCENE := preload("res://UI/components/InputPromptGroup/InputPromptGroup.tscn")
const REWARD_TEXT_COLUMN_SCENE := preload("res://UI/components/RewardTextColumn/RewardTextColumn.tscn")
const REWARD_HEADER_SCENE := preload("res://UI/components/RewardHeader/RewardHeader.tscn")
const REWARD_CHIP_ROW_SCENE := preload("res://UI/components/RewardChipRow/RewardChipRow.tscn")
const WEAPON_DESCRIPTION_SECTION_SCENE := preload("res://UI/components/WeaponDescriptionSection/WeaponDescriptionSection.tscn")
const MODULE_EFFECT_SECTION_SCENE := preload("res://UI/components/ModuleEffectSection/ModuleEffectSection.tscn")
const REWARD_FEATURE_LIST_SCENE := preload("res://UI/components/RewardFeatureList/RewardFeatureList.tscn")
const REWARD_COMPARISON_BOX_SCENE := preload("res://UI/components/RewardComparisonBox/RewardComparisonBox.tscn")
const WEAPON_REWARD_HERO_SCENE := preload("res://UI/components/WeaponRewardHero/WeaponRewardHero.tscn")

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
const WEAPON_PREVIEW_DATA := preload("res://UI/scripts/presentation/reward_weapon_preview_data.gd")
const DAMAGE_TYPE_ICONS := {
	&"physical": preload("res://UI/themes/pixel/generated/damage_types/damage_physical_compact.png"),
	&"energy": preload("res://UI/themes/pixel/generated/damage_types/damage_energy.png"),
	&"fire": preload("res://UI/themes/pixel/generated/damage_types/damage_fire.png"),
	&"freeze": preload("res://UI/themes/pixel/generated/damage_types/damage_freeze.png"),
}
const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const INPUT_PROMPT_ATLAS := preload("res://asset/images/ui/input_prompts/kenney_pixel/input_prompts_tilemap.png")
const INPUT_PROMPT_TEXTURE_FACTORY := preload("res://UI/scripts/components/input_prompt_texture_factory.gd")
const INPUT_PROMPT_TILE_SIZE := 16
const INPUT_PROMPT_TILE_STRIDE := 17
const INPUT_PROMPT_DISPLAY_SIZE := 32.0
const SPACE_PROMPT_DISPLAY_WIDTH := 72
const QUICK_SELECT_HOLD_SECONDS := 0.55
const DETAIL_HOVER_OPEN_SECONDS := 0.25
const DETAIL_HOVER_CLOSE_SECONDS := 0.15
const CARD_FONT_SIZE_BONUS := 0
const CARD_LINE_SPACING := -2
const CARD_BODY_SEPARATION := 4
const STANDARD_CARD_MIN_HEIGHT := 372.0
const DETAILED_CARD_MIN_HEIGHT := 380.0
const CARD_SELECTION_PULSE_SCALE := Vector2(1.012, 1.012)
const CORE_MATERIAL_COLOR := Color(0.94, 0.58, 0.18, 1.0)
const CORE_MATERIAL_SURFACE := Color(0.16, 0.105, 0.045, 1.0)

@onready var title_label: Label = $Panel/VBox/Title
@onready var panel: Panel = $Panel
@onready var subtitle_label: Label = $Panel/VBox/SubTitle
@onready var options_scroll: ScrollContainer = $Panel/VBox/OptionsScroll
@onready var options_box: GridContainer = $Panel/VBox/OptionsScroll/Options
@onready var confirm_button: Button = $Panel/VBox/ActionPanel/Margin/Actions/ConfirmButton
@onready var cancel_button: Button = $Panel/VBox/ActionPanel/Margin/Actions/CancelButton
@onready var detail_hint: HBoxContainer = $Panel/VBox/ActionPanel/Margin/Actions/DetailHint

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
var _detail_open_index := -1
var _pending_detail_index := -1
var _mouse_detail_index := -1
@onready var _detail_open_timer: Timer = $DetailOpenTimer
@onready var _detail_close_timer: Timer = $DetailCloseTimer
var _using_gamepad := false
var _gamepad_device_id := 0

func set_synergy_evaluator(evaluator: Callable) -> void:
	_synergy_evaluator = evaluator

func _get_reward_data_assembler():
	if _reward_data_assembler == null:
		_reward_data_assembler = REWARD_CARD_DATA_ASSEMBLER.new()
	return _reward_data_assembler

func _ready() -> void:
	visible = false
	if not confirm_button.is_connected("pressed", Callable(self, "_on_confirm_pressed")):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not cancel_button.is_connected("pressed", Callable(self, "_on_cancel_pressed")):
		cancel_button.pressed.connect(_on_cancel_pressed)
	_apply_action_button_style(confirm_button, true)
	_apply_action_button_style(cancel_button, false)
	_apply_panel_style()
	if not LocalizationManager.is_connected("language_changed", Callable(self, "_on_language_changed")):
		LocalizationManager.language_changed.connect(_on_language_changed)
	if not options_scroll.resized.is_connected(_update_grid_columns):
		options_scroll.resized.connect(_update_grid_columns)
	_detail_open_timer.timeout.connect(_on_detail_open_timeout)
	_detail_close_timer.timeout.connect(_on_detail_close_timeout)

func _exit_tree() -> void:
	_set_battle_hud_suppressed(false)

func _input(event: InputEvent) -> void:
	if not is_modal_open():
		return
	_update_input_device(event)
	if _is_detail_input(event):
		if event.is_pressed() and not event.is_echo():
			_toggle_focused_weapon_detail()
		get_viewport().set_input_as_handled()
		return
	if _detail_open_index >= 0 and ModalUiController.is_cancel_input(event):
		_close_weapon_detail()
		get_viewport().set_input_as_handled()
		return
	if _is_space_key_event(event):
		if event.is_pressed() and not event.is_echo():
			_activate_or_focus_confirm_button()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()
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
	if _is_navigation_input(event):
		_navigate_focus(event)
		get_viewport().set_input_as_handled()
		return
	if not ModalUiController.is_cancel_input(event):
		return
	cancel_visible_modal()
	get_viewport().set_input_as_handled()

func _is_detail_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	return false

func _is_navigation_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	return event.is_action_pressed("UP") or event.is_action_pressed("DOWN") \
			or event.is_action_pressed("LEFT") or event.is_action_pressed("RIGHT")

func _navigate_focus(event: InputEvent) -> void:
	var card_count := options_box.get_child_count()
	if card_count <= 0:
		return
	var focused := get_viewport().gui_get_focus_owner() as Control
	var card_index := focused.get_index() if focused != null and focused.get_parent() == options_box else -1
	if event.is_action_pressed("LEFT") or event.is_action_pressed("RIGHT"):
		if card_index >= 0:
			var direction := -1 if event.is_action_pressed("LEFT") else 1
			(options_box.get_child(clampi(card_index + direction, 0, card_count - 1)) as Button).grab_focus()
		elif focused == confirm_button and cancel_button.visible and event.is_action_pressed("LEFT"):
			cancel_button.grab_focus()
		elif focused == cancel_button and event.is_action_pressed("RIGHT"):
			confirm_button.grab_focus()
		return
	if event.is_action_pressed("DOWN") and card_index >= 0:
		confirm_button.grab_focus()
		return
	if event.is_action_pressed("UP") and (focused == confirm_button or focused == cancel_button):
		var target_index := clampi(_pinned_index if _summary_mode else _selected_index, 0, card_count - 1)
		(options_box.get_child(target_index) as Button).grab_focus()

func _update_input_device(event: InputEvent) -> void:
	var next_gamepad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var is_keyboard_or_pointer := event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion
	if not next_gamepad and not is_keyboard_or_pointer:
		return
	if next_gamepad:
		var next_device_id := event.device
		if _using_gamepad and _gamepad_device_id != next_device_id:
			_gamepad_device_id = next_device_id
			_update_detail_hint()
			return
		_gamepad_device_id = next_device_id
	if _using_gamepad == next_gamepad:
		return
	_using_gamepad = next_gamepad
	_update_detail_hint()

func _is_space_key_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	return key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE or key_event.unicode == KEY_SPACE

func _process(delta: float) -> void:
	if not is_modal_open():
		return
	if _held_quick_select_index >= 0:
		_held_quick_select_elapsed += maxf(delta, 0.0)
		_update_quick_select_hold_visual()
		if _held_quick_select_elapsed >= QUICK_SELECT_HOLD_SECONDS:
			var index := _held_quick_select_index
			_cancel_quick_select_hold()
			if index == _selected_index:
				_on_confirm_pressed()
func _activate_or_focus_confirm_button() -> void:
	if confirm_button.disabled:
		return
	if get_viewport().gui_get_focus_owner() == confirm_button:
		_on_confirm_pressed()
		return
	_cancel_quick_select_hold()
	confirm_button.grab_focus()

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
			progress.visible = true
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
	_detail_open_index = -1
	_pending_detail_index = -1
	_mouse_detail_index = -1
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
	for reward in incoming_options.slice(0, 3):
		if reward == null:
			continue
		_reward_options.append(reward)
	if _reward_options.is_empty():
		return false
	for idx in range(_reward_options.size()):
		var button := _build_reward_card_button(_reward_options[idx], idx)
		button.pressed.connect(Callable(self, "_on_reward_button_pressed").bind(idx, button))
		button.focus_entered.connect(Callable(self, "_on_reward_card_focus_entered").bind(idx, button))
		button.mouse_entered.connect(Callable(self, "_on_reward_card_mouse_entered").bind(idx, button))
		button.mouse_exited.connect(Callable(self, "_on_reward_card_mouse_exited").bind(idx, button))
		options_box.add_child(button)
	if options_box.get_child_count() > 0:
		var first := options_box.get_child(0) as Button
		if first:
			_on_reward_button_pressed(0, first)
	_update_grid_columns()
	_configure_card_focus_chain()
	_confirm_button_state()
	visible = true
	_set_battle_hud_suppressed(true)
	if options_box.get_child_count() > 0:
		(options_box.get_child(0) as Button).grab_focus()
	_play_entry_animation()
	return true

func _apply_unified_layout() -> void:
	panel.offset_left = -500.0
	panel.offset_top = -350.0
	panel.offset_right = 500.0
	panel.offset_bottom = 350.0
	options_scroll.custom_minimum_size.y = 500.0
	options_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

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
	_set_battle_hud_suppressed(false)
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
	_detail_open_index = -1
	_pending_detail_index = -1
	_mouse_detail_index = -1
	if _detail_open_timer != null:
		_detail_open_timer.stop()
	if _detail_close_timer != null:
		_detail_close_timer.stop()
	_title_override_cache = ""
	_subtitle_override_cache = ""
	_progress_index_cache = 0
	_progress_total_cache = 0
	_show_draft_hint_cache = false
	var ui = GlobalVariables.ui
	if ui != null and is_instance_valid(ui) and ui.has_method("_request_next_queued_equipment_pickup"):
		ui.call_deferred("_request_next_queued_equipment_pickup")

func _set_battle_hud_suppressed(suppressed: bool) -> void:
	var ui := GlobalVariables.ui
	if ui != null and is_instance_valid(ui) and ui.has_method("set_reward_modal_hud_hidden"):
		ui.call("set_reward_modal_hud_hidden", suppressed)

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
	if _detail_open_index >= 0 and index != _detail_open_index:
		_close_weapon_detail()
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
	if source_button != null and is_instance_valid(source_button) and not source_button.has_focus():
		source_button.grab_focus()
	_confirm_button_state()

func _on_reward_card_focus_entered(index: int, source_button: Button) -> void:
	_focus_index = index
	_on_reward_button_pressed(index, source_button)

func _on_reward_card_mouse_entered(index: int, button: Button) -> void:
	_hover_index = index
	var selected_index := _pinned_index if _summary_mode else _selected_index
	_animate_reward_card(button, index == selected_index, false, true)

func _on_reward_card_mouse_exited(index: int, button: Button) -> void:
	if _hover_index == index:
		_hover_index = -1
	var selected_index := _pinned_index if _summary_mode else _selected_index
	_animate_reward_card(button, index == selected_index, false, false)

func _configure_weapon_detail_hotspot(control: Control, reward_index: int) -> void:
	if control == null:
		return
	control.set_meta(&"weapon_detail_hotspot", true)
	control.set_meta(&"reward_index", reward_index)
	control.mouse_entered.connect(Callable(self, "_on_weapon_hotspot_mouse_entered").bind(reward_index))
	control.mouse_exited.connect(Callable(self, "_on_weapon_hotspot_mouse_exited").bind(reward_index))

func _restore_weapon_preview_interactions(button: Button) -> void:
	for node in button.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null:
			continue
		if bool(control.get_meta(&"weapon_detail_hotspot", false)):
			control.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_weapon_hotspot_mouse_entered(index: int) -> void:
	# Gallery/showcase cards can be built from a detached presenter without the
	# complete reward panel scene. They keep their static preview, but must not
	# enter the modal interaction state machine.
	if options_box == null or not is_instance_valid(options_box):
		return
	_mouse_detail_index = index
	_pending_detail_index = index
	if _detail_close_timer != null:
		_detail_close_timer.stop()
	if _detail_open_index == index:
		return
	if _detail_open_timer == null:
		_open_weapon_detail(index)
		return
	_detail_open_timer.start(DETAIL_HOVER_OPEN_SECONDS)

func _on_weapon_hotspot_mouse_exited(index: int) -> void:
	if _mouse_detail_index == index:
		_mouse_detail_index = -1
	if _detail_open_timer != null:
		_detail_open_timer.stop()
	_start_detail_close_timer(index)

func _on_detail_overlay_mouse_entered(index: int) -> void:
	_mouse_detail_index = index
	if _detail_close_timer != null:
		_detail_close_timer.stop()

func _on_detail_overlay_mouse_exited(index: int) -> void:
	if _mouse_detail_index == index:
		_mouse_detail_index = -1
	_start_detail_close_timer(index)

func _start_detail_close_timer(index: int) -> void:
	if _detail_open_index != index:
		return
	if _detail_close_timer == null:
		_close_weapon_detail()
		return
	_detail_close_timer.start(DETAIL_HOVER_CLOSE_SECONDS)

func _on_detail_open_timeout() -> void:
	if _pending_detail_index >= 0 and _mouse_detail_index == _pending_detail_index:
		_open_weapon_detail(_pending_detail_index)

func _on_detail_close_timeout() -> void:
	if _mouse_detail_index < 0:
		_close_weapon_detail()

func _toggle_focused_weapon_detail() -> void:
	if _detail_open_index >= 0:
		_close_weapon_detail()
		return
	var index := _focus_index
	if index < 0:
		index = _pinned_index if _summary_mode else _selected_index
	_open_weapon_detail(index)

func _open_weapon_detail(index: int) -> void:
	if options_box == null or not is_instance_valid(options_box):
		return
	if index < 0 or index >= options_box.get_child_count():
		return
	var button := options_box.get_child(index) as Button
	if button == null or not bool(button.get_meta(&"is_weapon_reward", false)):
		return
	if _detail_open_index >= 0 and _detail_open_index != index:
		_close_weapon_detail()
	var overlay := button.find_child("WeaponBranchDetailOverlay", true, false) as Control
	var content := button.find_child("CardContentMargin", true, false) as Control
	if overlay == null or content == null:
		return
	_cancel_quick_select_hold()
	_detail_open_index = index
	_pending_detail_index = -1
	overlay.visible = true
	content.modulate.a = 0.25
	button.z_index = 25
	_confirm_button_state()

func _close_weapon_detail() -> void:
	if _detail_open_timer != null:
		_detail_open_timer.stop()
	if _detail_close_timer != null:
		_detail_close_timer.stop()
	if options_box != null and is_instance_valid(options_box) \
			and _detail_open_index >= 0 and _detail_open_index < options_box.get_child_count():
		var button := options_box.get_child(_detail_open_index) as Button
		if button != null:
			var overlay := button.find_child("WeaponBranchDetailOverlay", true, false) as Control
			var content := button.find_child("CardContentMargin", true, false) as Control
			if overlay != null:
				overlay.visible = false
			if content != null:
				content.modulate.a = 1.0
			button.z_index = 1 if button.button_pressed else 0
	_detail_open_index = -1
	_pending_detail_index = -1
	_confirm_button_state()

func _update_detail_hint() -> void:
	if detail_hint == null:
		return
	if options_box == null or not is_instance_valid(options_box):
		detail_hint.visible = false
		return
	var index := _focus_index
	if index < 0:
		index = _pinned_index if _summary_mode else _selected_index
	var is_weapon := false
	if index >= 0 and index < options_box.get_child_count():
		var button := options_box.get_child(index) as Button
		is_weapon = button != null and bool(button.get_meta(&"is_weapon_reward", false))
	detail_hint.visible = is_weapon
	for child in detail_hint.get_children():
		detail_hint.remove_child(child)
		child.queue_free()
	_update_confirm_prompt_icon()
	if not is_weapon:
		return
	var detail_is_open := _detail_open_index >= 0
	var detail_action := _inline_text("CLOSE DETAILS", "关闭详情") if detail_is_open else _inline_text("VIEW DETAILS", "查看详情")
	if _using_gamepad:
		var button_coord := _gamepad_detail_button_coord()
		detail_hint.add_child(_make_prompt_icon(button_coord.x, button_coord.y, "Detail button"))
		detail_hint.add_child(_make_prompt_text(detail_action))
	else:
		var tab_group := INPUT_PROMPT_GROUP_SCENE.instantiate() as HBoxContainer
		tab_group.add_theme_constant_override("separation", 0)
		tab_group.add_child(_make_prompt_icon(19, 5, "Tab"))
		tab_group.add_child(_make_prompt_icon(20, 5, "Tab"))
		detail_hint.add_child(tab_group)
		detail_hint.add_child(_make_prompt_text(detail_action))

func _make_prompt_icon(column: int, row: int, accessible_name: String) -> TextureRect:
	var texture := AtlasTexture.new()
	texture.atlas = INPUT_PROMPT_ATLAS
	texture.region = Rect2(
		column * INPUT_PROMPT_TILE_STRIDE,
		row * INPUT_PROMPT_TILE_STRIDE,
		INPUT_PROMPT_TILE_SIZE,
		INPUT_PROMPT_TILE_SIZE
	)
	var icon := INPUT_PROMPT_ICON_SCENE.instantiate() as TextureRect
	icon.call("set_data", texture, Vector2(INPUT_PROMPT_DISPLAY_SIZE, INPUT_PROMPT_DISPLAY_SIZE), accessible_name)
	return icon

func _make_prompt_text(value: String) -> Label:
	var label := REWARD_PROMPT_TEXT_SCENE.instantiate() as Label
	label.call("set_data", value)
	return label

func _gamepad_detail_button_coord() -> Vector2i:
	var controller_name := Input.get_joy_name(_gamepad_device_id).to_lower()
	if controller_name.contains("playstation") or controller_name.contains("dualshock") or controller_name.contains("dualsense"):
		return Vector2i(13, 0)
	if controller_name.contains("nintendo") or controller_name.contains("switch") or controller_name.contains("joy-con"):
		return Vector2i(10, 0)
	return Vector2i(7, 0)

func _update_confirm_prompt_icon() -> void:
	if confirm_button == null:
		return
	if not _using_gamepad:
		if _summary_mode:
			confirm_button.icon = null
			return
		confirm_button.icon = INPUT_PROMPT_TEXTURE_FACTORY.space_prompt_texture()
		confirm_button.expand_icon = true
		confirm_button.add_theme_constant_override("icon_max_width", SPACE_PROMPT_DISPLAY_WIDTH)
		confirm_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		return
	var coord := _gamepad_confirm_button_coord()
	var texture := AtlasTexture.new()
	texture.atlas = INPUT_PROMPT_ATLAS
	texture.region = Rect2(
		coord.x * INPUT_PROMPT_TILE_STRIDE,
		coord.y * INPUT_PROMPT_TILE_STRIDE,
		INPUT_PROMPT_TILE_SIZE,
		INPUT_PROMPT_TILE_SIZE
	)
	confirm_button.icon = texture
	confirm_button.expand_icon = true
	confirm_button.add_theme_constant_override("icon_max_width", int(INPUT_PROMPT_DISPLAY_SIZE))
	confirm_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _gamepad_confirm_button_coord() -> Vector2i:
	var controller_name := Input.get_joy_name(_gamepad_device_id).to_lower()
	if controller_name.contains("playstation") or controller_name.contains("dualshock") or controller_name.contains("dualsense"):
		return Vector2i(15, 0)
	if controller_name.contains("nintendo") or controller_name.contains("switch") or controller_name.contains("joy-con"):
		return Vector2i(9, 0)
	return Vector2i(4, 0)

func _update_grid_columns() -> void:
	if options_box == null or options_scroll == null:
		return
	var option_count := maxi(1, options_box.get_child_count())
	options_box.columns = mini(3, option_count)

func _configure_card_focus_chain() -> void:
	var count := options_box.get_child_count()
	for index in range(count):
		var button := options_box.get_child(index) as Button
		if button == null:
			continue
		var previous := options_box.get_child(maxi(0, index - 1)) as Button
		var next := options_box.get_child(mini(count - 1, index + 1)) as Button
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
		button.focus_next = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous)

func _confirm_button_state() -> void:
	confirm_button.disabled = false if _summary_mode else _selected_index < 0 or _selected_index >= _reward_options.size()
	confirm_button.text = _get_confirm_button_text()
	_apply_action_button_style(confirm_button, true)
	confirm_button.add_theme_color_override("font_color", TOKENS.COLOR_TEXT_PRIMARY)
	confirm_button.add_theme_color_override("font_disabled_color", TOKENS.COLOR_TEXT_SECONDARY)
	_update_detail_hint()

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
	var reward_type := StringName(card_data.get("reward_type", &"generic"))
	var detail_variant := StringName(card_data.get("detail_variant", reward_type))
	var is_weapon_core_reward := reward_type == &"weapon_core"
	var is_weapon_visual_reward := reward_type in [&"new_weapon", &"weapon_upgrade"]
	var weapon_preview: Dictionary = WEAPON_PREVIEW_DATA.build(reward) if is_weapon_visual_reward else {}
	var button := REWARD_CARD_SCENE.instantiate() as Button
	button.call("set_data", {
		"reward_index": reward_index,
		"reward_type": reward_type,
		"is_weapon_reward": is_weapon_visual_reward,
		"is_weapon_core_reward": is_weapon_core_reward,
		"minimum_height": 400.0 if is_weapon_visual_reward else (DETAILED_CARD_MIN_HEIGHT if is_module_reward or is_weapon_core_reward else STANDARD_CARD_MIN_HEIGHT),
		"key_text": str(reward_index + 1) if not _summary_mode and reward_index >= 0 and reward_index < 3 else "",
		"type_label": str(card_data.get("type_label", "Reward")).to_upper(),
		"selected_text": LocalizationManager.tr_key("ui.reward.selected", "SELECTED"),
		"type_color": _get_reward_type_color(reward),
		"accent_color": TOKENS.COLOR_ACCENT_SYSTEM,
	})
	var full_detail := str(card_data.get("detail_text", "")).strip_edges()
	button.tooltip_text = ""
	var body := button.get_node("CardContentMargin/Body") as VBoxContainer
	if is_weapon_core_reward:
		body.add_child(_build_weapon_core_content(card_data))
		_set_mouse_filter_recursive(button, Control.MOUSE_FILTER_IGNORE)
		_clear_tooltips_recursive(button)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_reward_card_style(button, reward, false)
		return button

	var text_box := REWARD_TEXT_COLUMN_SCENE.instantiate() as VBoxContainer
	if is_weapon_visual_reward:
		var weapon_hero := _build_weapon_reward_hero(card_data)
		body.add_child(weapon_hero)
		body.add_child(text_box)
	else:
		var header := REWARD_HEADER_SCENE.instantiate() as HBoxContainer
		body.add_child(header)
		header.call("set_content", _make_reward_icon(card_data, Vector2(72.0, 72.0), 7), text_box)

	var display_title := str(card_data.get("title", "Reward")).strip_edges()
	if is_weapon_visual_reward:
		display_title = _weapon_reward_display_name(reward, display_title)
	var name_label := _make_card_label(display_title, 19 if is_weapon_visual_reward else TOKENS.FONT_BUTTON, TOKENS.COLOR_TEXT_PRIMARY)
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
		name_label.name = "WeaponRewardName"
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_weapon_visual_reward:
		_attach_damage_icons_to_weapon_name(name_label, weapon_preview.get("damage_types", []))
	text_box.add_child(name_label)
	var chips: Array = card_data.get("chips", [])
	if is_module_reward and not chips.is_empty():
		var module_chip_row := REWARD_CHIP_ROW_SCENE.instantiate() as HFlowContainer
		BUILD_TAG_DISPLAY.populate_chip_row(module_chip_row, chips)
		text_box.add_child(module_chip_row)

	var meta_text := str(card_data.get("meta_text", "")).strip_edges()
	var level_text := str(card_data.get("level_text", "")).strip_edges()
	var meta_label := _make_card_label(level_text if level_text != "" else meta_text, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_SECONDARY)
	meta_label.clip_text = true
	if is_weapon_visual_reward:
		meta_label.name = "WeaponLevelLabel"
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_box.add_child(meta_label)
	var rarity_label := _make_rarity_label(str(card_data.get("rarity", reward.get_rarity())))
	if is_weapon_visual_reward:
		_attach_rarity_to_weapon_level(meta_label, rarity_label)
	else:
		text_box.add_child(rarity_label)

	var summary_parent: VBoxContainer = body
	if is_weapon_visual_reward:
		var description_box := WEAPON_DESCRIPTION_SECTION_SCENE.instantiate() as VBoxContainer
		body.add_child(description_box)
		summary_parent = description_box
	elif is_module_reward:
		var effect_box := MODULE_EFFECT_SECTION_SCENE.instantiate() as VBoxContainer
		body.add_child(effect_box)
		effect_box.call("set_heading", LocalizationManager.tr_key("ui.reward.module_effect", "Module Effect"))
		summary_parent = effect_box
	var role_summary := str(card_data.get("role_summary", "")).strip_edges()
	var behavior_summary := str(card_data.get("summary_text", "")).strip_edges()
	if is_weapon_visual_reward and role_summary != "" and role_summary != behavior_summary:
		var role_label := _make_card_label(role_summary, 15, TOKENS.COLOR_TEXT_PRIMARY)
		role_label.name = "WeaponRoleSummary"
		role_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		role_label.clip_text = true
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.tooltip_text = ""
		summary_parent.add_child(role_label)
	var summary_label := _make_card_label(behavior_summary, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_PRIMARY)
	summary_label.name = "BehaviorSummary"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.max_lines_visible = 2
	summary_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	summary_label.tooltip_text = ""
	if is_module_reward:
		# Keep the plain semantic node for callers that inspect card data, while the
		# visible rich-text version gives the module's thresholds and payoff priority.
		summary_label.visible = false
		summary_parent.add_child(summary_label)
		summary_parent.add_child(_make_highlighted_module_summary(behavior_summary))
	else:
		summary_parent.add_child(summary_label)

	var feature_lines: PackedStringArray = card_data.get("feature_lines", PackedStringArray())
	if not feature_lines.is_empty():
		var feature_box := REWARD_FEATURE_LIST_SCENE.instantiate() as VBoxContainer
		summary_parent.add_child(feature_box)
		for feature in feature_lines.slice(0, 2):
			var feature_label := _make_card_label("• %s" % str(feature).strip_edges(), 13, Color(0.70, 0.80, 0.84, 1.0))
			feature_label.name = "FeatureLine"
			_configure_wrapped_card_text(feature_label)
			feature_label.tooltip_text = ""
			feature_box.add_child(feature_label)

	if is_module_reward:
		body.add_child(_build_module_weapon_grid(card_data))
	elif is_weapon_visual_reward:
		body.add_child(_build_core_weapon_stats(card_data))
		body.add_child(_build_weapon_preview_section(weapon_preview, reward_index))
	else:
		var comparison_lines := _card_comparison_lines(card_data)
		var comparison_box := REWARD_COMPARISON_BOX_SCENE.instantiate() as VBoxContainer
		body.add_child(comparison_box)
		for comparison_line in comparison_lines:
			var comparison_label := _make_card_label(str(comparison_line), TOKENS.FONT_LABEL, TOKENS.COLOR_POSITIVE)
			comparison_label.name = "ComparisonLine"
			_configure_wrapped_card_text(comparison_label)
			comparison_label.tooltip_text = ""
			comparison_box.add_child(comparison_label)

	var tag_text := str(card_data.get("short_tag", "")).strip_edges()
	if not is_module_reward and not chips.is_empty():
		var chip_row := REWARD_CHIP_ROW_SCENE.instantiate() as HFlowContainer
		BUILD_TAG_DISPLAY.populate_chip_row(chip_row, chips)
		body.add_child(chip_row)
	elif not is_module_reward and tag_text != "" and detail_variant != &"weapon_upgrade":
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
		synergy_label.tooltip_text = ""
		body.add_child(synergy_label)

	_set_mouse_filter_recursive(button, Control.MOUSE_FILTER_IGNORE)
	_clear_tooltips_recursive(button)
	_restore_weapon_preview_interactions(button)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_weapon_visual_reward:
		button.add_child(_build_weapon_branch_detail_overlay(weapon_preview, reward_index))
	_apply_reward_card_style(button, reward, false)
	return button

func _build_weapon_core_content(card_data: Dictionary) -> VBoxContainer:
	var content := WEAPON_CORE_CONTENT_SCENE.instantiate() as VBoxContainer
	var source_name := str(card_data.get("source_weapon_name", "")).strip_edges()
	var amount := int(card_data.get("core_amount", 1))
	var current_count := int(card_data.get("current_core_count", 0))
	var resulting_count := int(card_data.get("resulting_core_count", amount))
	var usage_lines: PackedStringArray = card_data.get("usable_branch_lines", PackedStringArray())
	content.call("set_data", {
		"title": LocalizationManager.tr_format("ui.reward.core.named_title", {"name": source_name}, "%s Core" % source_name),
		"source_icon": _crop_reward_texture_to_content(card_data.get("source_weapon_icon", null) as Texture2D),
		"source": LocalizationManager.tr_format("ui.reward.core.source", {"name": source_name}, "Source: %s" % source_name),
		"gain": LocalizationManager.tr_format("ui.reward.core.gain", {"amount": amount}, "+%d Core" % amount),
		"inventory": LocalizationManager.tr_format("ui.reward.core.inventory", {"current": current_count, "resulting": resulting_count}, "Inventory: %d → %d" % [current_count, resulting_count]),
		"current_count": current_count,
		"resulting_count": resulting_count,
		"tag_heading": LocalizationManager.tr_key("ui.reward.core.inherited_tags", "INHERITED CORE TAGS"),
		"usage_heading": LocalizationManager.tr_key("ui.reward.core.usable_by_label", "Usable By"),
		"usage_lines": usage_lines,
		"usage_summary": LocalizationManager.tr_format("ui.reward.core.usage_summary", {"count": int(card_data.get("usable_branch_count", usage_lines.size()))}, "Supports %d fusion branches" % int(card_data.get("usable_branch_count", usage_lines.size()))),
		"usage_more": LocalizationManager.tr_format("ui.reward.core.more_usages", {"count": maxi(0, usage_lines.size() - 2)}, "%d more" % maxi(0, usage_lines.size() - 2)),
		"usage_empty": LocalizationManager.tr_key("ui.reward.core.no_usable_branches", "No available fusion recipes found yet"),
	})
	BUILD_TAG_DISPLAY.populate_chip_row(content.call("get_chip_grid") as GridContainer, card_data.get("chips", []))
	return content

func _build_weapon_core_usage_section(card_data: Dictionary) -> VBoxContainer:
	var usage_lines: PackedStringArray = card_data.get("usable_branch_lines", PackedStringArray())
	var content := WEAPON_CORE_CONTENT_SCENE.instantiate() as VBoxContainer
	content.call("set_data", {
		"usage_heading": LocalizationManager.tr_key("ui.reward.core.usable_by_label", "Usable By"),
		"usage_lines": usage_lines,
		"usage_summary": LocalizationManager.tr_format("ui.reward.core.usage_summary", {"count": int(card_data.get("usable_branch_count", usage_lines.size()))}, "Supports %d fusion branches" % int(card_data.get("usable_branch_count", usage_lines.size()))),
		"usage_more": LocalizationManager.tr_format("ui.reward.core.more_usages", {"count": maxi(0, usage_lines.size() - 2)}, "%d more" % maxi(0, usage_lines.size() - 2)),
		"usage_empty": LocalizationManager.tr_key("ui.reward.core.no_usable_branches", "No available fusion recipes found yet"),
	})
	var usage_section := content.get_node("WeaponCoreUsagePanel/WeaponCoreUsageSection") as VBoxContainer
	usage_section.get_parent().remove_child(usage_section)
	content.free()
	return usage_section

func _build_core_weapon_stats(card_data: Dictionary) -> HBoxContainer:
	var stats_box := CORE_WEAPON_STATS_SCENE.instantiate() as HBoxContainer
	var lines: PackedStringArray = card_data.get("core_stat_lines", PackedStringArray())
	var core_keys: Array[StringName] = [&"damage", &"fire_interval_sec", &"ammo"]
	var items: Array = []
	for index in range(3):
		var fallback_key: StringName = core_keys[index]
		var text := str(lines[index]) if index < lines.size() else WEAPON_STAT_FORMATTER.format_line(fallback_key, null, " ")
		var separator_index := text.find(" ")
		var heading_text := text.left(separator_index) if separator_index >= 0 else WEAPON_STAT_FORMATTER.format_label(fallback_key)
		var value_text := text.substr(separator_index + 1) if separator_index >= 0 else "--"
		items.append({"heading": heading_text, "value": value_text})
	stats_box.call("set_data", items)
	return stats_box

func _build_weapon_reward_hero(card_data: Dictionary) -> CenterContainer:
	var hero := WEAPON_REWARD_HERO_SCENE.instantiate() as CenterContainer
	var icon := _make_reward_icon(card_data, Vector2(132.0, 76.0), 6)
	icon.name = "WeaponHeroImage"
	hero.call("set_icon", icon)
	return hero

func _build_weapon_preview_section(preview: Dictionary, reward_index: int) -> VBoxContainer:
	var section := WEAPON_BRANCH_PREVIEW_SECTION_SCENE.instantiate() as VBoxContainer
	section.call("set_heading", _inline_text("BRANCH PREVIEW", "分支预览"))
	var branch_row := section.call("get_branch_container") as HBoxContainer
	_configure_weapon_detail_hotspot(branch_row, reward_index)
	for branch_variant in preview.get("branches", []):
		branch_row.add_child(_build_branch_preview_node(branch_variant as Dictionary))
	return section

func _build_branch_preview_node(branch: Dictionary) -> PanelContainer:
	var damage_types: Array = branch.get("damage_types", [])
	var state := StringName(branch.get("state", &"locked"))
	var panel_node := BRANCH_PREVIEW_CARD_SCENE.instantiate() as PanelContainer
	var branch_icon_slot_size := 18.0 if damage_types.size() > 1 else 20.0
	var branch_name := str(branch.get("name", "Branch"))
	var data := _branch_component_data(branch, damage_types)
	data["name"] = branch_name
	data["status"] = _branch_state_short(state)
	data["icon_size"] = branch_icon_slot_size
	panel_node.call("set_data", data)
	return panel_node

func _build_damage_type_icon_row(damage_types: Array, icon_size: float, row_name: String) -> HBoxContainer:
	var row := DAMAGE_TYPE_ICON_ROW_SCENE.instantiate() as HBoxContainer
	var items: Array = []
	for type_variant in damage_types.slice(0, 2):
		var damage_type := Attack.normalize_damage_type(type_variant)
		var texture := DAMAGE_TYPE_ICONS.get(damage_type) as Texture2D
		if texture == null:
			continue
		var damage_color := WEAPON_PREVIEW_DATA.damage_color(damage_type)
		items.append({"type": str(damage_type), "texture": texture, "color": damage_color})
	row.call("set_data", items, icon_size, row_name)
	return row

func _attach_damage_icons_to_weapon_name(name_label: Label, damage_types: Array) -> void:
	_attach_damage_icons_to_label(name_label, damage_types, 24.0, "WeaponDamageTypeIcons", 5.0)

func _attach_damage_icons_to_label(
	label: Label,
	damage_types: Array,
	icon_size: float,
	row_name: String,
	gap: float
) -> void:
	var icon_row := _build_damage_type_icon_row(damage_types, icon_size, row_name)
	if icon_row.get_child_count() == 0:
		return
	var icon_count := icon_row.get_child_count()
	var row_width := float(icon_count) * icon_size + float(maxi(icon_count - 1, 0)) * 2.0
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	icon_row.set_anchors_preset(Control.PRESET_CENTER)
	icon_row.offset_right = -text_width * 0.5 - gap
	icon_row.offset_left = icon_row.offset_right - row_width
	icon_row.offset_top = -icon_size * 0.5
	icon_row.offset_bottom = icon_size * 0.5
	label.add_child(icon_row)

func _attach_rarity_to_weapon_level(level_label: Label, rarity_label: Label) -> void:
	var level_font := level_label.get_theme_font("font")
	var level_font_size := level_label.get_theme_font_size("font_size")
	var level_width := level_font.get_string_size(
		level_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		level_font_size
	).x
	var rarity_font := rarity_label.get_theme_font("font")
	var rarity_font_size := rarity_label.get_theme_font_size("font_size")
	var rarity_width := rarity_font.get_string_size(
		rarity_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		rarity_font_size
	).x
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rarity_label.set_anchors_preset(Control.PRESET_CENTER)
	rarity_label.offset_left = level_width * 0.5 + 8.0
	rarity_label.offset_right = rarity_label.offset_left + rarity_width
	rarity_label.offset_top = -12.0
	rarity_label.offset_bottom = 12.0
	level_label.add_child(rarity_label)

func _build_weapon_branch_detail_overlay(preview: Dictionary, reward_index: int) -> PanelContainer:
	var overlay := WEAPON_BRANCH_DETAIL_OVERLAY_SCENE.instantiate() as PanelContainer
	overlay.call("set_heading", _inline_text("WEAPON BRANCH DETAILS", "武器分支详情"))
	var row := overlay.call("get_branch_container") as HBoxContainer
	for branch_variant in preview.get("branches", []):
		row.add_child(_build_branch_detail_card(branch_variant as Dictionary))
	overlay.mouse_entered.connect(Callable(self, "_on_detail_overlay_mouse_entered").bind(reward_index))
	overlay.mouse_exited.connect(Callable(self, "_on_detail_overlay_mouse_exited").bind(reward_index))
	return overlay

func _build_branch_detail_card(branch: Dictionary) -> PanelContainer:
	var damage_types: Array = branch.get("damage_types", [])
	var card := BRANCH_DETAIL_CARD_SCENE.instantiate() as PanelContainer
	var data := _branch_component_data(branch, damage_types)
	data["name"] = str(branch.get("name", "Branch"))
	data["type_text"] = _damage_type_text(damage_types)
	data["description"] = str(branch.get("description", ""))
	card.call("set_data", data)
	return card

func _branch_component_data(branch: Dictionary, damage_types: Array) -> Dictionary:
	var icon_items: Array = []
	var accent_colors: Array = []
	for type_variant in damage_types.slice(0, 2):
		var damage_type := Attack.normalize_damage_type(type_variant)
		var color := WEAPON_PREVIEW_DATA.damage_color(damage_type)
		accent_colors.append(color)
		var texture := DAMAGE_TYPE_ICONS.get(damage_type) as Texture2D
		if texture != null:
			icon_items.append({"type": str(damage_type), "texture": texture, "color": color})
	var satisfied_tags: Array = branch.get("satisfied_fusion_tags", [])
	var tag_items: Array = []
	for tag_variant in branch.get("fusion_required_tags", []):
		var tag := StringName(tag_variant)
		var satisfied := satisfied_tags.has(tag)
		tag_items.append({
			"id": str(tag),
			"text": "【%s】" % LocalizationManager.get_module_term(tag, str(tag).replace("_", " ").capitalize()),
			"satisfied": satisfied,
			"color": _branch_primary_color(damage_types) if satisfied else TOKENS.COLOR_TEXT_SECONDARY,
		})
	var fuse := int(branch.get("unlock_fuse", 2))
	return {
		"primary_color": _branch_primary_color(damage_types),
		"icon_items": icon_items,
		"accent_colors": accent_colors,
		"recipe_prefix": _inline_text("Fuse %d:" % fuse, "融合 %d：" % fuse),
		"recipe_tags": tag_items,
		"background": TOKENS.COLOR_SURFACE_INTERACTIVE if StringName(branch.get("state", &"locked")) == &"acquired" else TOKENS.COLOR_SURFACE,
	}

func _branch_primary_color(damage_types: Array) -> Color:
	if damage_types.is_empty():
		return WEAPON_PREVIEW_DATA.damage_color(&"physical")
	return WEAPON_PREVIEW_DATA.damage_color(StringName(damage_types[0]))

func _damage_type_text(damage_types: Array) -> String:
	var labels := PackedStringArray()
	for type_variant in damage_types:
		var key := StringName(type_variant)
		labels.append(LocalizationManager.get_module_term(key, str(key).capitalize()))
	return " + ".join(labels)

func _branch_state_short(state: StringName) -> String:
	match state:
		&"acquired": return "✓ %s" % _inline_text("OWNED", "已获得")
		&"available": return _inline_text("AVAILABLE", "可解锁")
		_: return _inline_text("LOCKED", "未解锁")

func _build_branch_fusion_recipe(branch: Dictionary, damage_types: Array) -> HBoxContainer:
	var recipe_row := BRANCH_FUSION_RECIPE_SCENE.instantiate() as HBoxContainer
	var fuse := int(branch.get("unlock_fuse", 2))
	var satisfied_tags: Array = branch.get("satisfied_fusion_tags", [])
	var satisfied_color := _branch_primary_color(damage_types)
	var tag_items: Array = []
	for tag_variant in branch.get("fusion_required_tags", []):
		var tag := StringName(tag_variant)
		var tag_text := LocalizationManager.get_module_term(tag, str(tag).replace("_", " ").capitalize())
		tag_items.append({"id": str(tag), "text": "【%s】" % tag_text, "satisfied": satisfied_tags.has(tag), "color": satisfied_color if satisfied_tags.has(tag) else TOKENS.COLOR_TEXT_SECONDARY})
	recipe_row.call("set_data", _inline_text("Fuse %d:" % fuse, "融合 %d：" % fuse), tag_items)
	return recipe_row

func _inline_text(english: String, chinese: String) -> String:
	return chinese if LocalizationManager.get_locale() == "zh_CN" else english

func _build_module_weapon_grid(card_data: Dictionary) -> VBoxContainer:
	var section := MODULE_FIT_SECTION_SCENE.instantiate() as VBoxContainer
	var previews: Array = card_data.get("compatible_weapons", [])
	var owned_count := int(card_data.get("owned_weapon_count", 0))
	var compatible_count := 0
	for preview_variant in previews:
		if bool((preview_variant as Dictionary).get("compatible", true)):
			compatible_count += 1
	var count_text := _inline_text(
		"Equippable %d/%d" % [compatible_count, owned_count],
		"可装备 %d/%d" % [compatible_count, owned_count]
	)
	section.call("set_data", {
		"heading": LocalizationManager.tr_key("ui.module.fit.title", "Fit Check"),
		"count": count_text,
		"empty": previews.is_empty(),
		"empty_text": LocalizationManager.tr_key("ui.reward.no_compatible_weapons", "No owned weapon can equip this module"),
	})
	var grid := section.call("get_grid") as GridContainer
	for preview_variant in previews.slice(0, 4):
		grid.add_child(_build_module_weapon_tile(preview_variant as Dictionary))
	return section

func _build_module_weapon_tile(preview: Dictionary) -> PanelContainer:
	var compatible := bool(preview.get("compatible", true))
	var has_slot := bool(preview.get("has_slot", not bool(preview.get("requires_replace", false))))
	var state_color := Color(0.40, 0.86, 0.57, 1.0)
	if not compatible:
		state_color = Color(1.0, 0.34, 0.28, 1.0)
	elif not has_slot:
		state_color = Color(0.95, 0.74, 0.30, 1.0)
	var tile := MODULE_FIT_WEAPON_TILE_SCENE.instantiate() as PanelContainer
	var weapon_name := str(preview.get("name", "Weapon"))
	var status_text := _inline_text("Can equip now", "可直接装备")
	var status_icon := "✓ "
	if not compatible:
		status_text = str(preview.get("reason", LocalizationManager.tr_key("ui.module.fit.not_compatible", "Not compatible")))
		status_icon = "✕ "
	elif not has_slot:
		status_text = _inline_text("Module slots full", "模组槽已满")
		status_icon = "! "
	else:
		var fit_reason := str(preview.get("fit_reason", "")).strip_edges()
		if fit_reason != "":
			status_text = _inline_text("Can equip now", "可直接装备")
	tile.call("set_data", {"icon": preview.get("icon_texture", null), "name": weapon_name, "status": status_icon + status_text, "status_tooltip": status_text, "state_color": state_color})
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
		&"direct_fit", &"unlocks_chain": return TOKENS.COLOR_POSITIVE
		&"partial_fit": return TOKENS.COLOR_WARNING
		&"blocked", &"conflict": return TOKENS.COLOR_DANGER
		_: return TOKENS.COLOR_TEXT_SECONDARY

func _build_reward_card_data(reward: RewardInfo) -> Dictionary:
	return _get_reward_data_assembler()._build_reward_card_data(reward)

func _build_reward_display_data(reward: RewardInfo) -> Dictionary:
	return _get_reward_data_assembler()._build_reward_display_data(reward)

func _make_reward_icon(card_data: Dictionary, minimum_size: Vector2 = Vector2(56.0, 56.0), content_margin: int = 6) -> Control:
	var fallback_key := str(card_data.get("fallback_icon_key", "reward")).strip_edges()
	var chip := BUILD_TAG_DISPLAY.build_tag_chip(fallback_key)
	var accent: Color = chip.get("color", Color(0.54, 0.64, 0.72, 1.0))
	var root := REWARD_ICON_SCENE.instantiate() as Control
	root.name = "RewardIcon"
	var texture := card_data.get("icon_texture", null) as Texture2D
	if texture != null:
		if fallback_key == "weapon":
			texture = _crop_reward_texture_to_content(texture)
	var badge_text := str(card_data.get("icon_badge_text", "")).strip_edges()
	root.call("set_data", {"size": minimum_size, "margin": content_margin, "texture": texture, "fallback": _fallback_icon_text(fallback_key), "badge": badge_text, "badge_color": card_data.get("icon_badge_color", accent) as Color})
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

func _fallback_icon_text(icon_key: String) -> String:
	match icon_key:
		"weapon_core":
			return "C"
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

func _make_card_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := REWARD_CARD_LABEL_SCENE.instantiate() as Label
	label.call("set_data", text, font_size + CARD_FONT_SIZE_BONUS, font_color)
	return label

func _make_highlighted_module_summary(summary_text: String) -> RichTextLabel:
	var summary := MODULE_EFFECT_SUMMARY_SCENE.instantiate() as RichTextLabel
	summary.call("set_data", summary_text, TOKENS.COLOR_ACCENT_SYSTEM)
	return summary

func _configure_wrapped_card_text(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

func _make_rarity_label(rarity: String) -> Label:
	var normalized := RARITY_UTIL.normalize(rarity)
	var rarity_text := "%s %s" % [_rarity_symbol(normalized), RARITY_UTIL.get_display_name(normalized)]
	var label := _make_card_label(rarity_text, TOKENS.FONT_LABEL, RARITY_UTIL.get_color(normalized))
	label.name = "RarityLabel"
	label.set_meta(&"rarity", normalized)
	label.tooltip_text = RARITY_UTIL.get_display_name(normalized)
	return label

func _rarity_symbol(rarity: String) -> String:
	match RARITY_UTIL.normalize(rarity):
		RARITY_UTIL.RARE: return "◆"
		RARITY_UTIL.EPIC: return "✦"
		_: return "◇"

func _compact_detail_text(text: String, _max_characters: int) -> String:
	var compact := text.replace("\r", " ").replace("\n", " ").replace("  ", " ").strip_edges()
	return compact

func _weapon_reward_display_name(reward: RewardInfo, fallback_title: String) -> String:
	if reward != null:
		if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
			var target_name := reward.target_weapon_name.strip_edges()
			if target_name != "":
				return target_name
			var target_id := reward.target_weapon_id.strip_edges()
			if target_id != "":
				var localized_target := LocalizationManager.get_weapon_name_by_id(target_id, "").strip_edges()
				if localized_target != "":
					return localized_target
		var item_id := reward.item_id.strip_edges()
		if item_id != "":
			var localized_item := LocalizationManager.get_weapon_name_by_id(item_id, "").strip_edges()
			if localized_item != "":
				return localized_item
	var normalized_fallback := fallback_title.strip_edges()
	if normalized_fallback != "":
		return normalized_fallback
	return LocalizationManager.tr_key("ui.branch.weapon", "Weapon")

func _apply_reward_card_style(button: Button, reward: RewardInfo, selected: bool, holding: bool = false) -> void:
	if button == null or reward == null:
		return
	var card_background := TOKENS.COLOR_SURFACE_ELEVATED
	var selected_badge := button.find_child("SelectedBadge", true, false) as Control
	if selected_badge != null:
		selected_badge.visible = selected
	var selection_bar := button.find_child("SelectionIndicatorBar", true, false) as ColorRect
	if selection_bar != null:
		selection_bar.visible = selected
	for state in ["normal", "hover", "pressed", "focus"]:
		var border_color := TOKENS.COLOR_ACCENT_SYSTEM if selected else Color(0.12, 0.24, 0.31, 0.58)
		if not selected and state in ["hover", "pressed", "focus"]:
			border_color = Color(TOKENS.COLOR_ACCENT_SYSTEM.r, TOKENS.COLOR_ACCENT_SYSTEM.g, TOKENS.COLOR_ACCENT_SYSTEM.b, 0.68)
		var style := TOKENS.make_panel_style(true, border_color)
		style.shadow_size = 0
		style.bg_color = card_background
		style.border_color = border_color
		style.set_border_width_all(TOKENS.BORDER_STRONG if selected else TOKENS.BORDER_THIN)
		style.set_corner_radius_all(TOKENS.RADIUS_PANEL)
		button.add_theme_stylebox_override(state, style)
	_animate_reward_card(button, selected, holding, _hover_index >= 0 and options_box.get_child(_hover_index) == button)

func _animate_reward_card(button: Button, selected: bool, _holding: bool, _hovered: bool) -> void:
	if button == null or not is_instance_valid(button):
		return
	var was_selected := bool(button.get_meta(&"reward_was_selected", false))
	button.set_meta(&"reward_was_selected", selected)
	button.z_index = 1 if selected else 0
	if selected == was_selected:
		return
	var previous_tween := button.get_meta(&"reward_motion_tween") as Tween if button.has_meta(&"reward_motion_tween") else null
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if selected:
		tween.tween_property(button, "scale", CARD_SELECTION_PULSE_SCALE, 0.07)
		tween.tween_property(button, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK)
	else:
		tween.tween_property(button, "scale", Vector2.ONE, 0.08)
	button.set_meta(&"reward_motion_tween", tween)

func _apply_action_button_style(button: Button, primary: bool) -> void:
	var color := TOKENS.COLOR_ACCENT_SYSTEM if primary else TOKENS.COLOR_BORDER_STRONG
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
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
		button.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, TOKENS.COLOR_TEXT_PRIMARY)

func _apply_panel_style() -> void:
	$ModalScrim.color = TOKENS.COLOR_SCRIM
	panel.add_theme_stylebox_override("panel", TOKENS.make_panel_style(true, TOKENS.COLOR_BORDER_STRONG))
	var action_panel := $Panel/VBox/ActionPanel as PanelContainer
	action_panel.add_theme_stylebox_override("panel", TOKENS.make_panel_style(false, TOKENS.COLOR_BORDER))
	TOKENS.style_label(title_label, TOKENS.FONT_TITLE + 3, TOKENS.COLOR_TEXT_PRIMARY)
	TOKENS.style_label(subtitle_label, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_SECONDARY)

func _clear_tooltips_recursive(root: Control) -> void:
	root.tooltip_text = ""
	for child in root.get_children():
		if child is Control:
			_clear_tooltips_recursive(child as Control)

func _get_reward_action_color(reward: RewardInfo) -> Color:
	return _get_reward_type_color(reward)

func _get_reward_type_color(reward: RewardInfo) -> Color:
	if reward == null:
		return Color(0.54, 0.64, 0.72, 1.0)
	if reward.reward_kind == RewardInfo.KIND_WEAPON_UPGRADE:
		return Color(0.36, 0.62, 0.95, 1.0)
	if reward.reward_kind == RewardInfo.KIND_TASK_MODULE:
		return Color(1.0, 0.60, 0.30, 1.0)
	if reward.reward_kind == RewardInfo.KIND_CELL_EFFECT:
		return Color(0.31, 0.84, 0.91, 1.0)
	if reward.reward_kind == RewardInfo.KIND_ECONOMY or reward.total_chip_value > 0 or reward.gold_value > 0:
		return TOKENS.COLOR_REWARD
	if reward.module_scene != null:
		return Color(0.69, 0.42, 1.0, 1.0)
	if reward.item_id.strip_edges() != "" and reward.item_level > 0:
		var outcome := _get_weapon_obtain_prediction(reward.item_id)
		var result_type := str(outcome.get("result", "not_applicable"))
		if result_type == "dismantled_to_core":
			return CORE_MATERIAL_COLOR
		return TOKENS.COLOR_BORDER_STRONG
	return Color(0.42, 0.78, 0.48, 1.0)

func _set_mouse_filter_recursive(root: Control, mouse_filter_value: Control.MouseFilter) -> void:
	for child in root.get_children():
		var control := child as Control
		if control == null:
			continue
		control.mouse_filter = mouse_filter_value
		_set_mouse_filter_recursive(control, mouse_filter_value)

func _get_weapon_obtain_prediction(weapon_id: String) -> Dictionary:
	if PlayerData.player == null or not is_instance_valid(PlayerData.player):
		return {}
	if not PlayerData.player.has_method("predict_weapon_obtain"):
		return {}
	return PlayerData.player.predict_weapon_obtain(weapon_id)

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
