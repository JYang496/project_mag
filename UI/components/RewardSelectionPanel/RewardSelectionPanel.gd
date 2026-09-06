extends Control

const REWARD_ICON_SCENE := preload("res://UI/components/RewardIcon/RewardIcon.tscn")
const REWARD_CARD_SCENE := preload("res://UI/components/RewardCard/RewardCard.tscn")

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
var _detail_open_timer: Timer
var _detail_close_timer: Timer
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
	_detail_open_timer = Timer.new()
	_detail_open_timer.one_shot = true
	_detail_open_timer.timeout.connect(_on_detail_open_timeout)
	add_child(_detail_open_timer)
	_detail_close_timer = Timer.new()
	_detail_close_timer.one_shot = true
	_detail_close_timer.timeout.connect(_on_detail_close_timeout)
	add_child(_detail_close_timer)

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
		var tab_group := HBoxContainer.new()
		tab_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(INPUT_PROMPT_DISPLAY_SIZE, INPUT_PROMPT_DISPLAY_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = accessible_name
	return icon

func _make_prompt_text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", TOKENS.FONT_LABEL)
	label.add_theme_color_override("font_color", Color(0.58, 0.82, 0.94, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var hold_progress := button.get_node("CardContentMargin/Body/HoldProgress") as ProgressBar
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = TOKENS.COLOR_REWARD
	hold_progress.add_theme_stylebox_override("fill", progress_fill)
	if is_weapon_core_reward:
		body.add_child(_build_weapon_core_content(card_data))
		_set_mouse_filter_recursive(button, Control.MOUSE_FILTER_IGNORE)
		_clear_tooltips_recursive(button)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_reward_card_style(button, reward, false)
		return button

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	if is_weapon_visual_reward:
		var weapon_hero := _build_weapon_reward_hero(card_data)
		body.add_child(weapon_hero)
		body.add_child(text_box)
	else:
		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_theme_constant_override("separation", 10)
		body.add_child(header)
		header.add_child(_make_reward_icon(card_data, Vector2(72.0, 72.0), 7))
		header.add_child(text_box)

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
		var module_chip_row := HFlowContainer.new()
		module_chip_row.add_theme_constant_override("h_separation", 5)
		module_chip_row.add_theme_constant_override("v_separation", 4)
		module_chip_row.name = "BuildChipRow"
		module_chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		module_chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		var description_box := VBoxContainer.new()
		description_box.name = "WeaponDescriptionSlot"
		description_box.custom_minimum_size = Vector2(0.0, 96.0)
		description_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_box.add_theme_constant_override("separation", 3)
		body.add_child(description_box)
		summary_parent = description_box
	elif is_module_reward:
		var effect_box := VBoxContainer.new()
		effect_box.name = "ModuleEffectBox"
		effect_box.add_theme_constant_override("separation", 3)
		body.add_child(effect_box)
		var effect_heading := _make_card_label(LocalizationManager.tr_key("ui.reward.module_effect", "Module Effect"), 13, TOKENS.COLOR_TEXT_SECONDARY)
		effect_heading.name = "ModuleEffectHeading"
		effect_box.add_child(effect_heading)
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
		var feature_box := VBoxContainer.new()
		feature_box.name = "FeatureList"
		feature_box.custom_minimum_size.y = 46.0
		feature_box.add_theme_constant_override("separation", 2)
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
		var comparison_box := VBoxContainer.new()
		comparison_box.name = "ComparisonBox"
		comparison_box.custom_minimum_size.y = 82.0
		comparison_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		comparison_box.alignment = BoxContainer.ALIGNMENT_CENTER
		comparison_box.add_theme_constant_override("separation", 3)
		body.add_child(comparison_box)
		for comparison_line in comparison_lines:
			var comparison_label := _make_card_label(str(comparison_line), TOKENS.FONT_LABEL, TOKENS.COLOR_POSITIVE)
			comparison_label.name = "ComparisonLine"
			_configure_wrapped_card_text(comparison_label)
			comparison_label.tooltip_text = ""
			comparison_box.add_child(comparison_label)

	var tag_text := str(card_data.get("short_tag", "")).strip_edges()
	if not is_module_reward and not chips.is_empty():
		var chip_row := HFlowContainer.new()
		chip_row.add_theme_constant_override("h_separation", 5)
		chip_row.add_theme_constant_override("v_separation", 4)
		chip_row.name = "BuildChipRow"
		chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var content := VBoxContainer.new()
	content.name = "WeaponCoreContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", TOKENS.SPACE_2)

	var acquisition_section := VBoxContainer.new()
	acquisition_section.name = "WeaponCoreAcquisitionSection"
	acquisition_section.add_theme_constant_override("separation", TOKENS.SPACE_1)
	content.add_child(acquisition_section)

	var source_name := str(card_data.get("source_weapon_name", "")).strip_edges()
	var title := _make_card_label(
		LocalizationManager.tr_format(
			"ui.reward.core.named_title",
			{"name": source_name},
			"%s Core" % source_name
		),
		19,
		TOKENS.COLOR_TEXT_PRIMARY
	)
	title.name = "WeaponCoreTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acquisition_section.add_child(title)

	var icon_stage := CenterContainer.new()
	icon_stage.name = "WeaponCoreIconStage"
	icon_stage.custom_minimum_size = Vector2(0.0, 76.0)
	icon_stage.add_child(_build_weapon_core_icon(card_data))
	acquisition_section.add_child(icon_stage)

	var source_label := _make_card_label(
		LocalizationManager.tr_format("ui.reward.core.source", {"name": source_name}, "Source: %s" % source_name),
		13,
		TOKENS.COLOR_TEXT_SECONDARY
	)
	source_label.name = "WeaponCoreSource"
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_label.max_lines_visible = 2
	source_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	source_label.visible = false
	acquisition_section.add_child(source_label)

	var amount := int(card_data.get("core_amount", 1))
	var dismantled_label := _make_card_label(
		LocalizationManager.tr_format(
			"ui.reward.core.gain",
			{"amount": amount},
			"+%d Core" % amount
		),
		18,
		CORE_MATERIAL_COLOR
	)
	dismantled_label.name = "WeaponCoreGain"
	dismantled_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_configure_wrapped_card_text(dismantled_label)
	acquisition_section.add_child(dismantled_label)

	var inventory_status := PanelContainer.new()
	inventory_status.name = "WeaponCoreInventoryStatus"
	inventory_status.custom_minimum_size = Vector2(0.0, 30.0)
	inventory_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inventory_status_style := StyleBoxFlat.new()
	inventory_status_style.bg_color = Color(CORE_MATERIAL_SURFACE.r, CORE_MATERIAL_SURFACE.g, CORE_MATERIAL_SURFACE.b, 0.72)
	inventory_status_style.border_color = Color(CORE_MATERIAL_COLOR.r, CORE_MATERIAL_COLOR.g, CORE_MATERIAL_COLOR.b, 0.48)
	inventory_status_style.set_border_width_all(TOKENS.BORDER_THIN)
	inventory_status_style.set_corner_radius_all(TOKENS.RADIUS_SMALL)
	inventory_status_style.content_margin_left = TOKENS.SPACE_2
	inventory_status_style.content_margin_right = TOKENS.SPACE_2
	inventory_status_style.content_margin_top = TOKENS.SPACE_1
	inventory_status_style.content_margin_bottom = TOKENS.SPACE_1
	inventory_status.add_theme_stylebox_override("panel", inventory_status_style)
	var inventory_label := _make_card_label(
		LocalizationManager.tr_format(
			"ui.reward.core.inventory",
			{
				"current": int(card_data.get("current_core_count", 0)),
				"resulting": int(card_data.get("resulting_core_count", amount)),
			},
			"Inventory: %d → %d" % [
				int(card_data.get("current_core_count", 0)),
				int(card_data.get("resulting_core_count", amount)),
			]
		),
		13,
		TOKENS.COLOR_TEXT_SECONDARY
	)
	inventory_label.name = "WeaponCoreInventory"
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_label.max_lines_visible = 2
	inventory_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	inventory_status.set_meta(&"current_count", int(card_data.get("current_core_count", 0)))
	inventory_status.set_meta(&"resulting_count", int(card_data.get("resulting_core_count", amount)))
	inventory_status.add_child(inventory_label)
	acquisition_section.add_child(inventory_status)

	var inheritance_section := VBoxContainer.new()
	inheritance_section.name = "WeaponCoreInheritanceSection"
	inheritance_section.add_theme_constant_override("separation", TOKENS.SPACE_1)
	content.add_child(inheritance_section)

	var tag_heading := _make_card_label(
		LocalizationManager.tr_key("ui.reward.core.inherited_tags", "INHERITED CORE TAGS"),
		11,
		TOKENS.COLOR_TEXT_SECONDARY
	)
	tag_heading.name = "CoreTagHeading"
	inheritance_section.add_child(tag_heading)

	var chip_grid := GridContainer.new()
	chip_grid.name = "BuildChipRow"
	chip_grid.columns = 2
	chip_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_grid.add_theme_constant_override("h_separation", 5)
	chip_grid.add_theme_constant_override("v_separation", 4)
	BUILD_TAG_DISPLAY.populate_chip_row(chip_grid, card_data.get("chips", []))
	inheritance_section.add_child(chip_grid)

	var usage_panel := PanelContainer.new()
	usage_panel.name = "WeaponCoreUsagePanel"
	usage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	usage_panel.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	var usage_panel_style := StyleBoxFlat.new()
	usage_panel_style.bg_color = Color(CORE_MATERIAL_SURFACE.r, CORE_MATERIAL_SURFACE.g, CORE_MATERIAL_SURFACE.b, 0.58)
	usage_panel_style.border_color = Color(CORE_MATERIAL_COLOR.r, CORE_MATERIAL_COLOR.g, CORE_MATERIAL_COLOR.b, 0.52)
	usage_panel_style.set_border_width_all(TOKENS.BORDER_THIN)
	usage_panel_style.set_corner_radius_all(TOKENS.RADIUS_PANEL)
	usage_panel_style.content_margin_left = TOKENS.SPACE_2
	usage_panel_style.content_margin_right = TOKENS.SPACE_2
	usage_panel_style.content_margin_top = 6
	usage_panel_style.content_margin_bottom = 6
	usage_panel.add_theme_stylebox_override("panel", usage_panel_style)
	usage_panel.add_child(_build_weapon_core_usage_section(card_data))
	content.add_child(usage_panel)
	return content

func _build_weapon_core_icon(card_data: Dictionary) -> Control:
	var root := Control.new()
	root.name = "WeaponCoreMaterialIcon"
	root.custom_minimum_size = Vector2(104.0, 72.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	frame.name = "WeaponCoreMaterialFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = CORE_MATERIAL_SURFACE
	frame_style.border_color = CORE_MATERIAL_COLOR
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(TOKENS.RADIUS_PANEL)
	frame.add_theme_stylebox_override("panel", frame_style)
	root.add_child(frame)
	var source_texture := card_data.get("source_weapon_icon", null) as Texture2D
	if source_texture != null:
		var source_icon := TextureRect.new()
		source_icon.name = "WeaponCoreSourceImage"
		source_icon.texture = _crop_reward_texture_to_content(source_texture)
		source_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		source_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		source_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		source_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		root.add_child(source_icon)
	var core_mark := Label.new()
	core_mark.name = "WeaponCoreMark"
	core_mark.text = "◆"
	core_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	core_mark.add_theme_font_size_override("font_size", 15)
	core_mark.add_theme_color_override("font_color", Color(1.0, 0.79, 0.32, 1.0))
	core_mark.add_theme_stylebox_override("normal", _make_icon_badge_style(CORE_MATERIAL_COLOR))
	core_mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	core_mark.offset_left = -25.0
	core_mark.offset_top = -25.0
	core_mark.offset_right = -3.0
	core_mark.offset_bottom = -3.0
	root.add_child(core_mark)
	return root

func _build_weapon_core_usage_section(card_data: Dictionary) -> VBoxContainer:
	var usage_section := VBoxContainer.new()
	usage_section.name = "WeaponCoreUsageSection"
	usage_section.add_theme_constant_override("separation", 2)
	var usage_heading_row := HBoxContainer.new()
	usage_heading_row.name = "WeaponCoreUsageHeadingRow"
	usage_heading_row.add_theme_constant_override("separation", 6)
	usage_section.add_child(usage_heading_row)
	var usage_icon := _make_card_label("↗", 12, CORE_MATERIAL_COLOR)
	usage_icon.name = "WeaponCoreUsageIcon"
	usage_icon.custom_minimum_size = Vector2(22.0, 22.0)
	usage_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	usage_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	usage_icon.add_theme_stylebox_override("normal", _make_icon_badge_style(CORE_MATERIAL_COLOR))
	usage_heading_row.add_child(usage_icon)
	var usage_heading := _make_card_label(
		LocalizationManager.tr_key("ui.reward.core.usable_by_label", "Usable By"),
		11,
		TOKENS.COLOR_TEXT_SECONDARY
	)
	usage_heading.name = "WeaponCoreUsageHeading"
	usage_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	usage_heading_row.add_child(usage_heading)
	var usage_lines: PackedStringArray = card_data.get("usable_branch_lines", PackedStringArray())
	if not usage_lines.is_empty():
		var usage_summary := _make_card_label(
			LocalizationManager.tr_format(
				"ui.reward.core.usage_summary",
				{"count": int(card_data.get("usable_branch_count", usage_lines.size()))},
				"Supports %d fusion branches" % int(card_data.get("usable_branch_count", usage_lines.size()))
			),
			13,
			CORE_MATERIAL_COLOR
		)
		usage_summary.name = "WeaponCoreUsageSummary"
		usage_section.add_child(usage_summary)
	for usage_index in range(mini(2, usage_lines.size())):
		var usage_line := usage_lines[usage_index]
		var usage_label := _make_card_label(str(usage_line), 13, TOKENS.COLOR_TEXT_PRIMARY)
		usage_label.name = "WeaponCoreUsageLine%d" % (usage_index + 1)
		usage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		usage_label.max_lines_visible = 2
		usage_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		usage_section.add_child(usage_label)
	if usage_lines.size() > 2:
		var more_label := _make_card_label(
			LocalizationManager.tr_format(
				"ui.reward.core.more_usages",
				{"count": usage_lines.size() - 2},
				"%d more" % (usage_lines.size() - 2)
			),
			11,
			TOKENS.COLOR_TEXT_SECONDARY
		)
		more_label.name = "WeaponCoreUsageMore"
		usage_section.add_child(more_label)
	elif usage_lines.is_empty():
		var empty_label := _make_card_label(
			LocalizationManager.tr_key(
				"ui.reward.core.no_usable_branches",
				"No available fusion recipes found yet"
			),
			12,
			TOKENS.COLOR_TEXT_SECONDARY
		)
		empty_label.name = "WeaponCoreUsageEmpty"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.max_lines_visible = 2
		usage_section.add_child(empty_label)
	return usage_section

func _build_core_weapon_stats(card_data: Dictionary) -> HBoxContainer:
	var stats_box := HBoxContainer.new()
	stats_box.name = "CoreWeaponStats"
	stats_box.custom_minimum_size = Vector2(0.0, 42.0)
	stats_box.add_theme_constant_override("separation", 6)
	var lines: PackedStringArray = card_data.get("core_stat_lines", PackedStringArray())
	var slot_names: Array[StringName] = [&"Damage", &"FireInterval", &"Ammo"]
	var core_keys: Array[StringName] = [&"damage", &"fire_interval_sec", &"ammo"]
	for index in range(3):
		var fallback_key: StringName = core_keys[index]
		var text := str(lines[index]) if index < lines.size() else WEAPON_STAT_FORMATTER.format_line(fallback_key, null, " ")
		var separator_index := text.find(" ")
		var heading_text := text.left(separator_index) if separator_index >= 0 else WEAPON_STAT_FORMATTER.format_label(fallback_key)
		var value_text := text.substr(separator_index + 1) if separator_index >= 0 else "--"
		var slot := VBoxContainer.new()
		slot.name = "CoreStat%s" % str(slot_names[index])
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_constant_override("separation", 0)
		var heading := _make_card_label(heading_text, 11, Color(0.60, 0.74, 0.80, 1.0))
		heading.name = "Heading"
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var value := _make_card_label(value_text, 14, TOKENS.COLOR_TEXT_PRIMARY)
		value.name = "Value"
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.max_lines_visible = 2
		value.custom_minimum_size.x = 0.0
		value.tooltip_text = value_text
		slot.add_child(heading)
		slot.add_child(value)
		stats_box.add_child(slot)
	return stats_box

func _build_weapon_reward_hero(card_data: Dictionary) -> CenterContainer:
	var hero := CenterContainer.new()
	hero.name = "WeaponRewardHero"
	hero.custom_minimum_size = Vector2(0.0, 80.0)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _make_reward_icon(card_data, Vector2(132.0, 76.0), 6)
	icon.name = "WeaponHeroImage"
	hero.add_child(icon)
	return hero

func _build_weapon_preview_section(preview: Dictionary, reward_index: int) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "WeaponBuildPreview"
	section.custom_minimum_size = Vector2(0.0, 100.0)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 3)
	var branch_heading_row := HBoxContainer.new()
	branch_heading_row.add_theme_constant_override("separation", 6)
	section.add_child(branch_heading_row)
	var branch_heading := _make_card_label(_inline_text("BRANCH PREVIEW", "分支预览"), 12, TOKENS.COLOR_TEXT_SECONDARY)
	branch_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branch_heading_row.add_child(branch_heading)
	var branch_row := HBoxContainer.new()
	branch_row.name = "BranchPreviewRow"
	branch_row.add_theme_constant_override("separation", 6)
	branch_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branch_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_configure_weapon_detail_hotspot(branch_row, reward_index)
	section.add_child(branch_row)
	for branch_variant in preview.get("branches", []):
		branch_row.add_child(_build_branch_preview_node(branch_variant as Dictionary))
	return section

func _build_branch_preview_node(branch: Dictionary) -> PanelContainer:
	var damage_types: Array = branch.get("damage_types", [])
	var state := StringName(branch.get("state", &"locked"))
	var panel_node := PanelContainer.new()
	panel_node.name = "BranchPreviewNode"
	panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_node.custom_minimum_size = Vector2(0.0, 60.0)
	panel_node.add_theme_stylebox_override("panel", _branch_style(damage_types, state, 0.11))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	panel_node.add_child(content)
	var title_offset := Control.new()
	title_offset.name = "BranchPreviewTitleOffset"
	title_offset.custom_minimum_size.y = 3.0
	content.add_child(title_offset)
	var title_row := HBoxContainer.new()
	title_row.name = "BranchPreviewTitleRow"
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 4)
	content.add_child(title_row)
	var branch_icon_slot_size := 18.0 if damage_types.size() > 1 else 20.0
	var icon_row := _build_damage_type_icon_row(
		damage_types,
		branch_icon_slot_size,
		"BranchDamageTypeIcons"
	)
	if icon_row.get_child_count() > 0:
		title_row.add_child(icon_row)
	var branch_name := str(branch.get("name", "Branch"))
	var name_label := _make_card_label(branch_name, 13, _branch_primary_color(damage_types))
	name_label.name = "BranchPreviewName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = branch_name
	title_row.add_child(name_label)
	var top_spacer := Control.new()
	top_spacer.name = "BranchPreviewTopSpacer"
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(top_spacer)
	var recipe := _build_branch_fusion_recipe(branch, damage_types)
	recipe.name = "BranchPreviewFusionRecipe"
	content.add_child(recipe)
	var bottom_spacer := Control.new()
	bottom_spacer.name = "BranchPreviewBottomSpacer"
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(bottom_spacer)
	var status_label := _make_card_label(_branch_state_short(state), 10, TOKENS.COLOR_TEXT_SECONDARY)
	status_label.name = "BranchPreviewUnlockState"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(status_label)
	_add_branch_accent_strip(panel_node, damage_types)
	return panel_node

func _build_damage_type_icon_row(damage_types: Array, icon_size: float, row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	for type_variant in damage_types.slice(0, 2):
		var damage_type := Attack.normalize_damage_type(type_variant)
		var texture := DAMAGE_TYPE_ICONS.get(damage_type) as Texture2D
		if texture == null:
			continue
		var slot := PanelContainer.new()
		slot.name = "DamageTypeSlot%s" % str(damage_type).capitalize()
		slot.custom_minimum_size = Vector2.ONE * icon_size
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.018, 0.031, 0.043, 0.98)
		var damage_color := WEAPON_PREVIEW_DATA.damage_color(damage_type)
		slot_style.border_color = Color(damage_color.r, damage_color.g, damage_color.b, 0.82)
		slot_style.set_border_width_all(1)
		slot_style.set_corner_radius_all(3)
		slot_style.set_content_margin_all(1.0)
		slot.add_theme_stylebox_override("panel", slot_style)
		var icon := TextureRect.new()
		icon.name = "DamageType%s" % str(damage_type).capitalize()
		icon.texture = texture
		icon.custom_minimum_size = Vector2.ONE * (icon_size - 2.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		row.add_child(slot)
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
	var overlay := PanelContainer.new()
	overlay.name = "WeaponBranchDetailOverlay"
	overlay.visible = false
	overlay.z_index = 20
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_TOP_WIDE)
	overlay.offset_left = 8.0
	overlay.offset_top = 44.0
	overlay.offset_right = -8.0
	overlay.offset_bottom = 314.0
	var style := TOKENS.make_panel_style(true, Color(0.36, 0.82, 0.94, 0.86))
	style.bg_color = Color(0.025, 0.040, 0.052, 0.985)
	style.content_margin_left = 10
	style.content_margin_top = 9
	style.content_margin_right = 10
	style.content_margin_bottom = 9
	overlay.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	overlay.add_child(content)
	var heading := _make_card_label(_inline_text("WEAPON BRANCH DETAILS", "武器分支详情"), 14, TOKENS.COLOR_TEXT_SECONDARY)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(row)
	for branch_variant in preview.get("branches", []):
		row.add_child(_build_branch_detail_card(branch_variant as Dictionary))
	overlay.mouse_entered.connect(Callable(self, "_on_detail_overlay_mouse_entered").bind(reward_index))
	overlay.mouse_exited.connect(Callable(self, "_on_detail_overlay_mouse_exited").bind(reward_index))
	return overlay

func _build_branch_detail_card(branch: Dictionary) -> PanelContainer:
	var damage_types: Array = branch.get("damage_types", [])
	var state := StringName(branch.get("state", &"locked"))
	var card := PanelContainer.new()
	card.name = "BranchDetailCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _branch_style(damage_types, state, 0.08))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var name_label := _make_card_label(str(branch.get("name", "Branch")), 15, _branch_primary_color(damage_types))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var type_label := _make_card_label(_damage_type_text(damage_types), 11, _branch_primary_color(damage_types))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_damage_icons_to_label(type_label, damage_types, 14.0, "BranchDetailDamageTypeIcons", 4.0)
	box.add_child(type_label)
	var description := _make_card_label(str(branch.get("description", "")), 12, TOKENS.COLOR_TEXT_PRIMARY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 5
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(description)
	box.add_child(_build_branch_fusion_recipe(branch, damage_types))
	_add_branch_accent_strip(card, damage_types)
	return card

func _branch_style(_damage_types: Array, state: StringName, _background_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TOKENS.COLOR_SURFACE_INTERACTIVE if state == &"acquired" else TOKENS.COLOR_SURFACE
	style.border_color = Color(TOKENS.COLOR_BORDER.r, TOKENS.COLOR_BORDER.g, TOKENS.COLOR_BORDER.b, 0.44)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	return style

func _add_branch_accent_strip(parent: Control, damage_types: Array) -> void:
	if damage_types.is_empty():
		return
	var overlay := Control.new()
	overlay.name = "BranchAccentStripOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	var strip := HBoxContainer.new()
	strip.name = "BranchAccentStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_left = 5
	strip.offset_top = 2
	strip.offset_right = -5
	strip.offset_bottom = 4
	strip.add_theme_constant_override("separation", 0)
	for type_variant in damage_types.slice(0, 2):
		var segment := ColorRect.new()
		segment.color = WEAPON_PREVIEW_DATA.damage_color(StringName(type_variant))
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(segment)
	overlay.add_child(strip)

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
	var recipe_row := HBoxContainer.new()
	recipe_row.name = "BranchFusionRecipe"
	recipe_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_row.add_theme_constant_override("separation", 6)
	var fuse := int(branch.get("unlock_fuse", 2))
	var prefix := _make_card_label(_inline_text("Fuse %d:" % fuse, "融合 %d：" % fuse), 11, TOKENS.COLOR_TEXT_SECONDARY)
	prefix.name = "FusionRecipePrefix"
	prefix.custom_minimum_size.x = 54.0
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recipe_row.add_child(prefix)
	var conditions := VBoxContainer.new()
	conditions.name = "FusionRecipeConditions"
	conditions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conditions.add_theme_constant_override("separation", 0)
	recipe_row.add_child(conditions)
	var satisfied_tags: Array = branch.get("satisfied_fusion_tags", [])
	var satisfied_color := _branch_primary_color(damage_types)
	for tag_variant in branch.get("fusion_required_tags", []):
		var tag := StringName(tag_variant)
		var tag_text := LocalizationManager.get_module_term(tag, str(tag).replace("_", " ").capitalize())
		var tag_label := _make_card_label("【%s】" % tag_text, 11, satisfied_color if satisfied_tags.has(tag) else TOKENS.COLOR_TEXT_SECONDARY)
		tag_label.name = "FusionRecipeTag%s" % str(tag).to_pascal_case()
		tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tag_label.set_meta(&"satisfied", satisfied_tags.has(tag))
		conditions.add_child(tag_label)
	return recipe_row

func _inline_text(english: String, chinese: String) -> String:
	return chinese if LocalizationManager.get_locale() == "zh_CN" else english

func _build_module_weapon_grid(card_data: Dictionary) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "CompatibleWeaponsSection"
	section.custom_minimum_size.y = 120.0
	section.add_theme_constant_override("separation", 5)
	var previews: Array = card_data.get("compatible_weapons", [])
	var owned_count := int(card_data.get("owned_weapon_count", 0))
	var top_spacer := Control.new()
	top_spacer.name = "ModuleFitTopSpacer"
	top_spacer.custom_minimum_size.y = 3.0
	section.add_child(top_spacer)
	var heading_row := HBoxContainer.new()
	section.add_child(heading_row)
	var heading := _make_card_label(LocalizationManager.tr_key("ui.module.fit.title", "Fit Check"), 13, TOKENS.COLOR_TEXT_SECONDARY)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	var compatible_count := 0
	for preview_variant in previews:
		if bool((preview_variant as Dictionary).get("compatible", true)):
			compatible_count += 1
	var count_text := _inline_text(
		"Equippable %d/%d" % [compatible_count, owned_count],
		"可装备 %d/%d" % [compatible_count, owned_count]
	)
	var count_label := _make_card_label(count_text, 13, Color(0.72, 0.84, 0.88, 1.0))
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
	var compatible := bool(preview.get("compatible", true))
	var has_slot := bool(preview.get("has_slot", not bool(preview.get("requires_replace", false))))
	var state_color := Color(0.40, 0.86, 0.57, 1.0)
	if not compatible:
		state_color = Color(1.0, 0.34, 0.28, 1.0)
	elif not has_slot:
		state_color = Color(0.95, 0.74, 0.30, 1.0)
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
	var status_label := _make_card_label(status_icon + status_text, 11, state_color)
	status_label.name = "WeaponFitStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.tooltip_text = status_text
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

func _make_icon_frame_style(_accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TOKENS.COLOR_SURFACE_ELEVATED
	style.border_color = TOKENS.COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(TOKENS.RADIUS_PANEL)
	return style

func _make_icon_badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.92)
	style.border_color = Color(0.04, 0.05, 0.06, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(TOKENS.RADIUS_PANEL)
	return style

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
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size + CARD_FONT_SIZE_BONUS)
	label.add_theme_constant_override("line_spacing", CARD_LINE_SPACING)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_highlighted_module_summary(summary_text: String) -> RichTextLabel:
	var summary := RichTextLabel.new()
	summary.name = "ModuleEffectSummary"
	summary.bbcode_enabled = true
	summary.fit_content = true
	summary.scroll_active = false
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("normal_font_size", TOKENS.FONT_LABEL + CARD_FONT_SIZE_BONUS)
	summary.add_theme_font_size_override("bold_font_size", TOKENS.FONT_LABEL + CARD_FONT_SIZE_BONUS)
	summary.add_theme_color_override("default_color", TOKENS.COLOR_TEXT_PRIMARY)
	summary.add_theme_constant_override("line_separation", CARD_LINE_SPACING)
	var escaped := summary_text.replace("[", "[lb]").replace("]", "[rb]")
	var number_pattern := RegEx.new()
	number_pattern.compile("([+-]?\\d+(?:\\.\\d+)?(?:%|\\+)?)")
	var accent_hex := TOKENS.COLOR_ACCENT_SYSTEM.to_html(false)
	summary.text = number_pattern.sub(escaped, "[color=#%s][b]$1[/b][/color]" % accent_hex, true)
	return summary

func _configure_wrapped_card_text(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

func _make_badge_label(text: String, color: Color) -> Label:
	var label := _make_card_label(text, TOKENS.FONT_LABEL, TOKENS.COLOR_TEXT_PRIMARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.custom_minimum_size = Vector2(54.0, 22.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.22)
	style.border_color = Color(color.r, color.g, color.b, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(TOKENS.RADIUS_SMALL)
	style.content_margin_left = 6
	style.content_margin_right = 6
	label.add_theme_stylebox_override("normal", style)
	return label

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
		style.set_corner_radius_all(TOKENS.RADIUS_SMALL)
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
