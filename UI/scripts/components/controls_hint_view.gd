extends PanelContainer
class_name ControlsHintView

signal display_state_changed(state: int)

enum DisplayState {
	EXPANDED,
	COMPACT,
	HIDDEN,
	CONTEXT_REMINDER,
}

const PANEL_WIDTH := 360.0
const COMPACT_PANEL_WIDTH := 240.0
const FALLBACK_MARGIN := 16.0
const TWO_COLUMN_MIN_WIDTH := 420.0
const KEYCAP_WIDTH := 64.0
const COMPACT_EXPAND_WIDTH := 96.0
const PANEL_TRANSITION_SECONDS := 0.18
const CONTENT_FADE_SECONDS := 0.08
const AUTO_COLLAPSE_SECONDS := 4.0
const REST_AUTO_COLLAPSE_SECONDS := 4.0
const CONTEXT_DURATION_SECONDS := 3.0
const CONTEXT_COOLDOWN_SECONDS := 15.0
const MAX_CONTEXT_REPEATS := 2

@onready var content: VBoxContainer = $Margin/Content
@onready var header: HBoxContainer = $Margin/Content/Header
@onready var title_label: Label = $Margin/Content/Header/Title
@onready var collapse_button: Button = $Margin/Content/Header/CollapseButton
@onready var header_divider: ColorRect = $Margin/Content/HeaderDivider
@onready var expanded_content: GridContainer = $Margin/Content/ExpandedContent
@onready var compact_content: HBoxContainer = $Margin/Content/CompactContent
@onready var compact_text: Label = $Margin/Content/CompactContent/CompactText
@onready var compact_expand: Button = $Margin/Content/CompactContent/CompactExpand
@onready var context_content: HBoxContainer = $Margin/Content/ContextContent
@onready var context_key: Label = $Margin/Content/ContextContent/ContextKey
@onready var context_message: Label = $Margin/Content/ContextContent/ContextMessage

var display_state: DisplayState = DisplayState.EXPANDED
var _current_phase: String = ""
var _primary_menu_open := false
var _secondary_menu_context: StringName = &""
var _auto_collapse_remaining := AUTO_COLLAPSE_SECONDS
var _used_move := false
var _used_attack := false
var _manual_expanded := false
var _context_remaining := 0.0
var _context_previous_state: DisplayState = DisplayState.COMPACT
var _context_last_shown_msec: Dictionary = {}
var _context_show_counts: Dictionary = {}
var _action_items: Dictionary = {}
var _render_signature := ""
var _text_context_signature := ""
var _collapsed_text_contexts: Dictionary = {}
var _last_viewport_size := Vector2.ZERO
var _panel_tween: Tween
var _content_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size_flags_horizontal = Control.SIZE_SHRINK_END
	add_theme_stylebox_override("panel", _build_panel_style())
	_configure_text_constraints()
	_configure_button_click_targets()
	_configure_visual_hierarchy()
	collapse_button.pressed.connect(_on_toggle_button_pressed)
	compact_expand.pressed.connect(_on_compact_expand_button_pressed)
	_build_action_items()
	_connect_settings_signal()
	refresh_input_glyphs()
	_apply_saved_mode(false)

func layout_for_viewport(viewport_size: Vector2) -> void:
	_last_viewport_size = viewport_size
	var available_width := maxf(1.0, viewport_size.x - 2.0 * FALLBACK_MARGIN)
	var expanded_width := minf(PANEL_WIDTH, available_width)
	var target_width := _target_panel_width(display_state)
	if _panel_tween == null or not _panel_tween.is_running():
		custom_minimum_size.x = target_width
	expanded_content.columns = 2 if expanded_width >= TWO_COLUMN_MIN_WIDTH else 1
	if get_parent() is Container:
		return
	size.x = target_width
	position = Vector2(viewport_size.x - size.x - FALLBACK_MARGIN, FALLBACK_MARGIN)

func refresh_for_phase(phase: String, primary_menu_open: bool, secondary_menu_context: StringName = &"") -> void:
	var phase_changed := _current_phase != phase
	_current_phase = phase
	_primary_menu_open = primary_menu_open
	_secondary_menu_context = _normalize_secondary_menu_context(secondary_menu_context)
	if phase_changed and phase == PhaseManager.BATTLE:
		_begin_battle_guidance()
	_render_current_context()

func refresh_visibility(primary_menu_open: bool, secondary_menu_context: StringName = &"") -> void:
	var next_phase := PhaseManager.current_state()
	var signature := "%s|%s|%s|%s|%s" % [
		next_phase,
		str(primary_menu_open),
		str(secondary_menu_context),
		str(get_tree().paused),
		str(PlayerAssistSettings.controls_hint_mode),
	]
	if signature == _render_signature:
		return
	_render_signature = signature
	refresh_for_phase(next_phase, primary_menu_open, secondary_menu_context)

func tick(delta: float) -> void:
	if not _can_auto_collapse_current_phase() or get_tree().paused:
		return
	if display_state == DisplayState.CONTEXT_REMINDER:
		_context_remaining -= maxf(delta, 0.0)
		if _context_remaining <= 0.0:
			set_display_state(_context_previous_state, false)
		return
	if display_state != DisplayState.EXPANDED:
		return
	if _manual_expanded:
		return
	if PlayerAssistSettings.controls_hint_mode != PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE:
		return
	_auto_collapse_remaining -= maxf(delta, 0.0)
	if _auto_collapse_remaining <= 0.0 or (_used_move and _used_attack):
		set_display_state(DisplayState.COMPACT)

func handle_input_event(event: InputEvent) -> bool:
	if event == null:
		return false
	if event.is_action_pressed("TOGGLE_CONTROLS"):
		return _request_toggle_display()
	if _current_phase == PhaseManager.BATTLE:
		if event.is_action_pressed("UP") or event.is_action_pressed("DOWN") \
				or event.is_action_pressed("LEFT") or event.is_action_pressed("RIGHT"):
			_used_move = true
		if event.is_action_pressed("ATTACK"):
			_used_attack = true
	return false

func _on_toggle_button_pressed() -> void:
	_request_display_state(DisplayState.COMPACT)

func _on_compact_expand_button_pressed() -> void:
	_request_display_state(DisplayState.EXPANDED)

func _request_toggle_display() -> bool:
	if display_state == DisplayState.EXPANDED:
		return _request_display_state(DisplayState.COMPACT)
	return _request_display_state(DisplayState.EXPANDED)

func _request_display_state(next_state: DisplayState, persist_manual_choice: bool = false) -> bool:
	if not _can_request_display_state(next_state):
		return false
	if PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_ADAPTIVE:
		_apply_manual_display_request(next_state)
	set_display_state(next_state, persist_manual_choice)
	return true

func toggle_expanded() -> void:
	_request_toggle_display()

func set_display_state(next_state: DisplayState, persist_manual_choice: bool = true) -> void:
	var previous_state := display_state
	if next_state == DisplayState.HIDDEN:
		_kill_transition_tweens()
		visible = false
		display_state = next_state
		if persist_manual_choice:
			PlayerAssistSettings.set_controls_hint_mode(PlayerAssistSettings.CONTROLS_HINT_HIDDEN)
		_sync_toggle_affordance()
		display_state_changed.emit(display_state)
		return
	display_state = next_state
	if persist_manual_choice and next_state == DisplayState.EXPANDED:
		PlayerAssistSettings.set_controls_hint_mode(PlayerAssistSettings.CONTROLS_HINT_ALWAYS)
	visible = _should_be_visible()
	_apply_display_state_visuals(next_state, previous_state)
	_sync_toggle_affordance()
	display_state_changed.emit(display_state)

func show_context_reminder(action: StringName, message: String, force: bool = false) -> bool:
	if _current_phase != PhaseManager.BATTLE or PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		return false
	var now_msec := Time.get_ticks_msec()
	var last_shown := int(_context_last_shown_msec.get(action, -1000000))
	var shown_count := int(_context_show_counts.get(action, 0))
	if not force:
		if shown_count >= MAX_CONTEXT_REPEATS:
			return false
		if now_msec - last_shown < int(CONTEXT_COOLDOWN_SECONDS * 1000.0):
			return false
	_context_last_shown_msec[action] = now_msec
	_context_show_counts[action] = shown_count + 1
	_context_previous_state = display_state if display_state != DisplayState.CONTEXT_REMINDER else DisplayState.COMPACT
	context_key.text = _keycap_text(_input_label(action))
	context_message.text = message
	_context_remaining = CONTEXT_DURATION_SECONDS
	set_display_state(DisplayState.CONTEXT_REMINDER, false)
	return true

func dismiss_context_reminder() -> void:
	if display_state == DisplayState.CONTEXT_REMINDER:
		set_display_state(_context_previous_state, false)

func refresh_input_glyphs() -> void:
	if not is_node_ready():
		return
	var move_label := _movement_input_label()
	_set_action_item(&"move", move_label, _tr("ui.controls.move", "Move"))
	_set_action_item(&"attack", _input_label(&"ATTACK"), _tr("ui.controls.attack", "Attack"))
	_set_action_item(&"skill", _input_label(&"SKILL_PLAYER"), _tr("ui.controls.skill", "Player Skill"))
	var reload_action := _tr("ui.controls.reload", "Reload")
	if PlayerAssistSettings.auto_reload_switch:
		reload_action = _tr("ui.controls.auto_reload", "Auto Reload On")
	_set_action_item(&"reload", _input_label(&"SKILL_WEAPON"), reload_action)
	_set_action_item(
		&"switch",
		"%s / %s" % [_input_label(&"SWITCH_LEFT"), _input_label(&"SWITCH_RIGHT")],
		_tr("ui.controls.switch_weapon", "Switch Weapon")
	)
	_set_action_item(&"pause", _input_label(&"ESC"), _tr("ui.controls.pause", "Pause"))
	compact_text.text = "%s %s / %s %s" % [
		move_label,
		_tr("ui.controls.move", "Move"),
		_input_label(&"ATTACK"),
		_tr("ui.controls.attack", "Attack"),
	]
	if _current_phase == PhaseManager.BATTLE:
		compact_text.text = _tr("ui.controls.compact_battle", "Battle Controls Hint")
	compact_expand.text = "%s %s" % [
		_input_label(&"TOGGLE_CONTROLS"),
		_tr("ui.controls.expand", "Expand"),
	]
	title_label.text = _tr("ui.controls.title", "Controls")
	_sync_toggle_affordance()

func _begin_battle_guidance() -> void:
	_auto_collapse_remaining = AUTO_COLLAPSE_SECONDS
	_used_move = false
	_used_attack = false
	_manual_expanded = false
	_context_show_counts.clear()
	_context_last_shown_msec.clear()
	_apply_saved_mode(false)

func _begin_rest_guidance() -> void:
	_auto_collapse_remaining = REST_AUTO_COLLAPSE_SECONDS
	_manual_expanded = false

func _apply_saved_mode(emit_change: bool = true) -> void:
	var mode: StringName = PlayerAssistSettings.controls_hint_mode
	if mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		set_display_state(DisplayState.HIDDEN, false)
	elif mode == PlayerAssistSettings.CONTROLS_HINT_ALWAYS:
		set_display_state(DisplayState.EXPANDED, false)
	elif _current_phase == PhaseManager.BATTLE:
		set_display_state(DisplayState.EXPANDED, false)
	else:
		set_display_state(DisplayState.COMPACT, false)
	if not emit_change:
		return
	display_state_changed.emit(display_state)

func _render_current_context() -> void:
	if not is_node_ready():
		return
	refresh_input_glyphs()
	if not _should_be_visible():
		visible = false
		return
	if PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		visible = false
		return
	visible = true
	if _secondary_menu_context != &"":
		_render_secondary_menu_hint(_secondary_menu_context)
		return
	if _primary_menu_open:
		_render_text_context(
			_tr("ui.tutorial.state.primary_menu", "Primary Menu"),
			[
				_tr("ui.tutorial.panel.primary_menu.line1", "[LMB] Click buttons"),
				_tr("ui.tutorial.panel.primary_menu.line2", "[RMB] Exit current menu"),
			]
		)
		return
	if _current_phase == PhaseManager.BATTLE:
		if display_state == DisplayState.HIDDEN:
			_apply_saved_mode(false)
		else:
			set_display_state(display_state, false)
		return
	_render_text_context(
		_tr("ui.tutorial.state.rest", "Rest Area"),
		[
			_tr("ui.tutorial.panel.rest.line1", "[LMB] Click menu and zones"),
			_tr("ui.tutorial.panel.rest.line2", "[LMB Hold Center] Start battle"),
			_tr("ui.tutorial.panel.rest.line3", "[Esc] Pause"),
		]
	)

func _render_secondary_menu_hint(context_name: StringName) -> void:
	var title_key := "ui.tutorial.state.secondary.%s" % context_name
	var fallback_title := str(context_name).replace("_", " ").capitalize()
	var lines: Array[String] = []
	var line_count := 3
	if context_name == &"grid_management" or context_name == &"task_management":
		line_count = 4
	for index in range(1, line_count + 1):
		var key := "ui.tutorial.panel.secondary.%s.line%d" % [context_name, index]
		var translated := LocalizationManager.tr_key(key, "")
		if translated != "":
			lines.append(translated)
	_render_text_context(LocalizationManager.tr_key(title_key, fallback_title), lines)

func _render_text_context(context_title: String, lines: Array[String]) -> void:
	var context_identity := _text_context_identity()
	var context_changed := _text_context_signature != context_identity
	_text_context_signature = context_identity
	title_label.text = context_title
	_clear_action_items()
	for line in lines:
		var item := _create_hint_item("", line)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		expanded_content.add_child(item)
	compact_text.text = _compact_text_context(context_title, lines)
	compact_expand.text = "%s %s" % [
		_input_label(&"TOGGLE_CONTROLS"),
		_tr("ui.controls.expand", "Expand"),
	]
	var next_state := display_state
	if PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_ALWAYS:
		next_state = DisplayState.EXPANDED
	elif _current_phase == PhaseManager.PREPARE:
		if context_changed and display_state == DisplayState.EXPANDED:
			_begin_rest_guidance()
		next_state = display_state
	elif bool(_collapsed_text_contexts.get(context_identity, false)):
		next_state = DisplayState.COMPACT
	elif context_changed:
		next_state = DisplayState.EXPANDED
	if next_state == DisplayState.HIDDEN or next_state == DisplayState.CONTEXT_REMINDER:
		next_state = DisplayState.EXPANDED
	set_display_state(next_state, false)

func _compact_text_context(context_title: String, _lines: Array[String]) -> String:
	return _tr("ui.controls.compact_context", "{context} controls").format({
		"context": _compact_context_name(context_title),
	})

func _compact_context_name(context_title: String) -> String:
	var compact := context_title.strip_edges()
	var prefixes := PackedStringArray([
		"Current: ",
		"当前状态：",
		"當前狀態：",
	])
	for prefix in prefixes:
		if compact.begins_with(prefix):
			return compact.substr(prefix.length()).strip_edges()
	return compact

func _text_context_identity() -> String:
	return "%s|%s|%s" % [_current_phase, str(_primary_menu_open), str(_secondary_menu_context)]

func _is_text_context_active() -> bool:
	return _current_phase != PhaseManager.BATTLE

func _set_text_context_collapsed(context_identity: String, collapsed: bool) -> void:
	if context_identity == "":
		return
	if collapsed:
		_collapsed_text_contexts[context_identity] = true
	else:
		_collapsed_text_contexts.erase(context_identity)

func _can_request_display_state(next_state: DisplayState) -> bool:
	var mode := PlayerAssistSettings.controls_hint_mode
	if mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		return false
	if mode == PlayerAssistSettings.CONTROLS_HINT_ALWAYS:
		return next_state == DisplayState.EXPANDED
	return next_state == DisplayState.EXPANDED or next_state == DisplayState.COMPACT

func _can_auto_collapse_current_phase() -> bool:
	return _current_phase == PhaseManager.BATTLE or _current_phase == PhaseManager.PREPARE

func _apply_manual_display_request(next_state: DisplayState) -> void:
	match next_state:
		DisplayState.EXPANDED:
			_manual_expanded = true
			if _is_text_context_active():
				_set_text_context_collapsed(_text_context_identity(), false)
		DisplayState.COMPACT:
			_manual_expanded = false
			if _is_text_context_active():
				_set_text_context_collapsed(_text_context_identity(), true)
		DisplayState.HIDDEN:
			_manual_expanded = false
		_:
			pass

func _sync_toggle_affordance() -> void:
	if collapse_button == null:
		return
	if PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_HIDDEN:
		collapse_button.disabled = true
		collapse_button.text = _tr("ui.controls.hidden", "Hidden")
		collapse_button.tooltip_text = _tr(
			"ui.controls.hidden_tooltip",
			"Controls hint is hidden by setting."
		)
		return
	if PlayerAssistSettings.controls_hint_mode == PlayerAssistSettings.CONTROLS_HINT_ALWAYS:
		collapse_button.disabled = true
		collapse_button.text = _tr("ui.controls.always_expanded", "Always Expanded")
		collapse_button.tooltip_text = _tr(
			"ui.controls.always_expanded_tooltip",
			"Controls setting is Always Expanded. Change it to Adaptive to collapse hints."
		)
		return
	collapse_button.disabled = false
	collapse_button.text = "%s %s" % [_input_label(&"TOGGLE_CONTROLS"), _tr("ui.controls.collapse", "Collapse")]
	collapse_button.tooltip_text = _tr("ui.controls.collapse_tooltip", "Temporarily collapse controls hint (F1)")

func _build_action_items() -> void:
	_clear_action_items()
	for action_id in [&"move", &"attack", &"skill", &"reload", &"switch", &"pause"]:
		var item := _create_hint_item("", "")
		expanded_content.add_child(item)
		_action_items[action_id] = item

func _clear_action_items() -> void:
	for child in expanded_content.get_children():
		expanded_content.remove_child(child)
		child.queue_free()
	_action_items.clear()

func _create_hint_item(key_text: String, action_text: String) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 7)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.custom_minimum_size.x = 0.0
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var key_label := Label.new()
	key_label.name = "Key"
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.custom_minimum_size = Vector2(KEYCAP_WIDTH, 26.0)
	key_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.clip_text = true
	key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.87, 1.0))
	key_label.add_theme_stylebox_override("normal", _build_keycap_style())
	key_label.text = key_text
	key_label.visible = key_text != ""
	item.add_child(key_label)
	var action_label := Label.new()
	action_label.name = "Action"
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label.custom_minimum_size = Vector2(0.0, 26.0)
	action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_label.size_flags_vertical = Control.SIZE_FILL
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_label.max_lines_visible = 2
	action_label.clip_text = true
	action_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	action_label.add_theme_font_size_override("font_size", 15)
	action_label.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98, 1.0))
	action_label.text = action_text
	item.add_child(action_label)
	return item

func _set_action_item(action_id: StringName, key_text: String, action_text: String) -> void:
	var item := _action_items.get(action_id, null) as HBoxContainer
	if item == null or not is_instance_valid(item):
		_build_action_items()
		item = _action_items.get(action_id, null) as HBoxContainer
	if item == null:
		return
	var key_label := item.get_node_or_null("Key") as Label
	var action_label := item.get_node_or_null("Action") as Label
	if key_label:
		key_label.text = key_text
		key_label.visible = key_text != ""
	if action_label:
		action_label.text = action_text

func _movement_input_label() -> String:
	var labels := PackedStringArray([
		_input_label(&"UP"),
		_input_label(&"LEFT"),
		_input_label(&"DOWN"),
		_input_label(&"RIGHT"),
	])
	if labels == PackedStringArray(["W", "A", "S", "D"]):
		return "WASD"
	return "/".join(labels)

func _input_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return str(action)
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return str(action)
	return _event_label(events[0])

func _event_label(event: InputEvent) -> String:
	var key_event := event as InputEventKey
	if key_event != null:
		var code := key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
		var label := OS.get_keycode_string(code)
		if label == "Space":
			return _tr("ui.controls.key.space", "Space")
		if label == "Escape":
			return "Esc"
		return _compact_key_name(label)
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return _tr("ui.controls.key.lmb", "LMB")
			MOUSE_BUTTON_RIGHT:
				return _tr("ui.controls.key.rmb", "RMB")
			MOUSE_BUTTON_MIDDLE:
				return _tr("ui.controls.key.mmb", "MMB")
			_:
				return "M%d" % mouse_event.button_index
	var joy_event := event as InputEventJoypadButton
	if joy_event != null:
		return "Pad %d" % joy_event.button_index
	return _compact_key_name(event.as_text())

func _keycap_text(text: String) -> String:
	return "[%s]" % text if text != "" else ""

func _compact_key_name(text: String) -> String:
	var compact := text.replace(" + ", "+").replace("Mouse Button", "M")
	if compact.length() > 12:
		return compact.substr(0, 11) + "..."
	return compact

func _configure_text_constraints() -> void:
	custom_minimum_size.x = PANEL_WIDTH
	title_label.custom_minimum_size.x = 0.0
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	compact_text.custom_minimum_size.x = 0.0
	compact_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_text.clip_text = true
	compact_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	compact_expand.custom_minimum_size.x = COMPACT_EXPAND_WIDTH
	compact_expand.size_flags_horizontal = Control.SIZE_SHRINK_END
	context_key.custom_minimum_size.x = KEYCAP_WIDTH
	context_key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	context_key.clip_text = true
	context_key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	context_message.custom_minimum_size = Vector2(0.0, 26.0)
	context_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_message.size_flags_vertical = Control.SIZE_FILL
	context_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_message.max_lines_visible = 2
	context_message.clip_text = true
	context_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _target_panel_width(state: DisplayState) -> float:
	var available_width := PANEL_WIDTH
	if _last_viewport_size.x > 0.0:
		available_width = maxf(1.0, _last_viewport_size.x - 2.0 * FALLBACK_MARGIN)
	var base_width := COMPACT_PANEL_WIDTH if state == DisplayState.COMPACT else PANEL_WIDTH
	return minf(base_width, available_width)

func _apply_display_state_visuals(next_state: DisplayState, previous_state: DisplayState) -> void:
	var target_width := _target_panel_width(next_state)
	var should_animate := is_inside_tree() and is_node_ready() and visible and previous_state != next_state
	if should_animate:
		_animate_display_state(next_state, target_width)
		return
	_kill_transition_tweens()
	custom_minimum_size.x = target_width
	content.modulate.a = 1.0
	_show_display_state_content(next_state)

func _animate_display_state(next_state: DisplayState, target_width: float) -> void:
	_kill_transition_tweens()
	_panel_tween = create_tween()
	_panel_tween.set_trans(Tween.TRANS_CUBIC)
	_panel_tween.set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(self, "custom_minimum_size:x", target_width, PANEL_TRANSITION_SECONDS)

	_content_tween = create_tween()
	_content_tween.set_trans(Tween.TRANS_SINE)
	_content_tween.set_ease(Tween.EASE_OUT)
	_content_tween.tween_property(content, "modulate:a", 0.0, CONTENT_FADE_SECONDS)
	_content_tween.tween_callback(Callable(self, "_show_display_state_content").bind(next_state))
	_content_tween.tween_property(content, "modulate:a", 1.0, CONTENT_FADE_SECONDS)

func _kill_transition_tweens() -> void:
	if _panel_tween != null and _panel_tween.is_running():
		_panel_tween.kill()
	if _content_tween != null and _content_tween.is_running():
		_content_tween.kill()
	_panel_tween = null
	_content_tween = null

func _show_display_state_content(state: DisplayState) -> void:
	header.visible = state == DisplayState.EXPANDED
	header_divider.visible = state == DisplayState.EXPANDED
	expanded_content.visible = state == DisplayState.EXPANDED
	compact_content.visible = state == DisplayState.COMPACT
	context_content.visible = state == DisplayState.CONTEXT_REMINDER

func _configure_button_click_targets() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	expanded_content.mouse_filter = Control.MOUSE_FILTER_PASS
	compact_content.mouse_filter = Control.MOUSE_FILTER_PASS
	context_content.mouse_filter = Control.MOUSE_FILTER_PASS
	compact_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compact_expand.mouse_filter = Control.MOUSE_FILTER_STOP
	compact_expand.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	compact_expand.tooltip_text = _tr("ui.controls.expand_tooltip", "Expand controls hint (F1)")

func _configure_visual_hierarchy() -> void:
	title_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
	_apply_hint_button_style(collapse_button)
	_apply_hint_button_style(compact_expand)

func _apply_hint_button_style(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.82, 0.91, 0.94, 1.0))
	button.add_theme_stylebox_override(
		"normal",
		_build_button_style(Color(0.08, 0.16, 0.20, 0.92), Color(0.28, 0.48, 0.56, 0.92))
	)
	button.add_theme_stylebox_override(
		"hover",
		_build_button_style(Color(0.12, 0.25, 0.30, 0.98), Color(0.38, 0.72, 0.82, 1.0))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_build_button_style(Color(0.08, 0.20, 0.25, 1.0), Color(0.45, 0.82, 0.90, 1.0))
	)

func _should_be_visible() -> bool:
	return _current_phase != PhaseManager.GAMEOVER and not get_tree().paused

func _connect_settings_signal() -> void:
	var callback := Callable(self, "_on_assist_settings_changed")
	if not PlayerAssistSettings.settings_changed.is_connected(callback):
		PlayerAssistSettings.settings_changed.connect(callback)

func _on_assist_settings_changed() -> void:
	_render_signature = ""
	refresh_input_glyphs()
	_apply_saved_mode(false)
	_render_current_context()

func _tr(key: String, fallback: String) -> String:
	return LocalizationManager.tr_key(key, fallback)

func _normalize_secondary_menu_context(context_name: StringName) -> StringName:
	match context_name:
		&"purchase", &"upgrade", &"warehouse", &"grid_management", &"task_management":
			return context_name
		&"shop":
			return &"purchase"
		&"grid":
			return &"grid_management"
		&"task":
			return &"task_management"
		_:
			return &""

func _build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.063, 0.094, 0.88)
	style.border_color = Color(0.28, 0.50, 0.58, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

func _build_keycap_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.20, 0.23, 0.96)
	style.border_color = Color(0.33, 0.40, 0.44, 0.96)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	return style

func _build_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	return style
