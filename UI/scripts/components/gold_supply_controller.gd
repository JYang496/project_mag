extends Node

const SUPPLY_HUD := preload("res://UI/components/SupplyProgressMeter/GoldSupplyHud.gd")
const REWARD_DATA := preload("res://UI/scripts/presentation/reward_card_data_assembler.gd")

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
var _last_ready_count := 0
var _first_ready_shown := false
var _last_announced_msec := -10000
var _last_available := false
var _selected_feedback := ""
var _refresh_elapsed := 0.0
var _pending_announcement := false
var _resources_ready := false
var _preparing := false
var _state_version := 0
var _prepared_version := -1
var _prepared_sequence := 0
var _prepared_record: Dictionary = {}
var _prepared_rewards: Array[RewardInfo] = []
var _retry_after_msec := 0
var _prepared_feedback: Array[String] = []

func finish_resource_prewarm() -> void:
	_resources_ready = true
	refresh()

func _invalidate_preparation() -> void:
	_state_version += 1
	_prepared_version = -1
	_prepared_rewards.clear()
	_prepared_feedback.clear()
	_prepared_record = {}
	if is_instance_valid(ui.reward_selection_panel):
		ui.reward_selection_panel.invalidate_prepared_supply()
	if is_instance_valid(ui.weapon_replacement_panel):
		ui.weapon_replacement_panel.invalidate_prepared_selection()

func _is_preparation_current(version: int, sequence: int) -> bool:
	if not is_inside_tree() or version != _state_version or not _resources_ready or not _can_claim() or not is_instance_valid(PlayerData.player):
		return false
	return PlayerData.get_next_pending_gold_supply_sequence() == sequence

func _has_prepared_supply() -> bool:
	if _prepared_version != _state_version or _prepared_rewards.is_empty() or _prepared_sequence != PlayerData.get_next_pending_gold_supply_sequence():
		return false
	if str(_prepared_record.get("status", "")) == "awaiting_replacement":
		return is_instance_valid(ui.weapon_replacement_panel) and ui.weapon_replacement_panel.has_prepared_selection()
	return is_instance_valid(ui.reward_selection_panel) and ui.reward_selection_panel.has_prepared_supply(_prepared_rewards)

func _prepare_next_supply() -> void:
	if _preparing or not _resources_ready or active or _has_prepared_supply() or not _can_claim() or Time.get_ticks_msec() < _retry_after_msec:
		return
	var sequence := PlayerData.get_next_pending_gold_supply_sequence()
	if sequence == 0 or not is_instance_valid(PlayerData.player):
		return
	_preparing = true
	var version := _state_version
	var current := _is_preparation_current.bind(version, sequence)
	var result: Dictionary = await PlayerData.gold_supply_rewards.prepare_in_background(sequence, current)
	if bool(result.get("ok", false)) and bool(current.call()):
		ui._init_reward_selection_panel()
		var rewards: Array[RewardInfo] = PlayerData.gold_supply_rewards.get_rewards(sequence)
		var ready := false
		if str(result.record.get("status", "")) == "awaiting_replacement":
			ui._init_weapon_replacement_panel()
			var option: Dictionary = result.record.options[int(result.record.selected)]
			var definition := DataHandler.read_weapon_data(str(option.id)) as WeaponDefinition
			var weapon := definition.scene.instantiate() as Weapon if definition and definition.scene else null
			if weapon != null:
				weapon.level = int(option.level)
				ready = await ui.weapon_replacement_panel.prepare_selection(weapon, current)
				if ready:
					var controls: Array[Control] = [ui.weapon_replacement_panel.incoming_host, ui.weapon_replacement_panel.slots]
					ready = await ui.reward_selection_panel.warm_supply_controls(controls, current)
		else:
			ready = await ui.reward_selection_panel.prepare_supply_cards(rewards, current)
		var feedback: Array[String] = []
		if ready and bool(current.call()):
			var assembler := REWARD_DATA.new()
			for reward in rewards:
				var data: Dictionary = assembler._build_reward_card_data(reward)
				feedback.append("%s · %s" % [str(data.get("name", "")), str(data.get("tag", ""))])
				await get_tree().process_frame
				if not bool(current.call()):
					ready = false
					break
		if ready and bool(current.call()):
			_prepared_rewards.assign(rewards)
			_prepared_feedback.assign(feedback)
			_prepared_record = result.record
			_prepared_sequence = sequence
			_prepared_version = version
	elif str(result.get("status", "")) == "save_failed":
		_retry_after_msec = Time.get_ticks_msec() + 1000
	_preparing = false
	refresh()
	PhaseManager.request_settlement_reward_gate_check()

func bind(owner_ui: UI) -> void:
	ui = owner_ui
	process_mode = Node.PROCESS_MODE_ALWAYS
	button = SUPPLY_HUD.new()
	ui.gui_root.add_child(button)
	button.z_index = 45
	title_label = button.title_label
	progress_label = button.progress_label
	ready_label = button.action_label
	progress_bar = button.progress_bar
	PlayerData.gold_supply_reset.connect(_reset_feedback)
	PhaseManager.phase_changed.connect(_phase_changed)
	layout()
	button.pressed.connect(open_supply)
	PlayerData.gold_supply_changed.connect(refresh)
	PlayerData.gold_supply_reset.connect(close_supply)
	LocalizationManager.language_changed.connect(_language_changed)
	PlayerData.weapon_list_changed.connect(_invalidate_preparation)
	InventoryData.temporary_modules_changed.connect(_invalidate_preparation)
	InventoryData.weapon_storage_changed.connect(_invalidate_preparation)
	InventoryData.weapon_cores_changed.connect(_invalidate_preparation)
	InventoryData.pending_transactions_changed.connect(_invalidate_preparation)
	refresh()

func _language_changed(_locale: String) -> void:
	_invalidate_preparation()
	button.call("clear_feedback")
	refresh()

func refresh() -> void:
	if not is_instance_valid(button):
		return
	button.visible = (
		PlayerData.gold_supply_enabled
		and not ui._reward_modal_hud_hidden
		and not ui._is_selection_interface_open()
		and PhaseManager.current_state() in [PhaseManager.BATTLE, PhaseManager.REST, PhaseManager.SETTLEMENT]
	)
	var count := PlayerData.get_pending_gold_supply_count()
	var threshold := PlayerData.get_next_gold_supply_threshold()
	var events := InputMap.action_get_events("CLAIM_SUPPLY")
	var key := ""
	if not events.is_empty():
		var event := events[0] as InputEventKey
		key = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode) if event != null else events[0].as_text()
	var available := count > 0 and _can_claim() and _has_prepared_supply()
	if count > 0 and not available:
		button.call("clear_feedback")
	title_label.text = LocalizationManager.tr_format("ui.supply.upgrade_ready", {"count": count}, "Upgrade ready ×{count}") if count > 0 else LocalizationManager.tr_key("ui.supply.title", "Gold Supply")
	if active:
		ready_label.text = LocalizationManager.tr_key("ui.supply.choosing", "Choosing upgrade")
	elif count > 0 and _can_claim() and not _has_prepared_supply():
		ready_label.text = LocalizationManager.tr_key("ui.supply.preparing", "Preparing upgrade…")
	elif count > 0 and not available:
		ready_label.text = LocalizationManager.tr_key("ui.supply.blocked", "Close menu to claim")
	else:
		ready_label.text = (("[" + key + "] " if not key.is_empty() else "") + LocalizationManager.tr_key("ui.supply.claim_upgrade", "Claim upgrade")) if count > 0 else LocalizationManager.tr_key("ui.supply.collect", "Collect gold to upgrade")
	ready_label.add_theme_font_size_override("font_size", 18 if available else 14)
	progress_label.text = LocalizationManager.tr_format("ui.supply.next_progress", {"current": PlayerData.gold_supply_progress, "next": threshold}, "Next supply {current}/{next}") if threshold > 0 else LocalizationManager.tr_key("ui.supply.finished", "All supplies unlocked")
	var ratio := clampf(float(PlayerData.gold_supply_progress) / float(threshold), 0.0, 1.0) if threshold > 0 else 0.0
	progress_bar.call("set_target_value", ratio)
	progress_bar.call("set_ready", count > 0)
	button.call("set_ready_count", count)
	button.call("set_claim_available", available)
	button.tooltip_text = LocalizationManager.tr_key("ui.supply.hint", "Claim one supply. Combat pauses while choosing.")
	button.disabled = not available
	_last_available = available
	if count > _last_ready_count:
		_pending_announcement = true
	if count == 0:
		_pending_announcement = false
	if _pending_announcement and button.is_visible_in_tree() and available:
		_pending_announcement = false
		var now := Time.get_ticks_msec()
		if now - _last_announced_msec > 600:
			button.call("announce_ready")
			_last_announced_msec = now
		if not _first_ready_shown:
			_first_ready_shown = true
			button.call("show_feedback", LocalizationManager.tr_format("ui.supply.first_ready", {"key": key}, "Supply ready! Press {key} to upgrade. Combat pauses while choosing."), 4.0)
	_last_ready_count = count

func _can_claim() -> bool:
	if active or ui.get_tree().paused or PhaseManager.current_state() not in [PhaseManager.BATTLE, PhaseManager.REST, PhaseManager.SETTLEMENT]:
		return false
	if ui.modal_ui_controller != null and ui.modal_ui_controller.is_modal_open():
		return false
	return not ui._is_selection_interface_open() and not ui.is_dialog_visible() and not ui._is_primary_menu_open() and InventoryData.pending_transactions.is_empty()

func _phase_changed(_new_phase: String) -> void:
	_invalidate_preparation()
	refresh()
	layout()

func _reset_feedback() -> void:
	_invalidate_preparation()
	_first_ready_shown = false
	_last_ready_count = 0
	_selected_feedback = ""
	_last_announced_msec = -10000
	_pending_announcement = false
	button.call("clear_feedback")

func layout() -> void:
	if not is_instance_valid(button):
		return
	var viewport_size := ui.get_viewport().get_visible_rect().size
	var resource_size := Vector2(250.0, 20.0)
	if ui.hud_presenter != null and is_instance_valid(ui.hud_presenter.primary_resource_meter):
		var meter := ui.hud_presenter.primary_resource_meter as Control
		if meter.has_method("get_visual_footprint_size"):
			resource_size = meter.call("get_visual_footprint_size") as Vector2
	var right_edge := viewport_size.x - 16.0
	var resource_top := viewport_size.y - 16.0 - resource_size.y
	button.position = Vector2(
		roundf(maxf(16.0, right_edge - button.size.x)),
		roundf(maxf(16.0, resource_top - 12.0 - button.size.y))
	)

func _reward_feedback(reward: RewardInfo) -> String:
	var index := _prepared_rewards.find(reward)
	if index >= 0 and index < _prepared_feedback.size():
		return _prepared_feedback[index]
	var data: Dictionary = REWARD_DATA.new()._build_reward_card_data(reward)
	return "%s · %s" % [str(data.get("name", "")), str(data.get("tag", ""))]

func _show_applied_feedback() -> void:
	if not _selected_feedback.is_empty():
		button.call("show_feedback", LocalizationManager.tr_format("ui.supply.applied", {"reward": _selected_feedback}, "Supply applied: {reward}"), 2.0)
		_selected_feedback = ""

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
	var sequence := PlayerData.get_next_pending_gold_supply_sequence()
	if sequence == 0:
		return false
	if not _has_prepared_supply() or _prepared_sequence != sequence:
		_prepare_next_supply.call_deferred()
		return false
	active = true
	_settlement_forced = force_settlement and PhaseManager.current_state() == PhaseManager.SETTLEMENT
	_generation += 1
	_sequence = sequence
	_phase = PhaseManager.current_state()
	_token = PhaseManager.acquire_pause(self)
	if not PlayerData.gold_supply_rewards.begin_battle_claim(self, _token):
		close_supply()
		return false
	for panel in [ui.reward_selection_panel]:
		if not is_instance_valid(panel):
			_fail()
			return false
		_panel_modes[panel] = panel.process_mode
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_rewards.assign(_prepared_rewards)
	ui._update_cursor_presentation()
	refresh()
	var record: Dictionary = _prepared_record
	if str(record.get("status", "")) == "awaiting_replacement":
		_selected_feedback = _reward_feedback(_rewards[int(record.selected)])
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
	_selected_feedback = _reward_feedback(reward)
	var result: Dictionary = PlayerData.gold_supply_rewards.accept(_sequence, index)
	if not active:
		return
	if bool(result.get("ok", false)) and str(result.get("status", "")) == "replacement_required":
		_open_replacement(result.option)
	elif bool(result.get("ok", false)):
		var module_to_install: Module = null
		if _phase == PhaseManager.BATTLE and str(result.get("result", "")) == "stored" and reward.module_scene != null:
			module_to_install = InventoryData.find_owned_module_by_scene_path(reward.module_scene.resource_path)
			if not InventoryData.can_assign_module_to_any_equipped_weapon(module_to_install, true):
				module_to_install = null
		close_supply()
		_show_applied_feedback()
		if module_to_install != null and is_instance_valid(module_to_install):
			ui.request_module_pickup_selection(module_to_install)
	else:
		_fail()

func _open_replacement(option: Dictionary) -> bool:
	ui._init_weapon_replacement_panel()
	var panel: Control = ui.weapon_replacement_panel
	if not is_instance_valid(panel):
		_fail()
		return false
	if not _panel_modes.has(panel):
		_panel_modes[panel] = panel.process_mode
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_replacement = true
	var definition := DataHandler.read_weapon_data(str(option.id)) as WeaponDefinition
	var weapon: Weapon = ui.weapon_replacement_panel.get_prepared_selection_weapon()
	if weapon == null:
		weapon = definition.scene.instantiate() as Weapon if definition and definition.scene else null
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
		if accepted:
			_show_applied_feedback()
		else:
			_selected_feedback = ""

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

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.12 and is_instance_valid(button):
		_refresh_elapsed = 0.0
		_prepare_next_supply.call_deferred()
		if _prepared_sequence != 0 and PlayerData.get_next_pending_gold_supply_sequence() != _prepared_sequence and _prepared_version != -1:
			_invalidate_preparation()
		var available := _last_ready_count > 0 and _can_claim() and _has_prepared_supply()
		if available != _last_available:
			refresh()
		layout()
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
	_selected_feedback = ""
	close_supply()
	if is_instance_valid(ui) and ui.is_inside_tree():
		ui.show_item_message(LocalizationManager.tr_key("ui.supply.failed", "Supply could not be claimed. It remains available."), 3.0)

func close_supply() -> void:
	if not active:
		return
	active = false
	var was_replacement := _replacement
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
	if was_replacement:
		_invalidate_preparation()
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
	if is_instance_valid(button):
		button.queue_free()
