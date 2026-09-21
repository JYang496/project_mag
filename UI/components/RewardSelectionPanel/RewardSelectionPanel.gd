extends Control

const REWARD_CARD_SCENE := preload("res://UI/components/RewardCard/RewardCard.tscn")
const REWARD_PROMPT_TEXT_SCENE := preload("res://UI/components/RewardPromptText/RewardPromptText.tscn")
const INPUT_PROMPT_ICON_SCENE := preload("res://UI/components/InputPromptIcon/InputPromptIcon.tscn")
const INPUT_PROMPT_GROUP_SCENE := preload("res://UI/components/InputPromptGroup/InputPromptGroup.tscn")
signal reward_confirmed(reward: RewardInfo)
signal selection_cancelled

const REWARD_CARD_MODEL_BUILDER := preload("res://UI/scripts/presentation/reward_card_model_builder.gd")
const REWARD_CARD_DATA_ASSEMBLER := preload("res://UI/scripts/presentation/reward_card_data_assembler.gd")
const TOKENS := preload("res://UI/themes/ui_design_tokens.gd")
const INPUT_PROMPT_ATLAS := preload("res://asset/images/ui/input_prompts/kenney_pixel/input_prompts_tilemap.png")
const INPUT_PROMPT_TEXTURE_FACTORY := preload("res://UI/scripts/components/input_prompt_texture_factory.gd")
const INPUT_PROMPT_TILE_SIZE := 16
const INPUT_PROMPT_TILE_STRIDE := 17
const INPUT_PROMPT_DISPLAY_SIZE := 32.0
const SPACE_PROMPT_DISPLAY_WIDTH := 72
const QUICK_SELECT_HOLD_SECONDS := 0.55
const ENTRY_FADE_DURATION := 0.15
const ENTRY_SLIDE_DURATION := 0.50
const ENTRY_DELAY := 0.08
const ENTRY_REBOUND_DURATION := 0.08
const ENTRY_OVERSHOOT := 28.0
const ENTRY_OFFSCREEN_MARGIN := 60.0
const CARD_SELECTION_PULSE_SCALE := Vector2(1.012, 1.012)
const CORE_MATERIAL_COLOR := Color(0.94, 0.58, 0.18, 1.0)
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
var _entry_generation := 0
var _held_quick_select_index := -1
var _held_quick_select_elapsed := 0.0
var _synergy_evaluator: Callable = Callable()
var _reward_data_assembler: RefCounted
var _card_factory: RewardCardFactory
var _detail_controller: RewardDetailController
@onready var _detail_open_timer: Timer = $DetailOpenTimer
@onready var _detail_close_timer: Timer = $DetailCloseTimer
var _using_gamepad := false
var _gamepad_device_id := 0
var _supply_viewport: SubViewport
var _supply_grid: GridContainer
var _supply_cards: Array[Button] = []
var _prepared_supply_rewards: Array[RewardInfo] = []
var _supply_prepare_generation := 0

func _ensure_supply_staging() -> void:
	if _supply_viewport != null:
		return
	_supply_viewport = SubViewport.new()
	_supply_viewport.name = "SupplyCardWarmup"
	_supply_viewport.size = Vector2i(952, 500)
	_supply_viewport.disable_3d = true
	_supply_viewport.world_2d = World2D.new()
	_supply_viewport.transparent_bg = true
	_supply_viewport.gui_disable_input = true
	_supply_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_supply_viewport)
	_supply_grid = GridContainer.new()
	_supply_grid.theme = preload("res://UI/themes/global_ui_theme.tres")
	_supply_grid.columns = 3
	_supply_grid.size = Vector2(952, 500)
	_supply_grid.add_theme_constant_override("h_separation", 12)
	_supply_grid.add_theme_constant_override("v_separation", 12)
	_supply_viewport.add_child(_supply_grid)

func invalidate_prepared_supply() -> void:
	_supply_prepare_generation += 1
	_prepared_supply_rewards.clear()
	if _supply_viewport != null:
		_supply_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func has_prepared_supply(rewards: Array[RewardInfo]) -> bool:
	return not rewards.is_empty() and _prepared_supply_rewards == rewards

func prepare_supply_cards(rewards: Array[RewardInfo], still_current: Callable) -> bool:
	if visible or rewards.is_empty():
		return false
	_ensure_supply_staging()
	invalidate_prepared_supply()
	var generation := _supply_prepare_generation
	for child in options_box.get_children():
		if child in _supply_cards:
			child.reparent(_supply_grid, false)
		else:
			options_box.remove_child(child)
			child.queue_free()
		await get_tree().process_frame
		if visible or generation != _supply_prepare_generation or not still_current.is_valid() or not bool(still_current.call()):
			return false
	for index in range(rewards.size()):
		if visible or generation != _supply_prepare_generation or not still_current.is_valid() or not bool(still_current.call()):
			return false
		var button: Button
		if index < _supply_cards.size():
			button = _supply_cards[index]
			if button.get_parent() != _supply_grid:
				button.reparent(_supply_grid, false)
			_reset_supply_card(button)
		else:
			button = REWARD_CARD_SCENE.instantiate() as Button
			_supply_cards.append(button)
			_supply_grid.add_child(button)
			_connect_card_inputs(button, index)
		button.visible = true
		_build_reward_card_button(rewards[index], index, button)
		# Never allocate all three cards in the claim input frame.
		await get_tree().process_frame
	for index in range(rewards.size(), _supply_cards.size()):
		_supply_cards[index].visible = false
	_supply_grid.columns = mini(3, rewards.size())
	_supply_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Headless rendering has no guaranteed draw callback. Yield frames rather
	# than awaiting frame_post_draw, which could strand settlement there.
	for frame in range(3):
		await get_tree().process_frame
		if visible or generation != _supply_prepare_generation or not still_current.is_valid() or not bool(still_current.call()):
			_supply_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			return false
	_supply_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_prepared_supply_rewards.assign(rewards)
	return true

func _reset_supply_card(button: Button) -> void:
	if button.has_meta(&"reward_motion_tween"):
		var tween := button.get_meta(&"reward_motion_tween") as Tween
		if tween != null:
			tween.kill()
		button.remove_meta(&"reward_motion_tween")
	button.set_meta(&"reward_was_selected", false)
	button.scale = Vector2.ONE
	button.button_pressed = false
	(button.get_node("CardContentMargin/Body/HoldProgress") as ProgressBar).value = 0.0
	var body := button.get_node("CardContentMargin/Body")
	for child in body.get_children():
		if child.name != "HoldProgress":
			body.remove_child(child)
			child.queue_free()
	for child in button.get_children():
		if child.name not in ["CardWellArt", "CardFrameArt", "CardHeaderMargin", "CardContentMargin", "SelectionIndicatorBar", "SelectedStripArt"]:
			button.remove_child(child)
			child.queue_free()

func _connect_card_inputs(button: Button, index: int) -> void:
	button.pressed.connect(_on_reward_button_pressed.bind(index, button))
	button.focus_entered.connect(_on_reward_card_focus_entered.bind(index, button))
	button.mouse_entered.connect(_on_reward_card_mouse_entered.bind(index, button))
	button.mouse_exited.connect(_on_reward_card_mouse_exited.bind(index, button))

func prewarm_supply_visuals() -> void:
	_ensure_supply_staging()
	for id in DataHandler.get_weapon_ids():
		var definition := DataHandler.read_weapon_data(id) as WeaponDefinition
		if definition != null and definition.icon != null:
			_crop_reward_texture_to_content(definition.icon)
		await get_tree().process_frame
	# Cover the component families while the loading overlay is present. Actual
	# candidates are rendered again after their dynamic inventory data is known.
	var definition := DataHandler.read_weapon_data("1") as WeaponDefinition
	if definition == null:
		return
	var samples: Array[RewardInfo] = []
	var weapon := RewardInfo.new()
	weapon.item_id = definition.weapon_id
	samples.append(weapon)
	var upgrade := RewardInfo.new()
	upgrade.reward_kind = RewardInfo.KIND_WEAPON_UPGRADE
	upgrade.target_weapon_id = definition.weapon_id
	upgrade.target_weapon_from_level = 1
	upgrade.target_weapon_to_level = 2
	samples.append(upgrade)
	var core := RewardInfo.new()
	core.reward_kind = RewardInfo.KIND_WEAPON_CORE
	core.item_id = definition.weapon_id
	core.core_tags = definition.get_normalized_core_tags()
	core.core_amount = 1
	samples.append(core)
	await prepare_supply_cards(samples, func() -> bool: return not visible)
	var paths := ModuleOfferCatalog.get_all_scene_paths()
	if not paths.is_empty():
		var module := RewardInfo.new()
		module.module_scene = load(paths[0]) as PackedScene
		samples[0] = module
		await prepare_supply_cards(samples, func() -> bool: return not visible)
	title_label.text = LocalizationManager.tr_key("ui.supply.title", "Gold Supply")
	subtitle_label.text = LocalizationManager.tr_key("ui.supply.hint", "Claim one supply. Combat pauses while choosing.")
	confirm_button.text = LocalizationManager.tr_key("ui.reward.confirm", "Confirm Reward")
	cancel_button.text = LocalizationManager.tr_key("ui.panel.cancel", "Cancel")
	var labels: Array[Control] = [title_label, subtitle_label, confirm_button, cancel_button]
	await warm_supply_controls(labels, func() -> bool: return not visible)
	invalidate_prepared_supply()

func warm_supply_controls(controls: Array[Control], still_current: Callable) -> bool:
	_ensure_supply_staging()
	var host := VBoxContainer.new()
	host.theme = _supply_grid.theme
	host.size = Vector2(952, 500)
	_supply_viewport.add_child(host)
	_supply_grid.visible = false
	for control in controls:
		# Render property-only copies: an unrelated modal can open during this
		# warmup without temporarily losing its live controls or callbacks.
		host.add_child(control.duplicate(0))
	_supply_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ready := true
	for frame in range(3):
		await get_tree().process_frame
		if not still_current.is_valid() or not bool(still_current.call()):
			ready = false
			break
	_supply_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.queue_free()
	_supply_grid.visible = true
	return ready

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
	_kill_entry_tween()
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
	if _get_detail_controller().open_index >= 0 and ModalUiController.is_cancel_input(event):
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
	if is_instance_valid(GlobalVariables.ui) and GlobalVariables.ui.has_method("is_supply_modal_open") and GlobalVariables.ui.is_supply_modal_open():
		if reward_options.is_empty() or reward_options[0].source_id != &"gold_supply":
			return false
	if reward_options.is_empty():
		return false
	if visible:
		return false
	if _summary_mode or not has_prepared_supply(reward_options):
		invalidate_prepared_supply()
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
	_get_detail_controller().reset()
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
		if child in _supply_cards:
			_supply_grid.add_child(child)
		else:
			child.queue_free()
	var incoming_options := reward_options.duplicate()
	for reward in incoming_options.slice(0, 3):
		if reward == null:
			continue
		_reward_options.append(reward)
	if _reward_options.is_empty():
		return false
	var use_prepared := has_prepared_supply(_reward_options)
	for idx in range(_reward_options.size()):
		var button := _supply_cards[idx] if use_prepared else _build_reward_card_button(_reward_options[idx], idx)
		if use_prepared:
			button.reparent(options_box, false)
		else:
			_connect_card_inputs(button, idx)
			options_box.add_child(button)
	if options_box.get_child_count() > 0:
		var first := options_box.get_child(0) as Button
		if first:
			_on_reward_button_pressed(0, first)
	_update_grid_columns()
	_configure_card_focus_chain()
	_confirm_button_state()
	visible = true
	var victory_transition := _get_active_victory_transition()
	if victory_transition != null and not bool(victory_transition.call("has_exit_started")):
		modulate.a = 0.0
		_reveal_after_victory_exit(victory_transition)
	else:
		_reveal_prepared_rewards()
	return true

func _get_active_victory_transition() -> Control:
	var ui := GlobalVariables.ui
	if ui == null or not is_instance_valid(ui):
		return null
	var transition = ui.get("victory_transition")
	if transition == null or not is_instance_valid(transition):
		return null
	if not transition.has_method("is_playing") or not bool(transition.call("is_playing")):
		return null
	if not transition.has_method("has_exit_started"):
		return null
	return transition as Control

func _reveal_after_victory_exit(victory_transition: Control) -> void:
	await victory_transition.exit_started
	if not visible:
		return
	_reveal_prepared_rewards()

func _reveal_prepared_rewards() -> void:
	_set_battle_hud_suppressed(true)
	if options_box.get_child_count() > 0:
		(options_box.get_child(0) as Button).grab_focus()
	_play_entry_animation()

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
	_get_detail_controller().reset()
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
	var generation := _entry_generation
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE
	var settled_position := panel.position
	var enter_start := Vector2(-panel.size.x - ENTRY_OFFSCREEN_MARGIN, settled_position.y)
	var overshoot := settled_position + Vector2(ENTRY_OVERSHOOT, 0.0)
	panel.position = enter_start
	# Cards are already prepared. Only wait for the deferred container layout
	# after reparenting; the old three-frame preparation catch-up is unnecessary.
	await get_tree().process_frame
	if generation != _entry_generation or not visible:
		return
	panel.position = enter_start
	_entry_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_entry_tween.set_ignore_time_scale(true)
	_entry_tween.tween_property(self, "modulate:a", 1.0, ENTRY_FADE_DURATION)
	_entry_tween.parallel().tween_property(panel, "position", overshoot, ENTRY_SLIDE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(ENTRY_DELAY)
	_entry_tween.tween_property(panel, "position", settled_position, ENTRY_REBOUND_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _kill_entry_tween() -> void:
	_entry_generation += 1
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
	if _get_detail_controller().open_index >= 0 and index != _get_detail_controller().open_index:
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
	var detail_is_open := _get_detail_controller().open_index >= 0
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

func _build_reward_card_model(reward: RewardInfo):
	var synergy_result: Dictionary = {}
	if _synergy_evaluator.is_valid():
		var evaluated: Variant = _synergy_evaluator.call(reward)
		if evaluated is Dictionary: synergy_result = evaluated
	elif reward != null and reward.has_meta("synergy_evaluation"):
		var metadata: Variant = reward.get_meta("synergy_evaluation")
		if metadata is Dictionary: synergy_result = metadata
	return REWARD_CARD_MODEL_BUILDER.build(_build_reward_display_data(reward), synergy_result)

func _build_reward_card_data(reward: RewardInfo) -> Dictionary:
	return _get_reward_data_assembler()._build_reward_card_data(reward)

func _build_reward_display_data(reward: RewardInfo) -> Dictionary:
	return _get_reward_data_assembler()._build_reward_display_data(reward)

func _apply_reward_card_style(button: Button, reward: RewardInfo, selected: bool, holding: bool = false) -> void:
	if button == null or reward == null:
		return
	var selected_badge := button.find_child("SelectedBadge", true, false) as Control
	if selected_badge != null:
		selected_badge.visible = selected
	var selection_bar := button.find_child("SelectionIndicatorBar", true, false) as ColorRect
	if selection_bar != null:
		selection_bar.visible = selected
	var selected_art := button.find_child("SelectedStripArt", true, false) as TextureRect
	if selected_art != null:
		selected_art.visible = selected
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.draw_center = false
	focus_style.border_color = Color(TOKENS.COLOR_ACCENT_SYSTEM, 0.9)
	focus_style.set_border_width_all(2)
	focus_style.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus_style)
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

func _build_reward_card_button(reward: RewardInfo, reward_index: int = -1, reusable: Button = null) -> Button:
	var button: Button = _get_card_factory().build(reward, reward_index, reusable, _build_reward_card_model(reward).to_display_data(), _summary_mode, _get_reward_type_color(reward))
	_apply_reward_card_style(button, reward, false)
	return button

func _get_card_factory() -> RewardCardFactory:
	if _card_factory == null:
		_card_factory = preload("res://UI/scripts/presentation/reward_card_factory.gd").new(self)
	return _card_factory

func _inline_text(english: String, chinese: String) -> String:
	return _get_card_factory()._inline_text(english, chinese)

func _crop_reward_texture_to_content(source: Texture2D) -> Texture2D:
	return _get_card_factory()._crop_reward_texture_to_content(source)

func _get_detail_controller() -> RewardDetailController:
	if _detail_controller == null:
		_detail_controller = preload("res://UI/scripts/components/reward_detail_controller.gd").new(self)
	return _detail_controller

func _on_weapon_hotspot_mouse_entered(index: int) -> void:
	_get_detail_controller()._on_weapon_hotspot_mouse_entered(index)

func _on_weapon_hotspot_mouse_exited(index: int) -> void:
	_get_detail_controller()._on_weapon_hotspot_mouse_exited(index)

func _on_detail_overlay_mouse_entered(index: int) -> void:
	_get_detail_controller()._on_detail_overlay_mouse_entered(index)

func _on_detail_overlay_mouse_exited(index: int) -> void:
	_get_detail_controller()._on_detail_overlay_mouse_exited(index)

func _on_detail_open_timeout() -> void:
	_get_detail_controller()._on_detail_open_timeout()

func _on_detail_close_timeout() -> void:
	_get_detail_controller()._on_detail_close_timeout()

func _toggle_focused_weapon_detail() -> void:
	_get_detail_controller()._toggle_focused_weapon_detail()

func _close_weapon_detail() -> void:
	_get_detail_controller()._close_weapon_detail()
