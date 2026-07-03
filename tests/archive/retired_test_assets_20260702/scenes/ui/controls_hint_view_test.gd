extends Node

const UI_SCENE := preload("res://UI/scenes/UI.tscn")

var _failed := false
var _original_mode: StringName
var _original_auto_reload := false
var _original_locale := "en"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_original_mode = PlayerAssistSettings.controls_hint_mode
	_original_auto_reload = PlayerAssistSettings.auto_reload_switch
	_original_locale = LocalizationManager.get_locale()
	LocalizationManager.set_locale("en", false)
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE
	PlayerAssistSettings.auto_reload_switch = false
	PhaseManager.phase = PhaseManager.BATTLE

	var ui := UI_SCENE.instantiate() as UI
	get_tree().root.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	var hint := ui.controls_hint_view as ControlsHintView
	_assert_true(hint != null, "Controls hint view should be created.")
	_assert_true(ui.right_hud_stack != null, "Right HUD stack should be created.")
	_assert_true(hint.get_parent() == ui.right_hud_stack, "Controls hint should use the shared right HUD stack.")
	_assert_true(
		ui.task_objective_hud_presenter.panel.get_parent() == ui.right_hud_stack,
		"Task HUD should use the shared right HUD stack."
	)
	_assert_equal(0, hint.get_index(), "Controls hint should be ordered above the task HUD.")
	_assert_true(
		hint.get_index() < ui.task_objective_hud_presenter.panel.get_index(),
		"Task HUD should follow the controls hint."
	)

	ui.task_objective_hud_presenter.panel.visible = true
	hint.set_display_state(ControlsHintView.DisplayState.EXPANDED, false)
	await get_tree().process_frame
	_assert_false(
		ui.task_objective_hud_presenter.panel.get_global_rect().intersects(hint.get_global_rect()),
		"Task HUD and controls hint should not overlap."
	)
	_assert_true(hint.get_global_rect().end.x <= 1264.5, "Controls hint should preserve the right screen margin.")
	_assert_true(hint.get_global_rect().position.y >= 16.0, "Controls hint should preserve the top screen margin.")
	_assert_equal(1, hint.expanded_content.columns, "A 360px controls hint should use one-column layout.")
	_assert_action_labels_usable(hint, "Default expanded layout")
	hint._set_action_item(
		&"move",
		"Ctrl+Shift+ExtremelyLongMouseButton",
		"This deliberately long action description must wrap or trim without widening the controls panel."
	)
	await get_tree().process_frame
	_assert_visible_labels_within(hint, "Expanded long text")
	hint.refresh_input_glyphs()

	hint.set_display_state(ControlsHintView.DisplayState.EXPANDED, false)
	hint._on_toggle_button_pressed()
	_assert_equal(
		ControlsHintView.DisplayState.COMPACT,
		hint.display_state,
		"Header collapse button should use the same temporary collapse path."
	)
	_assert_equal(
		PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE,
		PlayerAssistSettings.controls_hint_mode,
		"Header collapse button should preserve adaptive mode."
	)
	hint.compact_text.text = "WASD Move · Left Mouse Attack · Space Player Skill · Q/E Switch Weapon · R Reload"
	hint.compact_expand.text = "F1 Expand Controls"
	await get_tree().process_frame
	_assert_visible_labels_within(hint, "Compact long text")
	_assert_false(
		hint.gui_input.is_connected(Callable(hint, "_on_panel_gui_input")),
		"Controls hint panel should not be the click target."
	)
	_assert_false(
		hint.expanded_content.gui_input.is_connected(Callable(hint, "_on_panel_gui_input")),
		"Expanded controls hint content should not be the click target."
	)
	_assert_true(
		hint.compact_expand.pressed.is_connected(Callable(hint, "_on_compact_expand_button_pressed")),
		"Compact controls hint should expose a dedicated expand button."
	)
	hint._on_compact_expand_button_pressed()
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"Pressing the compact expand button should expand the controls hint."
	)
	hint._request_display_state(ControlsHintView.DisplayState.COMPACT)
	hint.set_display_state(ControlsHintView.DisplayState.EXPANDED, false)

	var reload_item := hint._action_items.get(&"reload", null) as HBoxContainer
	var reload_key := reload_item.get_node_or_null("Key") as Label if reload_item else null
	_assert_equal("R", reload_key.text if reload_key else "", "Reload glyph should come from InputMap.")
	var original_reload_events := InputMap.action_get_events("SKILL_WEAPON")
	InputMap.action_erase_events("SKILL_WEAPON")
	var remapped_reload := InputEventKey.new()
	remapped_reload.physical_keycode = KEY_T
	InputMap.action_add_event("SKILL_WEAPON", remapped_reload)
	hint.refresh_input_glyphs()
	_assert_equal("T", reload_key.text if reload_key else "", "Reload glyph should update after remapping.")
	InputMap.action_erase_events("SKILL_WEAPON")
	for original_event in original_reload_events:
		InputMap.action_add_event("SKILL_WEAPON", original_event)
	hint.refresh_input_glyphs()

	hint.set_display_state(ControlsHintView.DisplayState.EXPANDED, false)
	hint.tick(ControlsHintView.AUTO_COLLAPSE_SECONDS + 0.1)
	_assert_equal(
		ControlsHintView.DisplayState.COMPACT,
		hint.display_state,
		"Adaptive battle guidance should auto-collapse."
	)

	var toggle_event := InputEventAction.new()
	toggle_event.action = "TOGGLE_CONTROLS"
	toggle_event.pressed = true
	_assert_true(hint.handle_input_event(toggle_event), "Toggle-controls input should be consumed.")
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"Toggle-controls input should expand the hint."
	)
	await get_tree().physics_frame
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"Manual F1 expansion should remain expanded across physics frames."
	)
	_assert_equal(
		PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE,
		PlayerAssistSettings.controls_hint_mode,
		"Temporary F1 expansion should preserve adaptive mode."
	)
	hint.handle_input_event(toggle_event)
	_assert_equal(
		ControlsHintView.DisplayState.COMPACT,
		hint.display_state,
		"Second F1 press should release the manual lock and collapse the hint."
	)
	_assert_equal(
		PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE,
		PlayerAssistSettings.controls_hint_mode,
		"Temporary F1 collapse should preserve adaptive mode."
	)
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_HIDDEN
	hint.set_display_state(ControlsHintView.DisplayState.HIDDEN, false)
	_assert_false(hint.handle_input_event(toggle_event), "F1 should not be consumed while controls hint is hidden by setting.")
	_assert_equal(
		PlayerAssistSettings.CONTROLS_HINT_HIDDEN,
		PlayerAssistSettings.controls_hint_mode,
		"F1 should not rewrite the persistent hidden mode."
	)
	_assert_equal(
		ControlsHintView.DisplayState.HIDDEN,
		hint.display_state,
		"Hidden mode should remain hidden until the persistent setting changes."
	)
	_assert_true(hint.collapse_button.disabled, "Hidden mode should disable the header button affordance.")

	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE
	_assert_true(
		hint.show_context_reminder(
			&"SKILL_WEAPON",
			"正在执行一个非常长的自动装填流程，请等待当前装填动作完成后再继续攻击。",
			true
		),
		"Context reminder should display."
	)
	_assert_equal(
		ControlsHintView.DisplayState.CONTEXT_REMINDER,
		hint.display_state,
		"Context reminder should use its dedicated display state."
	)
	await get_tree().process_frame
	_assert_visible_labels_within(hint, "Context reminder long text")
	hint.tick(ControlsHintView.CONTEXT_DURATION_SECONDS + 0.1)
	_assert_true(
		hint.display_state != ControlsHintView.DisplayState.CONTEXT_REMINDER,
		"Context reminder should expire."
	)

	PhaseManager.phase = PhaseManager.PREPARE
	hint.refresh_for_phase(PhaseManager.PREPARE, true, &"warehouse")
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"Warehouse controls context should open expanded the first time."
	)
	hint.handle_input_event(toggle_event)
	_assert_equal(
		ControlsHintView.DisplayState.COMPACT,
		hint.display_state,
		"F1 should collapse the warehouse controls context."
	)
	_assert_true(
		hint.compact_text.text == "Warehouse controls",
		"Collapsed secondary menu controls should keep a compact context summary."
	)
	_assert_true(
		hint.compact_expand.text == "F1 Expand",
		"Collapsed secondary menu controls should expose the F1 expand action."
	)
	_assert_false(
		hint.compact_text.text.contains(LocalizationManager.tr_key("ui.tutorial.panel.secondary.warehouse.line1", "")),
		"Collapsed secondary menu controls should not include full tutorial text."
	)
	hint.refresh_for_phase(PhaseManager.PREPARE, true, &"warehouse")
	_assert_equal(
		ControlsHintView.DisplayState.COMPACT,
		hint.display_state,
		"Refreshing the same warehouse context should not force the controls context open again."
	)
	hint.refresh_for_phase(PhaseManager.PREPARE, true, &"upgrade")
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"Switching to upgrade should open expanded the first time."
	)
	hint.handle_input_event(toggle_event)
	_assert_equal(
		ControlsHintView.DisplayState.COMPACT,
		hint.display_state,
		"F1 should collapse the upgrade controls context."
	)
	hint.refresh_for_phase(PhaseManager.PREPARE, true, &"warehouse")
	_assert_equal(
		ControlsHintView.DisplayState.COMPACT,
		hint.display_state,
		"Returning to a collapsed warehouse context should keep it compact."
	)
	hint.refresh_for_phase(PhaseManager.PREPARE, true, &"task_management")
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"Switching to task management should open expanded the first time."
	)
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ALWAYS
	hint.refresh_for_phase(PhaseManager.PREPARE, true, &"warehouse")
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"Always Expanded should override per-context compact memory."
	)
	_assert_true(hint.collapse_button.disabled, "Always Expanded should disable the collapse button.")
	_assert_false(
		hint.collapse_button.text.contains(LocalizationManager.tr_key("ui.controls.collapse", "Collapse")),
		"Always Expanded button text should not promise collapse."
	)
	_assert_false(
		hint._request_display_state(ControlsHintView.DisplayState.COMPACT),
		"Unified display request should reject compact while Always Expanded is selected."
	)
	_assert_true(
		hint._request_display_state(ControlsHintView.DisplayState.EXPANDED),
		"Unified display request should allow expanded while Always Expanded is selected."
	)
	_assert_false(hint.handle_input_event(toggle_event), "F1 should not be consumed while Always Expanded is selected.")
	hint._on_toggle_button_pressed()
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"F1 and the header button should not compact controls while Always Expanded is selected."
	)
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE
	hint.refresh_for_phase(PhaseManager.PREPARE, true, &"warehouse")
	_assert_equal(
		ControlsHintView.DisplayState.COMPACT,
		hint.display_state,
		"Adaptive mode should restore the remembered warehouse compact state."
	)
	hint.handle_input_event(toggle_event)
	_assert_equal(
		ControlsHintView.DisplayState.EXPANDED,
		hint.display_state,
		"F1 should expand a compact secondary menu controls context."
	)
	_assert_equal(
		PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE,
		PlayerAssistSettings.controls_hint_mode,
		"Temporary F1 expansion in text context should preserve adaptive mode."
	)
	PhaseManager.phase = PhaseManager.BATTLE
	hint.refresh_for_phase(PhaseManager.BATTLE, false)
	reload_item = hint._action_items.get(&"reload", null) as HBoxContainer

	PlayerAssistSettings.auto_reload_switch = true
	hint.refresh_input_glyphs()
	var reload_action := reload_item.get_node_or_null("Action") as Label if reload_item else null
	_assert_true(
		reload_action != null and reload_action.text == LocalizationManager.tr_key("ui.controls.auto_reload", "Auto Reload On"),
		"Reload hint should reflect automatic reload assistance."
	)
	LocalizationManager.set_locale("zh_CN", false)
	hint.refresh_input_glyphs()
	_assert_equal("操作", hint.title_label.text, "Chinese controls localization should be imported.")
	var attack_item := hint._action_items.get(&"attack", null) as HBoxContainer
	var attack_key := attack_item.get_node_or_null("Key") as Label if attack_item else null
	_assert_equal("左键", attack_key.text if attack_key else "", "Chinese mouse key label should use the short name.")
	_assert_true(hint.collapse_button.text.contains("收起"), "Collapse button should have an explicit Chinese label.")
	PhaseManager.phase = PhaseManager.PREPARE
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE
	hint.refresh_for_phase(PhaseManager.PREPARE, true, &"warehouse")
	hint.handle_input_event(toggle_event)
	var zh_context_name := hint._compact_context_name(LocalizationManager.tr_key("ui.tutorial.state.secondary.warehouse", "Current: Warehouse"))
	var zh_expected_compact := LocalizationManager.tr_key("ui.controls.compact_context", "{context} controls").format({
		"context": zh_context_name,
	})
	_assert_equal(zh_expected_compact, hint.compact_text.text, "Chinese compact text should use the current context.")
	await get_tree().process_frame
	_assert_visible_labels_within(hint, "Chinese compact text context")
	LocalizationManager.set_locale(_original_locale, false)

	var controls_option: OptionButton = ui.pause_ui_controller.controls_hint_option as OptionButton
	_assert_true(controls_option != null and controls_option.item_count == 3, "Pause settings should expose three hint modes.")
	LocalizationManager.set_locale("en", false)
	ui.pause_ui_controller.refresh_language_options()
	_assert_equal("Adaptive", controls_option.get_item_text(0), "English pause settings should label adaptive mode.")
	_assert_equal("Always Expanded", controls_option.get_item_text(1), "English pause settings should label always-expanded mode.")
	_assert_equal("Hidden", controls_option.get_item_text(2), "English pause settings should label hidden mode.")
	_assert_true(controls_option.tooltip_text.contains("F1"), "Controls hint settings tooltip should explain F1 scope.")
	LocalizationManager.set_locale("zh_CN", false)
	ui.pause_ui_controller.refresh_language_options()
	_assert_equal(LocalizationManager.tr_key("ui.settings.controls_hint.adaptive", "Adaptive"), controls_option.get_item_text(0), "Chinese pause settings should label adaptive mode.")
	_assert_equal(LocalizationManager.tr_key("ui.settings.controls_hint.always", "Always Expanded"), controls_option.get_item_text(1), "Chinese pause settings should label always-expanded mode.")
	_assert_equal(LocalizationManager.tr_key("ui.settings.controls_hint.hidden", "Hidden"), controls_option.get_item_text(2), "Chinese pause settings should label hidden mode.")
	LocalizationManager.set_locale(_original_locale, false)
	ui.pause_ui_controller.refresh_language_options()
	ui._layout_controls_hint_panel(Vector2(320.0, 720.0))
	await get_tree().process_frame
	_assert_true(hint.custom_minimum_size.x <= 288.0, "Narrow layout should respect available width.")
	_assert_equal(1, hint.expanded_content.columns, "Narrow layout should remain one column.")
	_assert_visible_labels_within(hint, "Narrow viewport")
	ui._layout_controls_hint_panel(Vector2(2560.0, 1440.0))
	await get_tree().process_frame
	_assert_true(hint.custom_minimum_size.x <= ControlsHintView.PANEL_WIDTH, "Wide layout should respect the panel width cap.")
	_assert_visible_labels_within(hint, "Wide viewport")

	ui.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_restore_settings()
	_finish()

func _restore_settings() -> void:
	PlayerAssistSettings.controls_hint_mode = _original_mode
	PlayerAssistSettings.auto_reload_switch = _original_auto_reload
	PlayerAssistSettings.save_settings()
	LocalizationManager.set_locale(_original_locale, false)

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failed = true
	push_error("FAIL: %s" % message)

func _assert_false(condition: bool, message: String) -> void:
	_assert_true(not condition, message)

func _assert_equal(expected: Variant, actual: Variant, message: String) -> void:
	_assert_true(expected == actual, "%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])

func _assert_visible_labels_within(panel: Control, context: String) -> void:
	var panel_rect := panel.get_global_rect()
	for node in _collect_nodes(panel):
		var label := node as Label
		if label == null or not label.is_visible_in_tree():
			continue
		var label_rect := label.get_global_rect()
		_assert_true(
			label_rect.position.x >= panel_rect.position.x - 0.5 \
				and label_rect.end.x <= panel_rect.end.x + 0.5,
			"%s label '%s' should remain inside the panel." % [context, label.name]
		)

func _assert_action_labels_usable(hint: ControlsHintView, context: String) -> void:
	for action_id in [&"move", &"attack", &"skill", &"reload", &"switch", &"pause"]:
		var item := hint._action_items.get(action_id, null) as HBoxContainer
		var action_label := item.get_node_or_null("Action") as Label if item else null
		_assert_true(
			action_label != null \
				and action_label.is_visible_in_tree() \
				and action_label.size.x >= 100.0 \
				and action_label.size.y >= 20.0 \
				and not action_label.text.strip_edges().is_empty(),
			"%s action '%s' should be visible with usable width." % [context, action_id]
		)

func _collect_nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child in root.get_children():
		nodes.append_array(_collect_nodes(child))
	return nodes

func _finish() -> void:
	if _failed:
		print("FAIL: controls hint view")
	else:
		print("PASS: controls hint view")
	get_tree().quit(1 if _failed else 0)
