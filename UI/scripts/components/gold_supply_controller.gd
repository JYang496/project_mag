extends Node

const SUPPLY_PROGRESS_METER := preload("res://UI/components/SupplyProgressMeter/SupplyProgressMeter.gd")
const HUD_WIDTH := 216.0
const HUD_HEIGHT := 40.0

var ui: UI
var button: Button
var title_label: Label
var progress_label: Label
var ready_label: Label
var progress_bar: Control
var active := false
var _token := 0
var _generation := 0
var _sequence := 0
var _phase := ""
var _rewards: Array[RewardInfo] = []
var _replacement := false
var _panel_modes: Dictionary = {}
var _last_close_frame := -10
var _hidden_frames := 0
var _settlement_forced := false

func bind(owner_ui: UI) -> void:
	ui = owner_ui
	process_mode = Node.PROCESS_MODE_ALWAYS
	button = Button.new()
	button.name = "GoldSupplyHud"
	button.custom_minimum_size = Vector2(HUD_WIDTH, HUD_HEIGHT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for state in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	ui.left_contract_hud_stack.add_child(button)
	_build_hud_content()
	button.pressed.connect(open_supply)
	PlayerData.gold_supply_changed.connect(refresh)
	PlayerData.gold_supply_reset.connect(close_supply)
	LocalizationManager.language_changed.connect(_language_changed)
	refresh()

func _language_changed(_locale: String) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(button):
		return
	button.visible = PlayerData.gold_supply_enabled and PhaseManager.current_state() in [PhaseManager.BATTLE, PhaseManager.REST, PhaseManager.SETTLEMENT]
	var count := PlayerData.get_pending_gold_supplies().size()
	var threshold := PlayerData.get_next_gold_supply_threshold()
	title_label.text = LocalizationManager.tr_key("ui.supply.title", "Gold Supply")
	progress_label.text = "%d / %d" % [PlayerData.gold_supply_progress, threshold]
	var events := InputMap.action_get_events("CLAIM_SUPPLY")
	var key := ""
	if not events.is_empty():
		var event := events[0] as InputEventKey
		key = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode) if event != null else events[0].as_text()
	var ready := LocalizationManager.tr_format("ui.supply.ready", {"count": count}, "Supply ready ×{count}")
	ready_label.text = ready + ("  [" + key + "]" if not key.is_empty() else "") if count > 0 else ""
	ready_label.visible = count > 0
	var ratio := clampf(float(PlayerData.gold_supply_progress) / float(threshold), 0.0, 1.0) if threshold > 0 else 0.0
	progress_bar.call("set_target_value", ratio)
	progress_bar.call("set_ready", count > 0)
	button.tooltip_text = LocalizationManager.tr_key("ui.supply.hint", "Claim one supply. Combat pauses while choosing.")
	button.disabled = count == 0 or active

func _build_hud_content() -> void:
	title_label = Label.new()
	title_label.name = "Title"
	title_label.position = Vector2(0.0, 0.0)
	title_label.size = Vector2(136.0, 19.0)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.97, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.03, 0.94))
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(title_label)

	progress_label = Label.new()
	progress_label.name = "Value"
	progress_label.position = Vector2(140.0, 0.0)
	progress_label.size = Vector2(76.0, 19.0)
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.add_theme_color_override("font_color", Color(0.94, 0.78, 0.26, 1.0))
	progress_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.03, 0.94))
	progress_label.add_theme_constant_override("shadow_offset_x", 1)
	progress_label.add_theme_constant_override("shadow_offset_y", 1)
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(progress_label)

	ready_label = Label.new()
	ready_label.name = "Ready"
	ready_label.position = Vector2(0.0, 17.0)
	ready_label.size = Vector2(216.0, 10.0)
	ready_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ready_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.38, 1.0))
	ready_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.03, 0.94))
	ready_label.add_theme_constant_override("shadow_offset_x", 1)
	ready_label.add_theme_constant_override("shadow_offset_y", 1)
	ready_label.add_theme_font_size_override("font_size", 9)
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(ready_label)

	progress_bar = SUPPLY_PROGRESS_METER.new() as Control
	progress_bar.name = "Progress"
	progress_bar.position = Vector2(0.0, 27.0)
	progress_bar.size = Vector2(216.0, 12.0)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(progress_bar)

func open_supply(force_settlement: bool = false) -> bool:
	if active or Engine.get_process_frames() <= _last_close_frame + 1 or ui.get_tree().paused:
		return false
	if PhaseManager.current_state() not in [PhaseManager.BATTLE, PhaseManager.REST, PhaseManager.SETTLEMENT]:
		return false
	ui._init_modal_ui_controller()
	if ui.modal_ui_controller.is_modal_open() or ui._is_selection_interface_open() or ui.is_dialog_visible() or ui._is_primary_menu_open():
		return false
	if not InventoryData.pending_transactions.is_empty():
		return false
	var pending := PlayerData.get_pending_gold_supplies()
	if pending.is_empty():
		return false
	active = true
	_settlement_forced = force_settlement and PhaseManager.current_state() == PhaseManager.SETTLEMENT
	_generation += 1
	_sequence = int(pending[0].sequence)
	_phase = PhaseManager.current_state()
	_token = PhaseManager.acquire_pause(self)
	if not PlayerData.gold_supply_rewards.begin_battle_claim(self, _token):
		close_supply()
		return false
	var result: Dictionary = PlayerData.gold_supply_rewards.prepare(_sequence)
	if not active or not bool(result.get("ok", false)):
		_fail()
		return false
	ui._init_reward_selection_panel()
	ui._init_weapon_replacement_panel()
	for panel in [ui.reward_selection_panel, ui.weapon_replacement_panel]:
		if not is_instance_valid(panel):
			_fail()
			return false
		_panel_modes[panel] = panel.process_mode
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_rewards = PlayerData.gold_supply_rewards.get_rewards(_sequence)
	ui._update_cursor_presentation()
	refresh()
	var record: Dictionary = result.record
	if str(record.get("status", "")) == "awaiting_replacement":
		return _open_replacement(record.options[int(record.selected)])
	var opened: bool = ui.reward_selection_panel.open_for_rewards("", _rewards, _selected.bind(_generation), _cancelled.bind(_generation), not _settlement_forced,
		LocalizationManager.tr_key("ui.supply.title", "Gold Supply"), LocalizationManager.tr_key("ui.supply.hint", "Claim one supply. Combat pauses while choosing."))
	if not opened:
		_fail()
	return opened

func _selected(reward: RewardInfo, generation: int) -> void:
	if not active or generation != _generation or _replacement:
		return
	var index := _rewards.find(reward)
	if index < 0:
		_fail()
		return
	# Invalidate the callback before applying; a repeated deferred input is inert.
	_generation += 1
	var result: Dictionary = PlayerData.gold_supply_rewards.accept(_sequence, index)
	if not active:
		return
	if bool(result.get("ok", false)) and str(result.get("status", "")) == "replacement_required":
		_open_replacement(result.option)
	elif bool(result.get("ok", false)):
		close_supply()
	else:
		_fail()

func _open_replacement(option: Dictionary) -> bool:
	_replacement = true
	var definition := DataHandler.read_weapon_data(str(option.id)) as WeaponDefinition
	var weapon := definition.scene.instantiate() as Weapon if definition and definition.scene else null
	if weapon == null:
		_fail()
		return false
	weapon.level = int(option.level)
	var opened: bool = ui.weapon_replacement_panel.open_for_weapon(weapon, true, _replacement_done.bind(_generation), true)
	if opened:
		ui.set_reward_modal_hud_hidden(true)
	if not opened:
		weapon.queue_free()
		_fail()
	return opened

func _replacement_done(accepted: bool, result: Dictionary, generation: int) -> void:
	if not active or generation != _generation:
		return
	_generation += 1
	var applied: Dictionary = PlayerData.gold_supply_rewards.complete_replacement(_sequence, accepted, int(result.get("slot", -1)))
	if not bool(applied.get("ok", false)):
		_fail()
	else:
		close_supply()

func _cancelled(generation: int) -> void:
	if active and generation == _generation and not _settlement_forced:
		close_supply()

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("CLAIM_SUPPLY"):
		if not event.is_echo():
			open_supply()
		return true
	if active and ModalUiController.is_cancel_input(event):
		if _replacement and is_instance_valid(ui.weapon_replacement_panel):
			ui.weapon_replacement_panel.cancel_visible_modal()
		else:
			close_supply()
		return true
	return false

func _process(_delta: float) -> void:
	if not active:
		return
	if PhaseManager.current_state() != _phase or not is_instance_valid(PlayerData.player) or PlayerData.player.is_queued_for_deletion():
		close_supply()
		return
	# Covers an externally dismissed panel or an aborted callback without holding combat indefinitely.
	var panel: Control = ui.weapon_replacement_panel if _replacement else ui.reward_selection_panel
	_hidden_frames = _hidden_frames + 1 if not is_instance_valid(panel) or not panel.visible else 0
	if _hidden_frames > 2:
		close_supply()

func _fail() -> void:
	close_supply()
	if is_instance_valid(ui) and ui.is_inside_tree():
		ui.show_item_message(LocalizationManager.tr_key("ui.supply.failed", "Supply could not be claimed. It remains available."), 3.0)

func close_supply() -> void:
	if not active:
		return
	active = false
	_generation += 1
	_last_close_frame = Engine.get_process_frames()
	if is_instance_valid(ui.reward_selection_panel) and _panel_modes.has(ui.reward_selection_panel) and not _replacement:
		ui.reward_selection_panel.close_panel()
	if is_instance_valid(ui.weapon_replacement_panel) and _replacement:
		ui.weapon_replacement_panel.dismiss_selection()
	for panel in _panel_modes:
		if is_instance_valid(panel):
			panel.process_mode = _panel_modes[panel]
	_panel_modes.clear()
	ui.set_reward_modal_hud_hidden(false)
	PlayerData.gold_supply_rewards.end_battle_claim(self)
	PhaseManager.release_pause(_token)
	_token = 0
	_replacement = false
	_settlement_forced = false
	_hidden_frames = 0
	_rewards.clear()
	if is_instance_valid(ui) and ui.is_inside_tree():
		ui.get_viewport().gui_release_focus()
		ui._update_cursor_presentation()
	refresh()
	PhaseManager.request_settlement_reward_gate_check()

func _exit_tree() -> void:
	close_supply()
