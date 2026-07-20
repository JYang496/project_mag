extends Node

const CONTROLS_HINT_SCENE := preload("res://UI/scenes/components/controls_hint_view.tscn")

var _failed := false
var _original_mode: StringName
var _original_reload_events: Array[InputEvent]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_original_mode = PlayerAssistSettings.controls_hint_mode
	_original_reload_events = InputMap.action_get_events(&"SKILL_WEAPON")

	var hint := CONTROLS_HINT_SCENE.instantiate() as ControlsHintView
	add_child(hint)
	await get_tree().process_frame

	_test_adaptive_battle_guidance(hint)
	_test_temporary_f1_toggle(hint)
	_test_persistent_modes(hint)
	_test_dynamic_input_label(hint)
	await _test_adaptive_width(hint)
	await _test_text_context_adaptive_width(hint)
	await _test_stack_reflow_animation()

	_restore_state()
	hint.queue_free()
	await get_tree().process_frame
	_finish()

func _test_adaptive_battle_guidance(hint: ControlsHintView) -> void:
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE
	hint.refresh_for_phase(PhaseManager.PREPARE, false)
	hint.refresh_for_phase(PhaseManager.BATTLE, false)
	_assert_equal(ControlsHintView.DisplayState.EXPANDED, hint.display_state,
		"Adaptive mode should enter battle with the basic controls expanded.")

	hint.handle_input_event(_action_event(&"UP"))
	hint.handle_input_event(_action_event(&"ATTACK"))
	hint.tick(0.0)
	_assert_equal(ControlsHintView.DisplayState.COMPACT, hint.display_state,
		"Using movement and attack should collapse adaptive guidance.")

	hint.refresh_for_phase(PhaseManager.PREPARE, false)
	hint.refresh_for_phase(PhaseManager.BATTLE, false)
	hint.tick(ControlsHintView.AUTO_COLLAPSE_SECONDS + 0.1)
	_assert_equal(ControlsHintView.DisplayState.COMPACT, hint.display_state,
		"Adaptive guidance should collapse after its battle timeout.")
	_assert_true(ControlsHintView.AUTO_COLLAPSE_SECONDS >= 7.5 and ControlsHintView.AUTO_COLLAPSE_SECONDS <= 8.5,
		"The fallback timeout should remain approximately eight seconds.")

func _test_temporary_f1_toggle(hint: ControlsHintView) -> void:
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE
	hint.refresh_for_phase(PhaseManager.PREPARE, false)
	hint.refresh_for_phase(PhaseManager.BATTLE, false)
	var toggle := _action_event(&"TOGGLE_CONTROLS")
	_assert_true(hint.handle_input_event(toggle), "F1 should temporarily collapse adaptive guidance.")
	_assert_equal(ControlsHintView.DisplayState.COMPACT, hint.display_state,
		"The first F1 toggle should collapse expanded guidance.")
	_assert_equal(PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE, PlayerAssistSettings.controls_hint_mode,
		"Temporary F1 collapse should not change the persistent mode.")
	_assert_true(hint.handle_input_event(toggle), "F1 should temporarily expand compact guidance.")
	_assert_equal(ControlsHintView.DisplayState.EXPANDED, hint.display_state,
		"The second F1 toggle should expand compact guidance.")
	_assert_equal(PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE, PlayerAssistSettings.controls_hint_mode,
		"Temporary F1 expansion should not change the persistent mode.")

func _test_persistent_modes(hint: ControlsHintView) -> void:
	var toggle := _action_event(&"TOGGLE_CONTROLS")
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_HIDDEN
	hint.refresh_for_phase(PhaseManager.PREPARE, false)
	hint.refresh_for_phase(PhaseManager.BATTLE, false)
	_assert_equal(ControlsHintView.DisplayState.HIDDEN, hint.display_state,
		"Hidden mode should stay hidden in battle.")
	_assert_false(hint.handle_input_event(toggle), "F1 should not override Hidden mode.")

	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ALWAYS
	hint.refresh_for_phase(PhaseManager.PREPARE, false)
	hint.refresh_for_phase(PhaseManager.BATTLE, false)
	hint.tick(ControlsHintView.AUTO_COLLAPSE_SECONDS + 1.0)
	_assert_equal(ControlsHintView.DisplayState.EXPANDED, hint.display_state,
		"Always mode should remain expanded after the adaptive timeout.")
	_assert_false(hint.handle_input_event(toggle), "F1 should not collapse Always mode.")

func _test_dynamic_input_label(hint: ControlsHintView) -> void:
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE
	hint.refresh_for_phase(PhaseManager.PREPARE, false)
	hint.refresh_for_phase(PhaseManager.BATTLE, false)
	InputMap.action_erase_events(&"SKILL_WEAPON")
	var remapped := InputEventKey.new()
	remapped.physical_keycode = KEY_T
	InputMap.action_add_event(&"SKILL_WEAPON", remapped)
	hint.refresh_input_glyphs()
	var reload_item := hint._action_items.get(&"reload", null) as HBoxContainer
	var reload_key := reload_item.get_node_or_null("Key") as Label if reload_item else null
	_assert_equal("T", reload_key.text if reload_key else "",
		"Control labels should reflect the current InputMap binding.")

func _test_adaptive_width(hint: ControlsHintView) -> void:
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ALWAYS
	hint.refresh_for_phase(PhaseManager.PREPARE, false)
	hint.refresh_for_phase(PhaseManager.BATTLE, false)
	hint.title_label.text = "Keys"
	hint.collapse_button.text = "F1"
	for action_id in hint._action_items:
		hint._set_action_item(action_id, "W", "Go")
	hint._recalculate_expanded_width()
	await _settle_layout()
	_assert_true(hint._expanded_panel_width >= ControlsHintView.MIN_EXPANDED_WIDTH,
		"Short controls text should respect the expanded minimum width.")
	_assert_true(hint._expanded_panel_width < ControlsHintView.MAX_EXPANDED_WIDTH,
		"Short controls text should use less than the 360px width cap.")

	var long_action := "This deliberately long localized action description should wrap onto another line"
	hint.title_label.text = "A deliberately long localized controls heading"
	hint.collapse_button.text = "F1 Collapse controls"
	for action_id in hint._action_items:
		hint._set_action_item(action_id, "Ctrl+Shift", long_action)
	hint._recalculate_expanded_width()
	hint.layout_for_viewport(Vector2(1280.0, 720.0))
	await _settle_layout()
	_assert_equal(ControlsHintView.MAX_EXPANDED_WIDTH, hint._expanded_panel_width,
		"Long localized controls text should be capped at 360px.")
	_assert_true(hint.custom_minimum_size.x <= ControlsHintView.MAX_EXPANDED_WIDTH,
		"Long controls content should not widen the panel beyond its cap.")
	_assert_control_within(hint.title_label, hint, "Header title should remain inside the panel.")
	_assert_control_within(hint.collapse_button, hint, "Header button should remain inside the panel.")
	var move_item := hint._action_items.get(&"move", null) as HBoxContainer
	var move_key := move_item.get_node_or_null("Key") as Label if move_item else null
	var move_action := move_item.get_node_or_null("Action") as Label if move_item else null
	_assert_true(move_key != null
			and move_key.custom_minimum_size.x > ControlsHintView.MIN_KEYCAP_WIDTH
			and move_key.custom_minimum_size.x <= ControlsHintView.MAX_KEYCAP_WIDTH,
		"A longer key label should grow its shared keycap column within the cap.")
	_assert_true(move_action != null and move_action.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"Long action descriptions should retain wrapping.")
	_assert_true(move_action != null and move_action.size.y > 26.0,
		"Long action descriptions should wrap onto another line at the width cap.")

	hint.layout_for_viewport(Vector2(220.0, 720.0))
	await _settle_layout()
	_assert_true(hint.custom_minimum_size.x <= 188.5,
		"A narrow viewport should constrain the panel inside both 16px margins.")
	_assert_true(hint.position.x >= ControlsHintView.FALLBACK_MARGIN - 0.5
			and hint.get_global_rect().end.x <= 220.5 - ControlsHintView.FALLBACK_MARGIN,
		"A narrow viewport should keep the controls panel on screen.")

	hint.layout_for_viewport(Vector2(1280.0, 720.0))
	hint.set_display_state(ControlsHintView.DisplayState.COMPACT, false)
	await _settle_layout()
	_assert_true(absf(hint.custom_minimum_size.x - ControlsHintView.COMPACT_PANEL_WIDTH) <= 0.5,
		"Compact battle controls should remain approximately 132px wide.")

func _test_text_context_adaptive_width(hint: ControlsHintView) -> void:
	PlayerAssistSettings.controls_hint_mode = PlayerAssistSettings.CONTROLS_HINT_ALWAYS
	hint.refresh_for_phase(PhaseManager.PREPARE, false)
	hint._render_text_context("Rest", ["Click"])
	await _settle_layout()
	var short_width := hint._expanded_panel_width
	_assert_true(short_width >= ControlsHintView.MIN_EXPANDED_WIDTH
			and short_width < ControlsHintView.MAX_EXPANDED_WIDTH,
		"A short ordinary text context should use adaptive expanded width.")

	var long_line := "This localized menu instruction is deliberately long enough to wrap within the capped controls panel"
	hint._render_text_context("A deliberately long localized menu context heading", [long_line, long_line])
	await _settle_layout()
	_assert_equal(ControlsHintView.MAX_EXPANDED_WIDTH, hint._expanded_panel_width,
		"A long ordinary text context should use the 360px width cap.")
	var long_width := hint._expanded_panel_width
	hint._render_text_context("A deliberately long localized menu context heading", [long_line, long_line])
	hint._render_text_context("A deliberately long localized menu context heading", [long_line, long_line])
	await _settle_layout()
	_assert_true(absf(hint._expanded_panel_width - long_width) < 0.5,
		"Repeated text-context refreshes should settle at a stable width.")

	hint.layout_for_viewport(Vector2(220.0, 720.0))
	await _settle_layout()
	_assert_true(hint._target_panel_width(ControlsHintView.DisplayState.EXPANDED) <= 188.5,
		"A narrow viewport should cap text-context target width to available space.")

func _test_stack_reflow_animation() -> void:
	var stack := VBoxContainer.new()
	stack.position = Vector2(900.0, 16.0)
	add_child(stack)
	var animated_hint := CONTROLS_HINT_SCENE.instantiate() as ControlsHintView
	stack.add_child(animated_hint)
	await get_tree().process_frame
	var previous_global_position := animated_hint.get_global_position()
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 72.0
	stack.add_child(spacer)
	stack.move_child(spacer, 0)
	await get_tree().process_frame
	var layout_target := animated_hint.position
	_assert_true(animated_hint.animate_stack_reflow_from(previous_global_position),
		"Controls should animate when its stack layout target changes.")
	_assert_true(animated_hint.get_global_position().distance_to(previous_global_position) < 0.5,
		"Stack reflow animation should begin from the previous screen position.")
	await get_tree().create_timer(ControlsHintView.STACK_REFLOW_SECONDS + 0.05).timeout
	_assert_true(animated_hint.position.distance_to(layout_target) < 0.5,
		"Stack reflow animation should finish at the container-assigned position.")
	stack.queue_free()
	await get_tree().process_frame

func _settle_layout() -> void:
	await get_tree().create_timer(ControlsHintView.PANEL_TRANSITION_SECONDS + 0.05).timeout
	await get_tree().process_frame

func _assert_control_within(control: Control, panel: Control, message: String) -> void:
	if control == null:
		_assert_true(false, message)
		return
	var control_rect := control.get_global_rect()
	var panel_rect := panel.get_global_rect()
	_assert_true(control_rect.position.x >= panel_rect.position.x - 0.5
			and control_rect.end.x <= panel_rect.end.x + 0.5, message)

func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func _restore_state() -> void:
	InputMap.action_erase_events(&"SKILL_WEAPON")
	for event in _original_reload_events:
		InputMap.action_add_event(&"SKILL_WEAPON", event)
	PlayerAssistSettings.controls_hint_mode = _original_mode

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

func _finish() -> void:
	if _failed:
		print("FAIL: controls hint adaptive guidance")
	else:
		print("PASS: controls hint adaptive guidance")
	get_tree().quit(1 if _failed else 0)
